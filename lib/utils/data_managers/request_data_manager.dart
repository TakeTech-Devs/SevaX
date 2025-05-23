import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import 'package:http/http.dart';

// import 'package:geolocator/geolocator.dart';
// import 'package:location/location.dart';
import 'package:meta/meta.dart';
import 'package:sevaexchange/flavor_config.dart';
import 'package:sevaexchange/l10n/l10n.dart';
import 'package:sevaexchange/models/agreement_template_model.dart';
import 'package:sevaexchange/models/basic_user_details.dart';
import 'package:sevaexchange/models/category_model.dart';
import 'package:sevaexchange/models/donation_model.dart';
import 'package:sevaexchange/models/models.dart';
import 'package:sevaexchange/models/notifications_model.dart';
import 'package:sevaexchange/models/request_model.dart';
import 'package:sevaexchange/models/timebank_balance_transction_model.dart';
import 'package:sevaexchange/models/transactions_timeline_model.dart';
import 'package:sevaexchange/new_baseline/models/acceptor_model.dart';
import 'package:sevaexchange/new_baseline/models/borrow_accpetor_model.dart';
import 'package:sevaexchange/new_baseline/models/project_model.dart';
import 'package:sevaexchange/new_baseline/models/project_template_model.dart';
import 'package:sevaexchange/new_baseline/models/request_invitaton_model.dart';
import 'package:sevaexchange/new_baseline/models/user_insufficient_credits_model.dart';
import 'package:sevaexchange/repositories/firestore_keys.dart';
import 'package:sevaexchange/repositories/notifications_repository.dart';
import 'package:sevaexchange/repositories/timebank_repository.dart';
import 'package:sevaexchange/utils/data_managers/blocs/communitylist_bloc.dart';
import 'package:sevaexchange/utils/deep_link_manager/invitation_manager.dart';
import 'package:sevaexchange/utils/firestore_manager.dart' as FirestoreManager;
import 'package:sevaexchange/utils/helpers/mailer.dart';
import 'package:sevaexchange/utils/log_printer/log_printer.dart';
import 'package:sevaexchange/utils/utils.dart' as utils;
import 'package:sevaexchange/utils/utils.dart';
import 'package:sevaexchange/views/core.dart';
import 'package:sevaexchange/views/exchange/widgets/request_enums.dart';
import 'package:sevaexchange/views/exchange/widgets/mail_content_template.dart';

import '../app_config.dart';
import '../svea_credits_manager.dart';
import 'notifications_data_manager.dart';

import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

final geo = GeoFirePoint(GeoPoint(0, 0));
late BuildContext dialogContext;

Future<void> createRequest({required RequestModel requestModel}) async {
  return await CollectionRef.requests
      .doc(requestModel.id)
      .set(requestModel.toMap());
}

Future<void> updateRequest({required RequestModel requestModel}) async {
  log('RequestModel:  ' + requestModel.toMap().toString());
  return await CollectionRef.requests
      .doc(requestModel.id)
      .update(requestModel.toMap());
}

Future<void> updateAcceptBorrowRequest({
  required RequestModel requestModel,
  // required Map participantDetails,
  required String userEmail,
}) async {
  log('accept updated borrow request');
  return await CollectionRef.requests.doc(requestModel.id).update(
    {
      // 'participantDetails.$userEmail': participantDetails,
      'accepted': true,
      'approvedUsers': FieldValue.arrayUnion([userEmail]),
    },
  );
}

Future<void> updateRequestsByFields(
    {required List<String> requestIds,
    required Map<String, dynamic> fields}) async {
  var futures = <Future>[];
  int i;
  for (i = 0; i < requestIds.length; i++) {
    futures.add(CollectionRef.requests.doc(requestIds[i]).update(fields));
  }
  await Future.wait(futures);
}

Future<void> createDonation({required DonationModel donationModel}) async {
  return await CollectionRef.donations
      .doc(donationModel.id)
      .set(donationModel.toMap());
}

Future<List<String>> createRecurringEvents({
  required RequestModel requestModel,
  required String communityId,
  required String timebankId,
}) async {
  var batch = CollectionRef.batch;
  double sevaCreditsCount = 0;
  bool lastRound = false;
  DateTime eventStartDate =
          DateTime.fromMillisecondsSinceEpoch(requestModel.requestStart!),
      eventEndDate =
          DateTime.fromMillisecondsSinceEpoch(requestModel.requestEnd!);
  double balanceVar = await SevaCreditLimitManager.getMemberBalancePerTimebank(
    communityId: communityId,
    userSevaId: requestModel.sevaUserId!,
  );

  double negativeThresholdTimebank =
      await SevaCreditLimitManager.getNegativeThresholdForCommunity(
    communityId,
  );
  List<Map<String, dynamic>> temparr = [];
  List<String> eventsIdsArr = [];
  DocumentSnapshot? projectDoc;
  ProjectModel? projectData;

  if (requestModel.projectId != null && requestModel.projectId != "") {
    projectDoc = await CollectionRef.projects.doc(requestModel.projectId).get();
    projectData = ProjectModel.fromMap(
        Map<String, dynamic>.from(projectDoc.data() as Map));
  }

  batch.set(CollectionRef.requests.doc(requestModel.id), requestModel.toMap());

  if (requestModel.end?.endType == 'On') {
    //end type is on
    int occurenceCount = 2;
    var numTemp = 0;
    while (lastRound == false) {
      eventStartDate = DateTime(
          eventStartDate.year,
          eventStartDate.month,
          eventStartDate.day + 1,
          eventStartDate.hour,
          eventStartDate.minute,
          eventStartDate.second);
      eventEndDate = DateTime(
          eventEndDate.year,
          eventEndDate.month,
          eventEndDate.day + 1,
          eventEndDate.hour,
          eventEndDate.minute,
          eventEndDate.second);

      if (eventStartDate.millisecondsSinceEpoch <=
              (requestModel.end?.on ?? 0) &&
          occurenceCount < 11) {
        numTemp = eventStartDate.weekday % 7;
        if ((requestModel.recurringDays ?? []).contains(numTemp)) {
          RequestModel temp = requestModel;
          temp.requestStart = eventStartDate.millisecondsSinceEpoch;
          temp.requestEnd = eventEndDate.millisecondsSinceEpoch;
          temp.postTimestamp = DateTime.now().millisecondsSinceEpoch;
          temp.id = (temp.email ?? '') +
              "*" +
              temp.postTimestamp.toString() +
              "*" +
              temp.requestStart.toString();
          temp.occurenceCount = occurenceCount;
          occurenceCount++;
          temp.softDelete = false;
          temp.isRecurring = false;
          temp.autoGenerated = true;
          sevaCreditsCount += (temp.numberOfHours ?? 0);
          temparr.add(temp.toMap());
          log("on mode inside if with day ${eventStartDate.toString()} with occurence count of ${temp.occurenceCount}");
        }
      } else {
        lastRound = true;
        break;
      }
    }
  } else {
    //end type is after
    var numTemp = 0;
    int occurenceCount = 2;
    while (occurenceCount <= (requestModel.end?.after ?? 0)) {
      eventStartDate = DateTime(
          eventStartDate.year,
          eventStartDate.month,
          eventStartDate.day + 1,
          eventStartDate.hour,
          eventStartDate.minute,
          eventStartDate.second);
      eventEndDate = DateTime(
          eventEndDate.year,
          eventEndDate.month,
          eventEndDate.day + 1,
          eventEndDate.hour,
          eventEndDate.minute,
          eventEndDate.second);

      numTemp = eventStartDate.weekday % 7;
      if ((requestModel.recurringDays ?? []).contains(numTemp)) {
        RequestModel temp = requestModel;
        temp.requestStart = eventStartDate.millisecondsSinceEpoch;
        temp.requestEnd = eventEndDate.millisecondsSinceEpoch;
        temp.postTimestamp = DateTime.now().millisecondsSinceEpoch;
        temp.id = (temp.email ?? '') +
            "*" +
            temp.postTimestamp.toString() +
            "*" +
            temp.requestStart.toString();
        temp.occurenceCount = occurenceCount;
        occurenceCount++;
        temp.softDelete = false;
        temp.isRecurring = false;
        temp.autoGenerated = true;
        sevaCreditsCount += (temp.numberOfHours ?? 0);
        temparr.add(temp.toMap());
        log("after mode inside if with day ${eventStartDate.toString()} with occurence count of ${temp.occurenceCount}");
      }
      if (occurenceCount > (requestModel.end?.after ?? 0)) {
        break;
      }
    }
  }

  if (requestModel.requestMode == RequestMode.PERSONAL_REQUEST) {
    log("inside personal req check");
    if (balanceVar - sevaCreditsCount >= negativeThresholdTimebank) {
      log("yup balance");
      eventsIdsArr.add(requestModel.id!);
      temparr.forEach((tempobj) {
        batch.set(CollectionRef.requests.doc(tempobj['id']), tempobj);
        eventsIdsArr.add(tempobj['id']);
        log("---------   ${DateTime.fromMillisecondsSinceEpoch(tempobj['request_start']).toString()} with occurence count of ${tempobj['occurenceCount']}");
      });
    } else {
      log("oops no balance");
      return [];
    }
  } else {
    if (requestModel.requestMode == RequestMode.PERSONAL_REQUEST) {
      log("inside personal req check");
      if (balanceVar - sevaCreditsCount >= negativeThresholdTimebank) {
        log("yup balance");
        eventsIdsArr.add(requestModel.id!);
        temparr.forEach((tempobj) {
          batch.set(CollectionRef.requests.doc(tempobj['id']), tempobj);
          eventsIdsArr.add(tempobj['id']);
          log("---------   ${DateTime.fromMillisecondsSinceEpoch(tempobj['request_start']).toString()} with occurence count of ${tempobj['occurenceCount']}");
        });
      } else {
        log("oops no balance");
        return [];
      }
    } else {
      if (AppConfig.supportedRequestTypeForRecurring
          .contains(requestModel.requestType)) {
        eventsIdsArr.add(requestModel.id!);
        temparr.forEach((tempobj) {
          batch.set(CollectionRef.requests.doc(tempobj['id']), tempobj);
          eventsIdsArr.add(tempobj['id']);
        });
      }
    }
  }

  DocumentSnapshot timebankDoc =
      await CollectionRef.timebank.doc(requestModel.timebankId).get();
  final timebankData = timebankDoc.data() as Map<String, dynamic>?;
  double balance =
      ((timebankData?['balance'] ?? 0) as num).toDouble() + sevaCreditsCount;
  batch
      .update(CollectionRef.timebank.doc(timebankDoc.id), {"balance": balance});

  if (requestModel.projectId != null &&
      requestModel.projectId != "" &&
      projectData != null) {
    if (projectData.pendingRequests != null) {
      projectData.pendingRequests!.add(requestModel.id!);
    }
    temparr.forEach((tempobj) {
      if (projectData!.pendingRequests != null) {
        projectData.pendingRequests!.add(tempobj['id'] as String);
      }
    });
    batch.update(
        CollectionRef.projects.doc(projectData.id), projectData.toMap());
  }

  await batch.commit();
  return eventsIdsArr;
}

