import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sevaexchange/models/request_model.dart';
import 'package:sevaexchange/repositories/firestore_keys.dart';

class RequestRepository {
  static CollectionReference ref = CollectionRef.requests;

  static Stream<List<RequestModel>> getAllRequestOfTimebank(
      String timebankId, String userId) async* {
    var data = ref
        .where('timebanksPosted', arrayContains: timebankId)
        .where('softDelete', isEqualTo: false)
        .where('autoGenerated', isEqualTo: false)
        // .where('accepted', isEqualTo: false)
        .orderBy("posttimestamp", descending: true)
        .snapshots();

    yield* data.transform(
      StreamTransformer<QuerySnapshot, List<RequestModel>>.fromHandlers(
        handleData: (snapshot, sink) {
          List<RequestModel> models = [];
          snapshot.docs.forEach(
            (documentSnapshot) {
              // =========================================++=======
              RequestModel model = RequestModel.fromMap(
                  documentSnapshot.data() as Map<String, dynamic>);
              model.id = documentSnapshot.id;

              if (model.accepted != null && model.accepted == true) {
                if (model.sevaUserId == userId) {
                  models.add(model);
                }
              } else {
                if (model.isFromOfferRequest != null &&
                    model.isFromOfferRequest == false) {
                  models.add(model);
                }
              }
            },
          );
          sink.add(models);
        },
      ),
    );
  }

  static Future<RequestModel> getRequestFutureById(
    String requestId,
  ) async {
    DocumentSnapshot document = await ref.doc(requestId).get();
    return RequestModel.fromMap(document.data() as Map<String, dynamic>);
  }

  static Future<List<RequestModel>> getAllRequestsOfCommunity(
      String communityId,
      {int limit = 10}) async {
    var result = await ref
        .where("communityId", isEqualTo: communityId)
        .limit(limit)
        .get();

    List<RequestModel> models = [];
    result.docs.forEach((element) {
      models.add(RequestModel.fromMap(element.data() as Map<String, dynamic>));
    });
    return models;
  }
}