Future<void> updateRecurrenceRequestsFrontEnd(
    {required RequestModel updatedRequestModel,
    required String communityId,
    required String timebankId}) async {
  var batch = CollectionRef.batch;
  double newCredits = 0, oldCredits = 0;
  bool lastRound = false;
  String uuidvar = "";
  RequestModel? eventData;

  logger.i("INSIDE updateRecurrenceRequestsFrontEnd");

  List<RequestModel> upcomingEventsArr = [], prevEventsArr = [];
  var futures = <Future>[];
  // double balanceVar = await getMemberBalance(updatedRequestModel.sevaUserId);
  double balanceVar = await SevaCreditLimitManager.getMemberBalancePerTimebank(
    communityId: communityId,
    userSevaId: updatedRequestModel.sevaUserId ?? '',
  );

  logger.i("INSIDE 1");
  double negativeThresholdTimebank =
      await SevaCreditLimitManager.getNegativeThresholdForCommunity(
          communityId);
  Set<String> usersIds = Set();
  DateTime eventStartDate = DateTime.fromMillisecondsSinceEpoch(
          updatedRequestModel.requestStart ?? 0),
      eventEndDate = DateTime.fromMillisecondsSinceEpoch(
          updatedRequestModel.requestEnd ?? 0);
  logger.i("INSIDE 2");

  QuerySnapshot snapEvents = await CollectionRef.requests
      .where("parent_request_id",
          isEqualTo: updatedRequestModel.parent_request_id)
      .get();
  DocumentSnapshot? projectDoc;
  ProjectModel? projectData;
  if (updatedRequestModel.projectId != null &&
      updatedRequestModel.projectId != "") {
    projectDoc =
        await CollectionRef.projects.doc(updatedRequestModel.projectId).get();
    final projectDocData = projectDoc.data();
    if (projectDocData != null) {
      projectData =
          ProjectModel.fromMap(projectDocData as Map<String, dynamic>);
    }
  }
  logger.i("INSIDE 3");

  for (var eventDoc in snapEvents.docs) {
    final eventDocData = eventDoc.data();
    if (eventDocData == null) continue;
    eventData = RequestModel.fromMap(eventDocData as Map<dynamic, dynamic>);
    if (eventData.occurenceCount != null && eventData.occurenceCount == 1) {
      // parentEvent = eventData; // Commented out as parentEvent is undefined
    }
    if (eventData.occurenceCount != null &&
        updatedRequestModel.occurenceCount != null &&
        eventData.occurenceCount! > updatedRequestModel.occurenceCount!) {
      upcomingEventsArr.add(eventData);
    }
    if (eventData.occurenceCount != null &&
        updatedRequestModel.occurenceCount != null &&
        eventData.occurenceCount! < updatedRequestModel.occurenceCount!) {
      prevEventsArr.add(eventData);
    }
  }
  logger.i("INSIDE 4");

  // s1 ---------- create set of events with updated data

  List<Map<String, dynamic>> temparr = [];

  if (updatedRequestModel.end?.endType == "On") {
    //end type is on
    int occurenceCount = (updatedRequestModel.occurenceCount ?? 0) + 1;
    var numTemp = 0;
    while (lastRound == false) {
      eventStartDate = DateTime(
          eventStartDate.year,
          eventStartDate.month,
          eventStartDate.day + 1,
          eventStartDate.hour,
          eventStartDate.minute,
          eventStartDate.second);
      eventEndDate = DateTime(
          eventEndDate.year,
          eventEndDate.month,
          eventEndDate.day + 1,
          eventEndDate.hour,
          eventEndDate.minute,
          eventEndDate.second);
      if (eventStartDate.millisecondsSinceEpoch <=
              (updatedRequestModel.end?.on ?? 0) &&
          occurenceCount < 11) {
        numTemp = eventStartDate.weekday % 7;
        if ((updatedRequestModel.recurringDays ?? []).contains(numTemp)) {
          RequestModel temp = updatedRequestModel;
          temp.requestStart = eventStartDate.millisecondsSinceEpoch;
          temp.requestEnd = eventEndDate.millisecondsSinceEpoch;
          temp.postTimestamp = DateTime.now().millisecondsSinceEpoch;
          temp.id = (temp.email ?? '') +
              "*" +
              temp.postTimestamp.toString() +
              "*" +
              temp.requestStart.toString();
          temp.occurenceCount = occurenceCount;
          occurenceCount++;
          temp.softDelete = false;
          temp.isRecurring = false;
          temp.autoGenerated = true;
          newCredits += (temp.numberOfHours ?? 0);
          temparr.add(temp.toMap());
          if (projectData != null && projectData.pendingRequests != null) {
            projectData.pendingRequests!.add(temp.id!);
          }
        }
      } else {
        lastRound = true;
        break;
      }
    }
  } else {
    //end type is after
    var numTemp = 0;
    int occurenceCount = (updatedRequestModel.occurenceCount ?? 0) + 1;
    while (occurenceCount <= (updatedRequestModel.end?.after ?? 0)) {
      eventStartDate = DateTime(
          eventStartDate.year,
          eventStartDate.month,
          eventStartDate.day + 1,
          eventStartDate.hour,
          eventStartDate.minute,
          eventStartDate.second);
      eventEndDate = DateTime(
          eventEndDate.year,
          eventEndDate.month,
          eventEndDate.day + 1,
          eventEndDate.hour,
          eventEndDate.minute,
          eventEndDate.second);
      numTemp = eventStartDate.weekday % 7;
      if ((updatedRequestModel.recurringDays ?? []).contains(numTemp)) {
        RequestModel temp = updatedRequestModel;
        temp.requestStart = eventStartDate.millisecondsSinceEpoch;
        temp.requestEnd = eventEndDate.millisecondsSinceEpoch;
        temp.postTimestamp = DateTime.now().millisecondsSinceEpoch;
        temp.id = (temp.email ?? '') +
            "*" +
            temp.postTimestamp.toString() +
            "*" +
            temp.requestStart.toString();
        temp.occurenceCount = occurenceCount;
        occurenceCount++;
        temp.softDelete = false;
        temp.isRecurring = false;
        temp.autoGenerated = true;
        newCredits += (temp.numberOfHours ?? 0);
        temparr.add(temp.toMap());
        if (projectData != null && projectData.pendingRequests != null) {
          projectData.pendingRequests!.add(temp.id!);
        }
        log("after mode inside if with day ${eventStartDate.toString()} with occurence count of ${temp.occurenceCount}");
      }
      if (occurenceCount > (updatedRequestModel.end?.after ?? 0)) {
        break;
      }
    }
  }

  logger.i("INSIDE 5");

  temparr.forEach((tempobj) {
    batch.set(CollectionRef.requests.doc(tempobj['id']), tempobj);
    log("---------   ${DateTime.fromMillisecondsSinceEpoch(tempobj['request_start']).toString()} with occurence count of ${tempobj['occurenceCount']}");
  });

  // s2 ---------- update parent request and previous events with end data of updated event model

  batch.update(
      CollectionRef.requests.doc(updatedRequestModel.parent_request_id), {
    "end": updatedRequestModel.end?.toMap(),
    "recurringDays": updatedRequestModel.recurringDays
  });

  // s3 ---------- delete old recurrences since the updated model

  if (upcomingEventsArr.isNotEmpty) {
    for (var upcomingEvent in upcomingEventsArr) {
      if (projectData != null && projectData.pendingRequests != null) {
        projectData.pendingRequests!.remove(upcomingEvent.id);
      }
      oldCredits = oldCredits + (upcomingEvent.numberOfHours ?? 0);
      batch.delete(CollectionRef.requests
          .doc(upcomingEvent.id)); // delete old upcoming recurrence-events
    }
  }

  // s4 ---------- subtract old credits and add credits to timebank

  DocumentSnapshot timebankDoc =
      await CollectionRef.timebank.doc(updatedRequestModel.timebankId).get();
  final timebankData = timebankDoc.data() as Map<String, dynamic>?;
  double balance = ((timebankData?['balance'] ?? 0) as num).toDouble() -
      oldCredits +
      newCredits;
  batch.update(CollectionRef.timebank.doc(updatedRequestModel.timebankId),
      {'balance': balance});

  // s5 ---------- send notifications in case users have part of members

  for (var upcomingEvent in upcomingEventsArr) {
    if ((upcomingEvent.approvedUsers ?? []).isNotEmpty) {
      for (var approvedMemberId in upcomingEvent.approvedUsers!) {
        usersIds.add(approvedMemberId);
      }
    }
  }

  if (usersIds.isNotEmpty) {
    for (var userid in usersIds) {
      futures.add(CollectionRef.users.doc(userid).get());
    }

    var futuresResult = await Future.wait(futures);
    for (var docUser in futuresResult) {
      for (RequestModel upcomingEvent in upcomingEventsArr) {
        if ((upcomingEvent.approvedUsers ?? []).contains(docUser.id)) {
          uuidvar = UniqueKey().toString();
          batch.set(
              CollectionRef.users
                  .doc(docUser.id)
                  .collection("notifications")
                  .doc(uuidvar),
              {
                'communityId': timebankData?['community_id'],
                'data': {
                  'eventName': upcomingEvent.title,
                  'eventDate': upcomingEvent.requestStart,
                  'requestId': upcomingEvent.id,
                  'photoUrl': upcomingEvent.photoUrl,
                },
                'id': uuidvar,
                'isRead': false,
                'senderUserId': upcomingEvent.sevaUserId,
                'timebankId': upcomingEvent.timebankId,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'type': "RecurringRequestUpdated",
                'userId':
                    (docUser.data() as Map<String, dynamic>?)?['sevauserid']
              });
        }
      }
    }
  }

  // s6 ---------- change in projects pendingrequests, and put it all into a batch and commit them
  if (projectData != null) {
    batch.update(
        CollectionRef.projects.doc(projectData.id), projectData.toMap());
  }
  await batch.commit();
  logger.i("END 4");
}

Stream<List<RequestModel>> getRequestStreamCreatedByUser({
  required String sevaUserID,
}) async* {
  var data = CollectionRef.requests
      .where('accepted', isEqualTo: false)
      .where('sevauserid', isEqualTo: sevaUserID)
      .snapshots();

  yield* data.transform(
      StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
    handleData: (snapshot, requestSink) {
      List<RequestModel> requestList = [];
      snapshot.docs.forEach(
        (documentSnapshot) {
          final data = documentSnapshot.data();
          if (data != null) {
            RequestModel model =
                RequestModel.fromMap(data as Map<dynamic, dynamic>);
            model.id = documentSnapshot.id;
            requestList.add(model);
          }
        },
      );
      requestSink.add(requestList);
    },
  ));
}

Stream<List<RequestModel>> getRequestListStream(
    {required String timebankId}) async* {
  var query = timebankId == 'All'
      ? CollectionRef.requests
      : CollectionRef.requests
          .where('timebanksPosted', arrayContains: timebankId)
          .where('requestMode', isEqualTo: 'TIMEBANK_REQUEST');

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final data = documentSnapshot.data();
            if (data != null) {
              RequestModel model =
                  RequestModel.fromMap(data as Map<dynamic, dynamic>);
              model.id = documentSnapshot.id;
              if ((model.approvedUsers?.length ?? 0) <=
                  (model.numberOfApprovals ?? 0)) requestList.add(model);
            }
          },
        );
        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<RequestModel>> getAllRequestListStream() async* {
  var query = CollectionRef.requests.where('accepted', isEqualTo: false);

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final data = documentSnapshot.data();
            if (data != null) {
              RequestModel model =
                  RequestModel.fromMap(data as Map<dynamic, dynamic>);
              model.id = documentSnapshot.id;
              if ((model.approvedUsers?.length ?? 0) <=
                  (model.numberOfApprovals ?? 0)) requestList.add(model);
            }
          },
        );
        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<CategoryModel>> getUserCreatedRequestCategories(
    String creatorId, BuildContext context) async* {
  var query =
      CollectionRef.requestCategories.where('creatorId', isEqualTo: creatorId);

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<CategoryModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<CategoryModel> categoriesList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final data = documentSnapshot.data();
            if (data != null) {
              CategoryModel model =
                  CategoryModel.fromMap(data as Map<String, dynamic>);

              logger.e('SNAPSHOT LENGTH:  ' + data.length.toString());

              final lang = SevaCore.of(context).loggedInUser.language ?? '';
              if (model.data != null &&
                  model.data!.containsKey('title_' + lang)) {
                categoriesList.add(model);
              }
            }
          },
        );
        requestSink.add(categoriesList);
      },
    ),
  );
}

Stream<List<RequestModel>> getAllVirtualRequestListStream(
    {required String timebankid}) async* {
  var query = CollectionRef.requests
      .where('accepted', isEqualTo: false)
      .where('timebanksPosted', arrayContains: timebankid)
      .where('softDelete', isEqualTo: false)
      .where('virtualRequest', isEqualTo: true);
  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final data = documentSnapshot.data();
            if (data != null) {
              RequestModel model =
                  RequestModel.fromMap(data as Map<dynamic, dynamic>);
              model.id = documentSnapshot.id;
              requestList.add(model);
            }
          },
        );
        requestSink.add(requestList);
      },
    ),
  );
}

//get all public projects
Future<List<ProjectModel>> getAllPublicProjects(
    {required String timebankid}) async {
  List<ProjectModel> projectsList = [];
  await CollectionRef.projects
      .where('timebanksPosted', arrayContains: timebankid)
      .where('softDelete', isEqualTo: false)
      .where('public', isEqualTo: true)
      .orderBy("created_at", descending: true)
      .get()
      .then((data) {
    data.docs.forEach(
      (documentSnapshot) {
        final dataMap = documentSnapshot.data();
        if (dataMap != null) {
          ProjectModel model =
              ProjectModel.fromMap(dataMap as Map<String, dynamic>);
          model.id = documentSnapshot.id;
          projectsList.add(model);
        }
      },
    );
  });
  return projectsList;
}

Stream<List<ProjectModel>> getRecurringEvents({
  required String parentEventId,
}) async* {
  var query = CollectionRef.projects
      .where('parentEventId', isEqualTo: parentEventId)
      .orderBy("start_time", descending: false);

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<ProjectModel>>.fromHandlers(
      handleData: (snapshot, projectSink) {
        List<ProjectModel> projectsList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final dataMap = documentSnapshot.data();
            if (dataMap != null) {
              ProjectModel model =
                  ProjectModel.fromMap(dataMap as Map<String, dynamic>);
              model.id = documentSnapshot.id;
              projectsList.add(model);
            }
          },
        );
        projectSink.add(projectsList);
      },
    ),
  );
}

Stream<ProjectModelList> getAllProjectListStream(
    {required String timebankid,
    required bool isAdminOrOwner,
    required BuildContext context}) async* {
  var query = CollectionRef.projects
      .where('timebanksPosted', arrayContains: timebankid)
      .where('softDelete', isEqualTo: false)
      .where('autoGenerated', isEqualTo: false)
      .orderBy("created_at", descending: true);

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, ProjectModelList>.fromHandlers(
      handleData: (snapshot, projectSink) {
        List<ProjectModel> projectsList = [];
        List<ProjectModel> completedProjectsList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final dataMap = documentSnapshot.data();
            if (dataMap != null) {
              ProjectModel model =
                  ProjectModel.fromMap(dataMap as Map<String, dynamic>);
              model.id = documentSnapshot.id;
              final endTime = model.endTime;
              if (endTime != null) {
                DateTime endDate = DateTime.fromMillisecondsSinceEpoch(endTime);

                //filter events in a range of 12 months
                if (endDate.isAfter(
                        DateTime.now().subtract(Duration(days: 365))) &&
                    endDate.isBefore(DateTime.now())) {
                  if (isAdminOrOwner ||
                      (model.associatedmembers?.containsKey(
                              SevaCore.of(context).loggedInUser.sevaUserID) ??
                          false) ||
                      (model.members?.contains(
                              SevaCore.of(context).loggedInUser.sevaUserID) ??
                          false) ||
                      model.creatorId ==
                          SevaCore.of(context).loggedInUser.sevaUserID) {
                    completedProjectsList.add(model);
                  }
                } else if (endDate.isAfter(DateTime.now())) {
                  projectsList.add(model);
                }
              }
            }
          },
        );
        projectSink.add(ProjectModelList(projectsList, completedProjectsList));
      },
    ),
  );
}

Stream<List<ProjectModel>> getPublicProjects(String sevaUserID) async* {
  var data = CollectionRef.projects
      .where('public', isEqualTo: true)
      .where('autoGenerated', isEqualTo: false)
      .where('softDelete', isEqualTo: false)
      .orderBy('start_time', descending: true)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<ProjectModel>>.fromHandlers(
      handleData: (snapshot, projectSink) {
        List<ProjectModel> projectsList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            final dataMap = documentSnapshot.data();
            if (dataMap != null) {
              ProjectModel model =
                  ProjectModel.fromMap(dataMap as Map<String, dynamic>);
              model.id = documentSnapshot.id;
              final endTime = model.endTime;
              if (endTime != null) {
                DateTime endDate = DateTime.fromMillisecondsSinceEpoch(endTime);

                //main explore page horizontal section
                if (endDate.isBefore(DateTime.now())) {
                  if (sevaUserID != '' &&
                      (model.creatorId == sevaUserID ||
                          (model.members?.contains(sevaUserID) ?? false) ||
                          (model.associatedmembers?.containsKey(sevaUserID) ??
                              false))) {
                    if (AppConfig.isTestCommunity) {
                      if (model.liveMode == false) projectsList.add(model);
                    } else {
                      projectsList.add(model);
                    }
                  }
                } else {
                  if (AppConfig.isTestCommunity) {
                    if (model.liveMode == false) projectsList.add(model);
                  } else {
                    projectsList.add(model);
                  }
                }
              }
            }
          },
        );
        projectSink.add(projectsList);
      },
    ),
  );
}

Stream<List<RequestModel>> getPublicRequests() async* {
  var data = CollectionRef.requests
      .where('accepted', isEqualTo: false)
      .where('public', isEqualTo: true)
      .where('softDelete', isEqualTo: false)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            RequestModel model = RequestModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            model.id = documentSnapshot.id;
            if (AppConfig.isTestCommunity) {
              if (model.liveMode == false) {
                requestList.add(model);
              }
            } else {
              requestList.add(model);
            }
          },
        );
        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<OfferModel>> getPublicOffers() async* {
  var data = CollectionRef.offers
      .where('public', isEqualTo: true)
      .where('softDelete', isEqualTo: false)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<OfferModel>>.fromHandlers(
      handleData: (snapshot, offerSink) {
        List<OfferModel> offerList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            OfferModel model = OfferModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            model.id = documentSnapshot.id;
            if (AppConfig.isTestCommunity) {
              if (model.liveMode == false) {
                offerList.add(model);
              }
            } else {
              offerList.add(model);
            }
          },
        );
        offerSink.add(offerList);
      },
    ),
  );
}

Future<List<ProjectModel>> getUserPersonalProjectsListFuture(
    {required String timebankid, required String sevauserid}) async {
  List<ProjectModel> projectsList = [];
  QuerySnapshot data = await CollectionRef.projects
      .where('timebank_id', isEqualTo: timebankid)
      .where('softDelete', isEqualTo: false)
      .where("creator_id", isEqualTo: sevauserid)
      .where("mode", isEqualTo: "Personal")
      .get();

  if (data.docs.length > 0) {
    data.docs.forEach(
      (documentSnapshot) {
        ProjectModel model = ProjectModel.fromMap(
            documentSnapshot.data() as Map<String, dynamic>);
        model.id = documentSnapshot.id;
        projectsList.add(model);
      },
    );
  }
  return projectsList;
}

Future<List<ProjectModel>> getAllProjectListFuture({String? timebankid}) async {
  List<ProjectModel> projectsList = [];
  await CollectionRef.projects
      .where('timebank_id', isEqualTo: timebankid)
      .where('softDelete', isEqualTo: false)
      .orderBy("created_at", descending: true)
      .get()
      .then((data) {
    data.docs.forEach(
      (documentSnapshot) {
        ProjectModel model = ProjectModel.fromMap(
            documentSnapshot.data() as Map<String, dynamic>);
        model.id = documentSnapshot.id;
        projectsList.add(model);
      },
    );
  });
  return projectsList;
}

Stream<List<RequestModel>> getTimebankRequestListStream(
    {String? timebankId}) async* {
  var query = CollectionRef.requests
      .where('timebankId', isEqualTo: timebankId)
      .where('accepted', isEqualTo: false);

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            RequestModel model = RequestModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            model.id = documentSnapshot.id;
            if (model.approvedUsers != null) {
              if (model.approvedUsers!.length <= (model.numberOfApprovals ?? 0))
                requestList.add(model);
            }
          },
        );

        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<RequestModel>> getTimebankExistingRequestListStream(
    {String? timebankId}) async* {
  var query = CollectionRef.requests
      .where('timebanksPosted', arrayContains: timebankId)
      .where('accepted', isEqualTo: false)
      .where('requestMode', isEqualTo: 'TIMEBANK_REQUEST');

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            RequestModel model = RequestModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            model.id = documentSnapshot.id;
            if (model.approvedUsers != null &&
                model.requestType == RequestType.TIME) {
              if (model.approvedUsers!.length <= model.numberOfApprovals!)
                requestList.add(model);
            }
          },
        );

        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<RequestModel>> getPersonalRequestListStream(
    {String? sevauserid}) async* {
  var query = CollectionRef.requests
      .where('sevauserid', isEqualTo: sevauserid)
      .where('accepted', isEqualTo: false)
      .where('requestMode', isEqualTo: 'PERSONAL_REQUEST');
  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            RequestModel model = RequestModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            model.id = documentSnapshot.id;
            if (model.approvedUsers != null) {
              if (model.approvedUsers!.length <= model.numberOfApprovals!)
                requestList.add(model);
            }
          },
        );
        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<RequestModel>> getProjectRequestsStream(
    {String? project_id}) async* {
  var query = CollectionRef.requests
      .where('projectId', isEqualTo: project_id)
      .where('accepted', isEqualTo: false)
      .where('autoGenerated', isEqualTo: false)
      .where('softDelete', isEqualTo: false);

  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            RequestModel model = RequestModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            model.id = documentSnapshot.id;
            if (model.approvedUsers != null) {
              if (model.approvedUsers!.length <= model.numberOfApprovals!)
                requestList.add(model);
            }
          },
        );
        requestSink.add(requestList);
      },
    ),
  );
}

Future<void> sendOfferRequest({
  required OfferModel offerModel,
  required String requestSevaID,
  required String communityId,
  bool directToMember = true,
}) async {
  NotificationsModel model = NotificationsModel(
    timebankId: offerModel.timebankId,
    targetUserId: offerModel.sevaUserId,
    data: offerModel.toMap(),
    type: NotificationType.OfferAccept,
    id: utils.Utils.getUuid(),
    isRead: false,
    senderUserId: requestSevaID,
    communityId: communityId,
  );
  await utils.offerAcceptNotification(
    model: model,
  );
}

Future<void> acceptRequest({
  required UserModel loggedInUser,
  required bool isAlreadyApproved,
  required RequestModel requestModel,
  required String senderUserId,
  bool isWithdrawal = false,
  bool fromOffer = false,
  required String communityId,
  required bool directToMember,
  required AcceptorModel acceptorModel,
}) async {
  await CollectionRef.requests
      .doc(requestModel.id)
      .update(requestModel.toMap());

  if (!fromOffer) {
    NotificationsModel model = NotificationsModel(
        timebankId: requestModel.timebankId ?? '',
        targetUserId: requestModel.sevaUserId ?? '',
        data: requestModel.toMap(),
        type: NotificationType.RequestAccept,
        id: utils.Utils.getUuid(),
        isRead: false,
        senderUserId: senderUserId,
        communityId: communityId);
    if (requestModel.requestMode == RequestMode.TIMEBANK_REQUEST) {
      model.isTimebankNotification = true;
    } else {
      model.isTimebankNotification = false;
    }

    if (isWithdrawal)
      await utils.withdrawAcceptRequestNotification(
          notificationsModel: model,
          isAlreadyApproved: isAlreadyApproved,
          loggedInUser: loggedInUser);
    else
      await utils.createAcceptRequestNotification(
        notificationsModel: model,
      );
  }
}

Future<void> requestComplete({
  required RequestModel model,
}) async {
  await CollectionRef.requests
      .doc(model.id)
      .set(model.toMap(), SetOptions(merge: true));
}

Future<void> borrowRequestFeedbackLenderUpdate({
  required RequestModel model,
}) async {
  await CollectionRef.requests.doc(model.id).update({
    'lenderReviewed': true,
  });
}

Future<void> borrowRequestFeedbackBorrowerUpdate({
  required RequestModel model,
}) async {
  await CollectionRef.requests.doc(model.id).update({
    'borrowerReviewed': true,
  });
}

Future<void> storeAcceptorDataBorrowRequest(
    {required RequestModel model,
    required BorrowAcceptorModel borrowAcceptorModel}) async {
  await CollectionRef.requests
      .doc(model.id)
      .collection('borrowRequestAcceptors')
      .doc(borrowAcceptorModel.acceptorEmail)
      .set(borrowAcceptorModel.toMap());
}

Future<void> removeAcceptorDataBorrowRequest(
    {required RequestModel requestModel, required String acceptorEmail}) async {
  await CollectionRef.requests
      .doc(requestModel.id)
      .collection('borrowRequestAcceptors')
      .doc(acceptorEmail)
      .delete();

  logger.e('REMOVED ACCEPTOR FROM borrowRequestAcceptors subcollection');
}

//accept borrow request (currently used in personal notifications)
Future<void> acceptBorrowRequest({
  required RequestModel requestModel,
  required TimebankModel timebankModel,
  required BuildContext context,
}) async {
  final acceptorsList = requestModel.acceptors ?? <String>[];
  Set<String> acceptorList = Set<String>.from(acceptorsList);
  final userEmail = SevaCore.of(context).loggedInUser.email ?? '';
  acceptorList.add(userEmail);

  requestModel.acceptors = acceptorList.toList();
  AcceptorModel acceptorModel = AcceptorModel(
    sevauserid: SevaCore.of(context).loggedInUser.sevaUserID ?? '',
    memberPhotoUrl: SevaCore.of(context).loggedInUser.photoURL ?? '',
    communityId: SevaCore.of(context).loggedInUser.currentCommunity ?? '',
    communityName: timebankModel.name ?? '',
    memberName: SevaCore.of(context).loggedInUser.fullname ?? '',
    memberEmail: userEmail,
    timebankId: timebankModel.id ?? '',
  );
  requestModel.participantDetails ??= {};
  requestModel.participantDetails![userEmail] = acceptorModel.toMap();

  await acceptRequest(
    loggedInUser: SevaCore.of(context).loggedInUser,
    isAlreadyApproved: false,
    requestModel: requestModel,
    senderUserId: SevaCore.of(context).loggedInUser.sevaUserID ?? '',
    communityId: requestModel.communityId ?? '',
    directToMember: !(timebankModel.protected ?? false),
    acceptorModel: acceptorModel,
  );
}

List<TransactionModel> updateListTransactionsCreditsAsPerTimebankTaxPolicy({
  required List<TransactionModel> originalModel,
  required double credits,
  required String userIdToBeCredited,
  required double userAmout,
}) {
  List<TransactionModel> modelTransactions =
      originalModel.map((f) => f).toList();

  return modelTransactions.map((t) {
    if (t.to == userIdToBeCredited) {
      TransactionModel editedTransaction = t;
      editedTransaction.credits = userAmout;
      return editedTransaction;
    }
    return t;
  }).toList();
}

Future<void> approveRequestCompletion({
  required RequestModel model,
  required String userId,
  required String communityId,
  required String memberCommunityId,
  // required num taxPercentage,
}) async {
  final transactionsList = model.transactions ?? <TransactionModel>[];
  List<TransactionModel> transactions = transactionsList.map((t) => t).toList();
  late TransactionModel editedTransaction;

  double transactionvalue = (model.durationOfRequest ?? 0) / 60;

  model.transactions = transactions.map((t) {
    if (t.to == userId) {
      editedTransaction = t;
      editedTransaction.credits = transactionvalue;
      editedTransaction.isApproved = true;
      return editedTransaction;
    }
    return t;
  }).toList();

  var approvalCount = 0;
  if (model.transactions != null) {
    for (var i = 0; i < model.transactions!.length; i++) {
      if (model.transactions![i].isApproved == true) {
        approvalCount++;
      }
    }
  }

  model.accepted = approvalCount >= (model.numberOfApprovals ?? 0);

  TimeBankBalanceTransactionModel? balanceTransactionModel;
  var updatedRequestModel = model;

  if (model.requestMode == RequestMode.TIMEBANK_REQUEST) {
    balanceTransactionModel = TimeBankBalanceTransactionModel(
      communityId: communityId,
      userId: userId,
      requestId: model.id ?? '',
      amount: transactionvalue,
      timestamp: FieldValue.serverTimestamp(),
    );

    updatedRequestModel.transactions =
        updateListTransactionsCreditsAsPerTimebankTaxPolicy(
      credits: transactionvalue,
      originalModel: model.transactions ?? <TransactionModel>[],
      userAmout: transactionvalue,
      userIdToBeCredited: userId,
    );

    TransactionBloc().createNewTransaction(
      FlavorConfig.values.timebankId,
      model.timebankId ?? '',
      DateTime.now().millisecondsSinceEpoch,
      transactionvalue,
      true,
      "REQUEST_CREATION_TIMEBANK_FILL_CREDITS",
      FlavorConfig.values.timebankId,
      model.timebankId ?? '',
      communityId: communityId,
      fromEmailORId: model.timebankId ?? '',
      toEmailORId: model.timebankId ?? '',
    );

    TransactionBloc().createNewTransaction(
        model.timebankId ?? '',
        userId,
        DateTime.now().millisecondsSinceEpoch,
        transactionvalue,
        true,
        "TIME_REQUEST",
        model.id ?? '',
        model.timebankId ?? '',
        communityId: communityId,
        fromEmailORId: model.timebankId ?? '',
        toEmailORId: model.timebankId ?? '',
        offerId: model.offerId ?? '');
    // adds review to firestore
  } else if (model.requestMode == RequestMode.PERSONAL_REQUEST) {
    TransactionBloc().createNewTransaction(
        model.sevaUserId ?? '',
        userId,
        DateTime.now().millisecondsSinceEpoch,
        transactionvalue,
        true,
        "TIME_REQUEST",
        model.id ?? '',
        model.timebankId ?? '',
        communityId: communityId,
        fromEmailORId: model.timebankId ?? '',
        toEmailORId: model.timebankId ?? '',
        offerId: model.offerId ?? '');
  }

  NotificationsModel notification = NotificationsModel(
    timebankId: model.timebankId ?? '',
    id: utils.Utils.getUuid(),
    targetUserId: userId,
    senderUserId: model.sevaUserId ?? '',
    type: NotificationType.RequestCompletedApproved,
    data: model.toMap(),
    communityId: memberCommunityId,
  );

  Map<String, dynamic> transactionData =
      (model.transactions ?? <TransactionModel>[])
          .where((transactionModel) {
            if (transactionModel.from == model.sevaUserId &&
                transactionModel.to == userId) {
              return true;
            } else {
              return false;
            }
          })
          .elementAt(0)
          .toMap();

  //Create transaction record for timebank

  if (model.requestMode == RequestMode.TIMEBANK_REQUEST &&
      balanceTransactionModel != null) {
    CollectionRef.timebank.doc(model.timebankId).collection("balance").add(
          balanceTransactionModel.toJson(),
        );
  } else {
    // NotificationsModel debitnotification = NotificationsModel(
    //   timebankId: model.timebankId ?? '',
    //   id: utils.Utils.getUuid(),
    //   targetUserId: model.sevaUserId ?? '',
    //   senderUserId: userId,
    //   communityId: communityId,
    //   type: NotificationType.TransactionDebit,
    //   data: transactionData,
    // );
    // await utils.createTransactionNotification(model: debitnotification);
  }

  //User gets a notification with amount after tax deducation
  transactionData["credits"] = transactionvalue;

  await CollectionRef.requests.doc(model.id).set(
        model.requestMode == RequestMode.PERSONAL_REQUEST
            ? model.toMap()
            : updatedRequestModel.toMap(),
        SetOptions(merge: true),
      );
  await utils.createTaskCompletedApprovedNotification(model: notification);
}

Future<void> approveAcceptRequest({
  required RequestModel requestModel,
  required String approvedUserId,
  required String notificationId,
  required String communityId,
  bool directToMember = false,
}) async {
  var approvalCount = 0;
  if (requestModel.transactions != null) {
    for (var i = 0; i < requestModel.transactions!.length; i++) {
      if (requestModel.transactions![i].isApproved!) {
        approvalCount++;
      }
    }
  }
  requestModel.accepted = approvalCount >= requestModel.numberOfApprovals!;
  await CollectionRef.requests
      .doc(requestModel.id)
      .update(requestModel.toMap());

  var timebankModel = await fetchTimebankData(requestModel.timebankId!);
  var tempRequestModel = requestModel;

  if (timebankModel.protected) {
    tempRequestModel.photoUrl = timebankModel.photoUrl;
    tempRequestModel.fullName = timebankModel.name;
  }

  NotificationsModel model = NotificationsModel(
    timebankId: requestModel.timebankId,
    id: utils.Utils.getUuid(),
    targetUserId: approvedUserId,
    communityId: communityId,
    senderUserId: requestModel.sevaUserId,
    type: NotificationType.RequestApprove,
    data: tempRequestModel.toMap(),
  );

  await utils.removeAcceptRequestNotification(
    model: model,
    notificationId: notificationId,
  );
  await utils.createRequestApprovalNotification(model: model);
}

Future<void> approveAcceptRequestForTimebank({
  required RequestModel requestModel,
  required String approvedUserId,
  required String notificationId,
  required String communityId,
}) async {
  var approvalCount = 0;
  if (requestModel.transactions != null) {
    for (var i = 0; i < requestModel.transactions!.length; i++) {
      if (requestModel.transactions![i].isApproved!) {
        approvalCount++;
      }
    }
  }

  log('BOOLEAN CHECK: ' + (requestModel.approvedUsers!.isEmpty).toString());

  requestModel.requestType == RequestType.BORROW
      ? null //requestModel.accepted = requestModel.approvedUsers.length >= requestModel.numberOfApprovals
      : requestModel.accepted =
          approvalCount >= requestModel.numberOfApprovals!;

  await CollectionRef.requests
      .doc(requestModel.id)
      .update(requestModel.toMap());

  var timebankModel = await fetchTimebankData(requestModel.timebankId!);
  var tempTimebankModel = requestModel;
  tempTimebankModel.photoUrl = timebankModel.photoUrl;
  tempTimebankModel.fullName = timebankModel.name;

  NotificationsModel model = NotificationsModel(
    isTimebankNotification:
        requestModel.requestMode == RequestMode.TIMEBANK_REQUEST,
    timebankId: requestModel.timebankId,
    id: utils.Utils.getUuid(),
    targetUserId: approvedUserId,
    communityId: communityId,
    senderUserId: tempTimebankModel.sevaUserId,
    type: NotificationType.RequestApprove,
    data: tempTimebankModel.toMap(),
  );

  await utils.readTimeBankNotification(
    timebankId: requestModel.timebankId,
    notificationId: notificationId,
  );
  await utils.createApprovalNotificationForMember(model: model);
}

Future<void> rejectAcceptRequest({
  required RequestModel requestModel,
  required String rejectedUserId,
  required String notificationId,
  required String communityId,
}) async {
  await CollectionRef.requests
      .doc(requestModel.id)
      .update(requestModel.toMap());

  var tempRequestModel = requestModel;
  if (requestModel.requestMode == RequestMode.TIMEBANK_REQUEST) {
    var timebankModel = await fetchTimebankData(requestModel.timebankId!);
    tempRequestModel.photoUrl = timebankModel.photoUrl;
    tempRequestModel.fullName = timebankModel.name;
  }

  NotificationsModel model = NotificationsModel(
    timebankId: requestModel.timebankId,
    id: utils.Utils.getUuid(),
    targetUserId: rejectedUserId,
    senderUserId: requestModel.sevaUserId,
    type: NotificationType.RequestReject,
    data: tempRequestModel.toMap(),
    communityId: communityId,
  );

  await utils.removeAcceptRequestNotification(
    model: model,
    notificationId: notificationId,
  );
  await utils.createRequestApprovalNotification(model: model);
}

Future<void> rejectInviteRequestForOffer({
  required String requestId,
  required String rejectedUserId,
  required String notificationId,
}) async {
  await CollectionRef.requests.doc(requestId).update({
    'invitedUsers': FieldValue.arrayRemove([rejectedUserId])
  });
}

Future<void> rejectInviteRequest(
    {required String requestId,
    required String rejectedUserId,
    required String notificationId,
    required String acceptedUserEmail,
    required RequestInvitationModel model}) async {
  var batch = CollectionRef.batch;

  if (model.requestModel!.requestType == RequestType.ONE_TO_MANY_REQUEST) {
    batch.delete(
      CollectionRef.requests
          .doc(requestId)
          .collection('oneToManyAttendeesDetails')
          .doc(acceptedUserEmail),
    );

    batch.update(CollectionRef.requests.doc(requestId), {
      'invitedUsers': FieldValue.arrayRemove([rejectedUserId])
    });
    batch.commit();
  } else {
    await CollectionRef.requests.doc(requestId).update({
      'invitedUsers': FieldValue.arrayRemove([rejectedUserId])
    });
  }
}

Future<void> acceptOfferInvite({
  required String requestId,
  required String acceptedUserEmail,
  required String acceptedUserId,
  required String notificationId,
  required bool allowedCalender,
  required AcceptorModel acceptorModel,
  UserModel? user,
}) async {
  // logger.i("acceptInviteRequest LEVEL |||||||||||||||||||||");

  if (allowedCalender) {
    // logger.i("allowedCalender is true");
    await CollectionRef.requests.doc(requestId).update({
      'approvedUsers': FieldValue.arrayUnion([acceptedUserEmail]),
      'allowedCalenderUsers': FieldValue.arrayUnion([acceptedUserEmail]),
      'invitedUsers': FieldValue.arrayRemove([acceptedUserId])
    });
  } else {
    // logger.i("Updating request with requestId approved members " +
    // acceptedUserEmail);

    await CollectionRef.requests.doc(requestId).update({
      'approvedUsers': FieldValue.arrayUnion([acceptedUserEmail]),
      'invitedUsers': FieldValue.arrayRemove([acceptedUserId])
    });
  }
}

Future<void> acceptInviteRequest({
  required String requestId,
  required String acceptedUserEmail,
  required String acceptedUserId,
  required String notificationId,
  required bool allowedCalender,
  required AcceptorModel acceptorModel,
  RequestInvitationModel? model,
  UserModel? user,
}) async {
  var batch = CollectionRef.batch;

  BasicUserDetails attendeeObject = BasicUserDetails(
    fullname: user?.fullname ?? '',
    email: user?.email ?? '',
    photoURL: user?.photoURL ?? '',
    sevaUserID: user?.sevaUserID ?? '',
  );

  if (model!.requestModel!.requestType == RequestType.ONE_TO_MANY_REQUEST) {
    batch.set(
        CollectionRef.requests
            .doc(requestId)
            .collection('oneToManyAttendeesDetails')
            .doc(acceptedUserEmail),
        attendeeObject.toMap());

    if (allowedCalender) {
      batch.update(CollectionRef.requests.doc(requestId), {
        //'approvedUsers': FieldValue.arrayUnion([acceptedUserEmail]),
        'allowedCalenderUsers': FieldValue.arrayUnion([acceptedUserEmail]),
        'oneToManyRequestAttenders': FieldValue.arrayUnion([acceptedUserEmail]),
        'participantDetails': {acceptedUserEmail: acceptorModel.toMap()},
        'invitedUsers': FieldValue.arrayRemove([acceptedUserId])
      });
    } else {
      batch.update(CollectionRef.requests.doc(requestId), {
        'oneToManyRequestAttenders': FieldValue.arrayUnion([acceptedUserEmail]),
        'participantDetails': {acceptedUserEmail: acceptorModel.toMap()},
        'invitedUsers': FieldValue.arrayRemove([acceptedUserId])
      });
    }

    batch.commit();

    log('request accept one to many stored attendee details');
  } else {
    if (allowedCalender) {
      await CollectionRef.requests.doc(requestId).set({
        'approvedUsers': FieldValue.arrayUnion([acceptedUserEmail]),
        'allowedCalenderUsers': FieldValue.arrayUnion([acceptedUserEmail]),
        'invitedUsers': FieldValue.arrayRemove([acceptedUserId]),
        'participantDetails': {acceptedUserEmail: acceptorModel.toMap()}
      }, SetOptions(merge: true));
    } else {
      await CollectionRef.requests.doc(requestId).set({
        'approvedUsers': FieldValue.arrayUnion([acceptedUserEmail]),
        'invitedUsers': FieldValue.arrayRemove([acceptedUserId]),
        'participantDetails': {acceptedUserEmail: acceptorModel.toMap()}
      }, SetOptions(merge: true));
    }
  }
}

Future<RequestModel> getRequestFutureById({
  required String requestId,
}) async {
  var documentsnapshot = await CollectionRef.requests.doc(requestId).get();

  return RequestModel.fromMap(documentsnapshot.data() as Map<String, dynamic>);
}

Future<ProjectModel> getProjectFutureById({
  required String projectId,
}) async {
  var documentsnapshot = await CollectionRef.projects.doc(projectId).get();

  return ProjectModel.fromMap(documentsnapshot.data() as Map<String, dynamic>);
}

Future<ProjectTemplateModel> getProjectTemplateById(
    {required String templateId}) async {
  assert(templateId != null && templateId.isNotEmpty,
      "template id cannot be null or empty");

  ProjectTemplateModel? projectTemplateModel;
  await CollectionRef.projectTemplates
      .where('id', isEqualTo: templateId)
      .get()
      .then((QuerySnapshot querySnapshot) {
    querySnapshot.docs.forEach((DocumentSnapshot documentSnapshot) {
      projectTemplateModel = ProjectTemplateModel.fromMap(
          documentSnapshot.data() as Map<String, dynamic>);
    });
  });

  if (projectTemplateModel == null) {
    throw Exception('ProjectTemplateModel not found for id: $templateId');
  }
  return projectTemplateModel!;
}

Stream<RequestModel> getRequestStreamById({
  required String requestId,
}) async* {
  var data = CollectionRef.requests.doc(requestId).snapshots();

  yield* data.transform(
    StreamTransformer<DocumentSnapshot, RequestModel>.fromHandlers(
      handleData: (snapshot, requestSink) {
        RequestModel model =
            RequestModel.fromMap(snapshot.data() as Map<String, dynamic>);
        model.id = snapshot.id;
        requestSink.add(model);
      },
    ),
  );
}

Stream<ProjectModel> getProjectStream({
  notifications,
  required String projectId,
}) async* {
  var data = CollectionRef.projects.doc(projectId).snapshots();

  yield* data.transform(
    StreamTransformer<DocumentSnapshot, ProjectModel>.fromHandlers(
      handleData: (snapshot, requestSink) {
        ProjectModel model =
            ProjectModel.fromMap(snapshot.data() as Map<String, dynamic>);
        model.id = snapshot.id;
        requestSink.add(model);
      },
    ),
  );
}

Future<void> createProjectTemplate(
    {required ProjectTemplateModel projectTemplateModel}) async {
  return await CollectionRef.projectTemplates
      .doc(projectTemplateModel.id)
      .set(projectTemplateModel.toMap());
}

Future<void> createBorrowAgreementTemplate(
    {required AgreementTemplateModel agreementTemplateModel}) async {
  return await CollectionRef.agreementTemplates
      .doc(agreementTemplateModel.id)
      .set(agreementTemplateModel.toMap());
}

//       .set(borrowAgreementTemplateModel.toMap());
// }

Future<void> createBorrowAgreementTemplateNullable(
    {required AgreementTemplateModel? agreementTemplateModel}) async {
  if (agreementTemplateModel == null) {
    throw Exception('AgreementTemplateModel cannot be null');
  }
  return await CollectionRef.agreementTemplates
      .doc(agreementTemplateModel.id)
      .set(agreementTemplateModel.toMap());
}

Future<void> createProject({required ProjectModel projectModel}) async {
  return await CollectionRef.projects
      .doc(projectModel.id)
      .set(projectModel.toMap());
}

Future<void> updateProject({required ProjectModel projectModel}) async {
  return await CollectionRef.projects
      .doc(projectModel.id)
      .update(projectModel.toMap());
}

Future<void> updateProjectCompletedRequest(
    {required String projectId, required String requestId}) async {
  return await CollectionRef.projects.doc(projectId).update({
    'completedRequests': FieldValue.arrayUnion(
      [requestId],
    ),
    'pendingRequests': FieldValue.arrayRemove([requestId])
  });
}

Future<void> updateProjectPendingRequest(
    {required String projectId, required String requestId}) async {
  return await CollectionRef.projects.doc(projectId).update({
    'pendingRequests': FieldValue.arrayUnion(
      [requestId],
    ),
  });
}

/// Get all timebanknew associated with a User as a Stream
Stream<List<RequestModel>> getCompletedRequestStream({
  required String userEmail,
  required String userId,
}) async* {
  var data = CollectionRef.requests
      // .where('transactions.to', isEqualTo: userId)
      // .where('transactions', arrayContains: {'to': '6TSPDyOpdQbUmBcDwfwEWj7Zz0z1', 'isApproved': true})
      //.where('transactions', arrayContains: true)
      .where('approvedUsers', arrayContains: userEmail)
      .where("root_timebank_id", isEqualTo: FlavorConfig.values.timebankId)
      // .where('timebankId', isEqualTo: FlavorConfig.values.timebankId)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach((document) {
          RequestModel model =
              RequestModel.fromMap(document.data() as Map<String, dynamic>);
          model.id = document.id;
          bool isRequestCompleted = false;

          model.transactions?.forEach((transaction) {
            if (transaction.isApproved! && transaction.to == userId)
              isRequestCompleted = true;
          });

          (model.accepted == true && model.requestType == RequestType.BORROW)
              ? requestList.add(model)
              : null;

          if (isRequestCompleted) requestList.add(model);
        });
        log('REQUESTS LIST COMPLETED:  ' + requestList.toString());
        requestSink.add(requestList);
      },
    ),
  );
}

Stream<List<TransactionModel>> getTimebankCreditsDebitsStream({
  required String timebankid,
  required String userId,
}) async* {
  log("==========================>>>>>>>>>> getTimebankCreditsDebitsStream");
  var data = CollectionRef.transactions
      .where("isApproved", isEqualTo: true)
      .where('transactionbetween', arrayContains: timebankid)
      .orderBy("timestamp", descending: true)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<TransactionModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<TransactionModel> requestList = [];
        snapshot.docs.forEach((document) {
          TransactionModel model =
              TransactionModel.fromMap(document.data() as Map<String, dynamic>);
          log('tyoe id ${model.typeid}');

          requestList.add(model);
        });
        requestSink.add(requestList);
        //
      },
    ),
  );
}

Stream<List<TransactionModel>> getUsersCreditsDebitsStream({
  String? userEmail,
  required String userId,
}) async* {
  var data;
  if (AppConfig.isTestCommunity) {
    data = CollectionRef.transactions
        .where("isApproved", isEqualTo: true)
        .where('transactionbetween', arrayContains: userId)
        .where('liveMode', isEqualTo: false)
        .orderBy("timestamp", descending: true)
        .snapshots();
  } else {
    data = CollectionRef.transactions
        .where("isApproved", isEqualTo: true)
        .where('transactionbetween', arrayContains: userId)
        .where('liveMode', isEqualTo: true)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<TransactionModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<TransactionModel> requestList = [];
        snapshot.docs.forEach((document) {
          TransactionModel model =
              TransactionModel.fromMap(document.data() as Map<String, dynamic>);
          log('tyoe id ${model.typeid}');
          requestList.add(model);
        });
        requestSink.add(requestList);

        //
      },
    ),
  );
}

///NOTE Removed as a part of version 1.1 update as balance should be a meta not through calculation

Stream<List<RequestModel>> getNotAcceptedRequestStream({
  String? userEmail,
  required String userId,
}) async* {
  var data = CollectionRef.requests
      .where('acceptors', arrayContains: userEmail)
      .where("root_timebank_id", isEqualTo: FlavorConfig.values.timebankId)
      // .where('timebankId', isEqualTo: FlavorConfig.values.timebankId)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestList = [];
        snapshot.docs.forEach((document) {
          RequestModel model =
              RequestModel.fromMap(document.data() as Map<String, dynamic>);
          model.id = document.id;
          bool isApproved = false;
          if (model.approvedUsers!.contains(userEmail)) {
            isApproved = true;
          }
          if (!isApproved) requestList.add(model);
        });
        requestSink.add(requestList);
      },
    ),
  );
}

//getALl the categories
Future<List<CategoryModel>> getAllCategories(String languageCode) async {
  List<CategoryModel> categories = [];

  await CollectionRef.requestCategories.get().then((data) {
    data.docs.forEach(
      (documentSnapshot) {
        final dataMap = documentSnapshot.data() as Map<String, dynamic>;
        if (dataMap["title_" + languageCode] != null) {
          CategoryModel model = CategoryModel.fromMap(dataMap);
          model.typeId = documentSnapshot.id;
          categories.add(model);

          //  model.typeId = documentSnapshot.id;
          //categories.add(model);
        }
      },
    );
  });
  return categories;
}

/// Get a particular category by it's ID
Future<CategoryModel> getCategoryForId({required String categoryID}) async {
  CategoryModel? categoryModel;
  await CollectionRef.requestCategories
      .doc(categoryID)
      .get()
      .then((DocumentSnapshot documentSnapshot) {
    Map<String, dynamic> dataMap =
        documentSnapshot.data() as Map<String, dynamic>;
    categoryModel = CategoryModel.fromMap(dataMap);
    categoryModel!.typeId = documentSnapshot.id;
  });

  if (categoryModel == null) {
    throw Exception('CategoryModel not found for id: $categoryID');
  }
  return categoryModel!;
}

//Add new user defined request category
Future<void> addNewRequestCategory(
    Map<String, dynamic> newModel, String typeId) async {
  await CollectionRef.requestCategories.doc(typeId).set(newModel);
}

//Edit user defined request category
Future<void> editRequestCategory(
    Map<String, dynamic> newModel, String typeId) async {
  await CollectionRef.requestCategories.doc(typeId).update(newModel);
}

Future oneToManyCreatorRequestCompletionRejectedTimebankNotifications(
    RequestModel requestModel,
    context,
    UserModel userModel,
    bool fromNotification) async {
  showDialog(
      barrierDismissible: false,
      context: context,
      builder: (createDialogContext) {
        dialogContext = createDialogContext;
        return AlertDialog(
          title: Text(S.of(context).loading),
          content: LinearProgressIndicator(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        );
      });

  //Send notification OneToManyCreatorRejectedCompletion
  //and speaker enters hours again and sends same completed notitifiation to creator

  UserModel speakerModel = await FirestoreManager.getUserForId(
      sevaUserId: requestModel.selectedInstructor!.sevaUserID!);

  if (speakerModel.communities!.contains(requestModel.communityId)) {
    log('in community');

    NotificationsModel notificationModel = NotificationsModel(
        timebankId: requestModel.timebankId,
        targetUserId: requestModel.selectedInstructor!.sevaUserID,
        data: requestModel.toMap(),
        type: NotificationType.OneToManyCreatorRejectedCompletion,
        id: utils.Utils.getUuid(),
        isRead: false,
        senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
        communityId: requestModel.communityId,
        isTimebankNotification: false);

    await CollectionRef.users
        .doc(requestModel.selectedInstructor!.email)
        .collection('notifications')
        .doc(notificationModel.id)
        .set(notificationModel.toMap());
  } else {
    log('outisde community');

    NotificationsModel notificationModel = NotificationsModel(
        timebankId: FlavorConfig.values.timebankId,
        targetUserId: requestModel.selectedInstructor!.sevaUserID,
        data: requestModel.toMap(),
        type: NotificationType.OneToManyCreatorRejectedCompletion,
        id: utils.Utils.getUuid(),
        isRead: false,
        senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
        communityId: FlavorConfig.values.timebankId,
        isTimebankNotification: false);

    await CollectionRef.users
        .doc(requestModel.selectedInstructor!.email)
        .collection('notifications')
        .doc(notificationModel.id)
        .set(notificationModel.toMap());
  }

  await CollectionRef.requests.doc(requestModel.id).update({
    'isSpeakerCompleted': false,
  });

  //make the relevant notification is read true
  await FirestoreManager
      .readTimeBankNotificationOneToManyCreatorRejectedCompletion(
          requestModel: requestModel, fromNotification: fromNotification);

  if (dialogContext != null) {
    Navigator.of(dialogContext).pop();
  }

  log('oneToManyCreatorRequestCompletionRejected end of function');
}

Future oneToManyCreatorRequestCompletionRejected(
    RequestModel requestModel, context) async {
  //Send notification OneToManyCreatorRejectedCompletion
  //and speaker enters hours again and sends same completed notitifiation to creator

  log('HERE HERE!');

  UserModel speakerModel = await FirestoreManager.getUserForId(
      sevaUserId: requestModel.selectedInstructor!.sevaUserID!);

  if (speakerModel.communities!.contains(requestModel.communityId)) {
    log('in community');

    NotificationsModel notificationModel = NotificationsModel(
        timebankId: requestModel.timebankId,
        targetUserId: requestModel.selectedInstructor!.sevaUserID,
        data: requestModel.toMap(),
        type: NotificationType.OneToManyCreatorRejectedCompletion,
        id: utils.Utils.getUuid(),
        isRead: false,
        senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
        communityId: requestModel.communityId,
        isTimebankNotification: false);

    await CollectionRef.users
        .doc(requestModel.selectedInstructor!.email)
        .collection('notifications')
        .doc(notificationModel.id)
        .set(notificationModel.toMap());
  } else {
    log('outisde community');

    NotificationsModel notificationModel = NotificationsModel(
        timebankId: FlavorConfig.values.timebankId,
        targetUserId: requestModel.selectedInstructor!.sevaUserID,
        data: requestModel.toMap(),
        type: NotificationType.OneToManyCreatorRejectedCompletion,
        id: utils.Utils.getUuid(),
        isRead: false,
        senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
        communityId: FlavorConfig.values.timebankId,
        isTimebankNotification: false);

    await CollectionRef.users
        .doc(requestModel.selectedInstructor!.email)
        .collection('notifications')
        .doc(notificationModel.id)
        .set(notificationModel.toMap());
  }

  await CollectionRef.requests.doc(requestModel.id).update({
    'isSpeakerCompleted': false,
  });

  log('oneToManyCreatorRequestCompletionRejected end of function');
}

//for one to many request when speaker has already claimed credits, so pending task
Stream<List<RequestModel>> getSpeakerClaimedCompletionRequestStream({
  required String userEmail,
  required String userId,
}) async* {
  var data = CollectionRef.requests
      .where('approvedUsers', arrayContains: userEmail)
      .where('isSpeakerCompleted', isEqualTo: true)
      .where('accepted', isEqualTo: false)
      // .where('timebankId', isEqualTo: FlavorConfig.values.timebankId)
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestListSpeakerClaimed = [];
        snapshot.docs.forEach((document) {
          RequestModel model =
              RequestModel.fromMap(document.data() as Map<String, dynamic>);
          requestListSpeakerClaimed.add(model);
        });
        requestSink.add(requestListSpeakerClaimed);
      },
    ),
  );
}

//for borrow request, request creator / Borrower needs to see in To do when needs to collect or check in
Stream<List<RequestModel>> getBorrowRequestCreatorToCollectReturnItems({
  required String userEmail,
  required String userId,
}) async* {
  var data = CollectionRef.requests
      .where('email', isEqualTo: userEmail)
      .where('approvedUsers', isNotEqualTo: [])
      .where('accepted', isEqualTo: false)
      .where('requestType', isEqualTo: 'BORROW')
      .snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<RequestModel> requestListBorrowerWaiting = [];
        snapshot.docs.forEach((document) {
          RequestModel model =
              RequestModel.fromMap(document.data() as Map<String, dynamic>);
          requestListBorrowerWaiting.add(model);
        });
        logger.e('--------> THISS:  ' +
            requestListBorrowerWaiting.length.toString());
        requestSink.add(requestListBorrowerWaiting);
      },
    ),
  );
}

//getALl the categories
Stream<List<CategoryModel>> getAllCategoriesStream(
    BuildContext context) async* {
  var key = S.of(context).localeName;

  var data = CollectionRef.requestCategories
      .where("type", isEqualTo: "subCategory")
      .orderBy("title_en", descending: false)
      .snapshots();

  yield* data.transform(
      StreamTransformer<QuerySnapshot, List<CategoryModel>>.fromHandlers(
    handleData: (snapshot, sink) {
      List<CategoryModel> categories = [];

      snapshot.docs.forEach((element) {
        final dataMap = element.data() as Map<String, dynamic>;
        final titleKey = "title_" + (key ?? 'en');
        if (dataMap[titleKey] != null) {
          CategoryModel model = CategoryModel.fromMap(dataMap);
          model.typeId = element.id;
          categories.add(model);
        }
      });
      sink.add(categories);
    },
  ));
}

Future<List<CategoryModel>> getSubCategoriesFuture(BuildContext context) async {
  var key = S.of(context).localeName;

  var data = await CollectionRef.requestCategories
      .where("type", isEqualTo: "subCategory")
      .get();
  List<CategoryModel> categories = [];
  data.docs.forEach((element) {
    final dataMap = element.data() as Map<String, dynamic>;
    final titleKey = "title_" + (key ?? 'en');
    if (dataMap[titleKey] != null) {
      CategoryModel model = CategoryModel.fromMap(dataMap);
      model.typeId = element.id;
      categories.add(model);
    }
  });
  logger.i("subCat length ${categories.length}");
  return categories;
}

Future lenderReceivedBackCheck(
    {NotificationsModel? notification,
    String? notificationId,
    required RequestModel requestModelUpdated,
    required BuildContext context}) async {
  showProgressForCreditRetrieval(context);

  //Send Receipt Email to Lender & Borrowr
  await MailBorrowRequestReceipts.sendBorrowRequestReceipts(
      requestModelUpdated);
  log('Came to send receipts to lender and borrower api');

  //Send Notification To Lender to let them know it's acknowledged
  await sendNotificationLenderReceipt(
      communityId: requestModelUpdated.communityId!,
      timebankId: requestModelUpdated.timebankId!,
      sevaUserId: SevaCore.of(context).loggedInUser.sevaUserID!,
      userEmail: SevaCore.of(context).loggedInUser.email!,
      requestModel: requestModelUpdated,
      context: context);

  //NOTIFICATION_TO_ BORROWER _COMPLETION_FEEDBACK
  await sendNotificationBorrowerRequestCompletedFeedback(
      communityId: requestModelUpdated.communityId!,
      timebankId: requestModelUpdated.timebankId!,
      sevaUserId: requestModelUpdated.sevaUserId!,
      userEmail: requestModelUpdated.email!,
      requestModel: requestModelUpdated,
      context: context);

  if (notification != null && notification.id!.isNotEmpty) {
    NotificationsRepository.readUserNotification(
        notification.id!, SevaCore.of(context).loggedInUser.email!);
  } else if (notificationId != null && notificationId.isNotEmpty) {
    NotificationsRepository.readUserNotification(
        notificationId, SevaCore.of(context).loggedInUser.email!);
  }

  FirestoreManager.requestComplete(model: requestModelUpdated);

  Navigator.of(creditRequestDialogContextNew!).pop();
}

Future<void> sendNotificationLenderReceipt(
    {required String communityId,
    required String sevaUserId,
    required String timebankId,
    required String userEmail,
    required RequestModel requestModel,
    required BuildContext context}) async {
  log('entered TO DB--------------------->>');

  bool isOutsideCommunity = false;

  List<TimebankModel> timebanks =
      await TimebankRepository.getTimebanksWhichUserIsPartOf(
    sevaUserId,
    communityId,
  );
  log('got time banks--------------------->>');

  TimebankModel finalTimebank = timebanks.firstWhere(
      (element) => element.id == timebankId,
      orElse: () => throw Exception('Timebank not found'));
  isOutsideCommunity = !finalTimebank.members.contains(sevaUserId);
  log('if conditions checked--------------------->>');

  NotificationsModel notification = NotificationsModel(
      isTimebankNotification: isOutsideCommunity ? false : true,
      id: Utils.getUuid(),
      timebankId: FlavorConfig.values.timebankId,
      data: requestModel.toMap(),
      isRead: false,
      type: NotificationType.NOTIFICATION_TO_LENDER_COMPLETION_RECEIPT,
      communityId:
          isOutsideCommunity ? FlavorConfig.values.timebankId : communityId,
      senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
      targetUserId: sevaUserId);
  log('model made--------------------->>');
  log('email $userEmail');

  await CollectionRef.users
      .doc(userEmail)
      .collection("notifications")
      .doc(notification.id)
      .set(notification.toMap());

  log('WRITTEN TO DB--------------------->>');
}

Future<void> sendNotificationBorrowerRequestCompletedFeedback(
    {required String communityId,
    required String sevaUserId,
    required String timebankId,
    required String userEmail,
    required RequestModel requestModel,
    required BuildContext context}) async {
  NotificationsModel notification = NotificationsModel(
      isTimebankNotification:
          requestModel.requestMode == RequestMode.TIMEBANK_REQUEST,
      id: Utils.getUuid(),
      timebankId: timebankId,
      data: requestModel.toMap(),
      isRead: false,
      type: NotificationType.NOTIFICATION_TO_BORROWER_COMPLETION_FEEDBACK,
      communityId: communityId,
      senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
      targetUserId: sevaUserId);

  requestModel.requestMode == RequestMode.PERSONAL_REQUEST
      ? await CollectionRef.users
          .doc(userEmail)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap())
      : await CollectionRef.timebank
          .doc(timebankId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());

  log('SEND FEEDBACK NOTIFICATION TO BORROWER--------------------->>');
}

BuildContext? creditRequestDialogContextNew;

void showProgressForCreditRetrieval(BuildContext context) {
  showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        creditRequestDialogContextNew = context;
        return AlertDialog(
          title: Text(S.of(context).please_wait),
          content: LinearProgressIndicator(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        );
      });
}

Future<BorrowAcceptorModel> getBorrowRequestAcceptorModel({
  required String requestId,
  required String acceptorEmail,
}) async {
  var documentsnapshot = await CollectionRef.borrowRequestAcceptors(requestId)
      .doc(acceptorEmail)
      .get();

  return BorrowAcceptorModel.fromMap(
      documentsnapshot.data() as Map<String, dynamic>);
}

Stream<List<BorrowAcceptorModel>> getBorrowRequestAcceptorsModelStream({
  required String requestId,
}) async* {
  var data = await CollectionRef.borrowRequestAcceptors(requestId).snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot, List<BorrowAcceptorModel>>.fromHandlers(
      handleData: (snapshot, requestSink) {
        List<BorrowAcceptorModel> acceptorList = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            BorrowAcceptorModel model = BorrowAcceptorModel.fromMap(
                documentSnapshot.data() as Map<String, dynamic>);
            // model.id = documentSnapshot.id;
            acceptorList.add(model);
          },
        );
        requestSink.add(acceptorList);
      },
    ),
  );
}

Stream<List<TransacationsTimelineModel>> getRequestTimelineDocs(
    {String? transactionTypeId, required String sevaUserID}) async* {
  var query = CollectionRef.timelineGroup
      .where('typeId', isEqualTo: transactionTypeId)
      .where('visible', arrayContains: sevaUserID);
  var data = query.snapshots();

  yield* data.transform(
    StreamTransformer<QuerySnapshot,
        List<TransacationsTimelineModel>>.fromHandlers(
      handleData: (snapshot, timelineSink) {
        List<TransacationsTimelineModel> timelineDocs = [];
        snapshot.docs.forEach(
          (documentSnapshot) {
            logger.e('SNAPSHOT CHECK:  ' + documentSnapshot.toString());
            TransacationsTimelineModel model =
                TransacationsTimelineModel.fromJson(
                    documentSnapshot.data() as Map<String, dynamic>);
            timelineDocs.add(model);
          },
        );
        timelineSink.add(timelineDocs);
      },
    ),
  );
}

Future<void> sendInsufficentNotificationToAdmin(
    {double? creditsNeeded,
    TimebankModel? timebankModel,
    required BuildContext context}) async {
  UserInsufficentCreditsModel userInsufficientModel =
      UserInsufficentCreditsModel(
    senderName: SevaCore.of(context).loggedInUser.fullname,
    senderId: SevaCore.of(context).loggedInUser.sevaUserID,
    senderPhotoUrl: SevaCore.of(context).loggedInUser.photoURL,
    timebankId: timebankModel?.id,
    timebankName: timebankModel?.name,
    creditsNeeded: creditsNeeded,
  );

  NotificationsModel notification = NotificationsModel(
      id: utils.Utils.getUuid(),
      timebankId: timebankModel?.id,
      data: userInsufficientModel.toMap(),
      isRead: false,
      type: NotificationType.TYPE_MEMBER_HAS_INSUFFICENT_CREDITS,
      communityId: timebankModel?.communityId,
      senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
      targetUserId: timebankModel?.creatorId);

  await CollectionRef.timebank
      .doc(timebankModel?.id!)
      .collection("notifications")
      .doc(notification.id)
      .set((notification..isTimebankNotification = true).toMap());

  log('writtent to DB');
}

Future<List<String>> writeToDB(
    {RequestModel? requestModel,
    required BuildContext context,
    TimebankModel? timebankModel,
    OfferModel? offer}) async {
  if (requestModel?.id == null) return [];

  List<String> resultVar = [];
  if (requestModel != null && requestModel.isRecurring == false) {
    await FirestoreManager.createRequest(requestModel: requestModel);
    //create invitation if its from offer only for cash and goods
    try {
      // ignore: deprecated_member_use_from_same_package
      await OfferInvitationManager
          .handleInvitationNotificationForRequestCreatedFromOffer(
        currentCommunity: SevaCore.of(context).loggedInUser.currentCommunity,
        offerModel: offer,
        requestModel: requestModel,
        senderSevaUserID: requestModel.sevaUserId,
        timebankModel: timebankModel,
      );
    } on Exception {
      //Log to crashlytics
    }

    if (requestModel.id != null) {
      resultVar.add(requestModel.id!);
    }
    return resultVar;
  } else if (requestModel != null && requestModel.isRecurring == true) {
    resultVar = await FirestoreManager.createRecurringEvents(
      requestModel: requestModel,
      communityId: SevaCore.of(context).loggedInUser.currentCommunity!,
      timebankId: SevaCore.of(context).loggedInUser.currentTimebank!,
    );
    return resultVar;
  }
  // Ensure a return at the end of the function
  return [];
}

Future updateInvitedSpeakerForRequest(String requestID, String sevaUserId,
    String email, DocumentReference speakerNotificationDocRef) async {
  var batch = CollectionRef.batch;

  batch.update(CollectionRef.requests.doc(requestID), {
    'invitedUsers': FieldValue.arrayUnion([sevaUserId]),
    'speakerInviteNotificationDocRef': speakerNotificationDocRef,
  });

  batch.update(
    CollectionRef.users.doc(email),
    {
      'invitedRequests': FieldValue.arrayUnion([requestID])
    },
  );

  await batch.commit();
}

Future<bool> sendMailToInstructor({
  String? senderEmail,
  String? receiverEmail,
  String? communityName,
  String? requestName,
  String? requestCreatorName,
  String? receiverName,
  var startDate,
  var endDate,
}) async {
  return await SevaMailer.createAndSendEmail(
      mailContent: MailContent.createMail(
          mailSender: senderEmail,
          mailReciever: receiverEmail,
          mailSubject: (requestCreatorName ?? 'Unknown') +
              ' from ' +
              (communityName ?? 'Unknown Community') +
              ' has invited you',
          mailContent: getMailContentTemplate(
              requestName: requestName,
              requestCreatorName: requestCreatorName,
              receiverName: receiverName,
              communityName: communityName,
              startDate: startDate)));
}

Future<DocumentReference> sendNotificationToMemberOneToManyRequest(
    {String? communityId,
    String? sevaUserId,
    String? timebankId,
    String? userEmail,
    required RequestFormType formType,
    required BuildContext context,
    DocumentReference? speakerNotificationDocRefOld,
    required RequestModel requestModel}) async {
  //delete the previous speaker's notification document, since new speaker is invited here
  if (formType == RequestFormType.EDIT) {
    try {
      await speakerNotificationDocRefOld?.delete();
    } catch (error) {
      logger.e('did not find notification doc to delete');
    }
  }

  NotificationsModel notification = NotificationsModel(
      id: utils.Utils.getUuid(),
      timebankId: FlavorConfig.values.timebankId,
      data: requestModel.toMap(),
      isRead: false,
      isTimebankNotification: false,
      type: NotificationType.OneToManyRequestAccept,
      communityId: communityId,
      senderUserId: SevaCore.of(context).loggedInUser.sevaUserID,
      //BlocProvider.of<AuthBloc>(context).user.sevaUserID,
      targetUserId: sevaUserId);

  await CollectionRef.users
      .doc(userEmail)
      .collection("notifications")
      .doc(notification.id)
      .set(notification.toMap());

  return CollectionRef.users
      .doc(userEmail)
      .collection("notifications")
      .doc(notification.id);
}

Future<List<CategoryModel>> getCategoriesFromApi(String query) async {
  try {
    var response = await post(
      Uri.parse(
        "https://proxy.sevaexchange.com/" +
            "http://ai.api.sevaxapp.com/request_categories",
      ),
      headers: {
        "Content-Type": "application/json",
        "Access-Control": "Allow-Headers",
        "x-requested-with": "x-requested-by"
      },
      body: jsonEncode({
        "description": query,
      }),
    );
    log('respinse ${response.body}');
    log('respinse ${response.statusCode}');

    if (response.statusCode == 200) {
      Map<String, dynamic> bodyMap = json.decode(response.body);
      List<String> categoriesList = bodyMap.containsKey('string_vec')
          ? List.castFrom(bodyMap['string_vec'])
          : [];
      if (categoriesList != null && categoriesList.length > 0) {
        return getCategoryModels(categoriesList);
      }
    } else {
      throw Exception('Failed to fetch categories from API');
    }
  } catch (exception) {
    log(exception.toString());
    throw Exception('Failed to fetch categories from API: $exception');
  }
  // Ensure a return or throw at the end of the function
  throw Exception('Failed to fetch categories from API: No categories found');
}

Future<List<CategoryModel>> getCategoryModels(
    List<String> categoriesList) async {
  List<CategoryModel> modelList = [];
  for (int i = 0; i < categoriesList.length; i += 1) {
    CategoryModel categoryModel = await FirestoreManager.getCategoryForId(
      categoryID: categoriesList[i],
    );
    modelList.add(categoryModel);
  }
  if (modelList != null && modelList.length > 0) {
    return updateInformation(modelList);
  }
  return null!;
}

List<CategoryModel> updateInformation(List<CategoryModel> category) {
  List<CategoryModel> selectedCategoryModels = [];
  if (category != null && category.length > 0) {
    selectedCategoryModels.addAll(category);
  }
  return selectedCategoryModels;
  // setState(() {});
}

linearProgressForCreatingRequest(context, title) {
  showDialog(
      barrierDismissible: false,
      context: context,
      useRootNavigator: true,
      builder: (createDialogContext) {
        dialogContext = createDialogContext;
        return AlertDialog(
          title: Text(title),
          content: LinearProgressIndicator(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        );
      });
}

//if another speaker is invited then we need to remove the previous speaker from the invited list
//re update the invited speaker
Future reUpdateInvitedSpeakerForRequest(
    {String? requestID,
    String? sevaUserIdPrevious,
    String? emailPrevious,
    String? sevaUserIdNew,
    String? emailNew}) async {
  var batch = CollectionRef.batch;

  //remove previous speaker as invited member
  // batch.update(
  //     CollectionRef.requests.doc(requestID), {
  //   'invitedUsers': FieldValue.arrayRemove([sevaUserIdPrevious]),
  // });
  batch.update(
    CollectionRef.users.doc(emailPrevious),
    {
      'invitedRequests': FieldValue.arrayRemove([requestID])
    },
  );

  //Add new speaker as invited member
  // batch.update(
  //     CollectionRef.requests.doc(requestID), {
  //   'invitedUsers': FieldValue.arrayUnion([sevaUserIdNew]),
  // });
  batch.update(
    CollectionRef.users.doc(emailNew),
    {
      'invitedRequests': FieldValue.arrayUnion([requestID])
    },
  );
  await batch.commit();
}
