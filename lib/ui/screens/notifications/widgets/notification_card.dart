import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:sevaexchange/l10n/l10n.dart';
import 'package:sevaexchange/ui/utils/avatar.dart';
import 'package:sevaexchange/widgets/custom_buttons.dart';
import 'package:timeago/timeago.dart' as timeAgo;

class NotificationCard extends StatelessWidget {
  final VoidCallback? onPressed;
  final Function? onDismissed;
  final String? photoUrl;
  final String title;
  final String subTitle;
  final bool isDissmissible;
  final String? entityName;
  final int timestamp;

  NotificationCard({
    Key? key,
    required this.title,
    required this.subTitle,
    required this.timestamp,
    this.onPressed,
    this.photoUrl,
    this.onDismissed,
    this.entityName,
    this.isDissmissible = true,
  }) : super(key: key);

  late DateTime clickTime;

  bool isRedundantClick(DateTime currentTime) {
    if (clickTime == null) {
      clickTime = currentTime;
      return false;
    }
    if (currentTime.difference(clickTime).inSeconds < 1) {
      //set this difference time in seconds
      return true;
    }

    clickTime = currentTime;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !isDissmissible && onPressed == null,
      child: Slidable(
        startActionPane: isDissmissible
            ? ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (context) {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: Text(
                              S.of(context).delete_notification,
                            ),
                            content: Text(
                              S.of(context).delete_notification_confirmation,
                            ),
                            actions: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 15,
                                ),
                                child: CustomTextButton(
                                  shape: StadiumBorder(),
                                  color: Colors.grey,
                                  padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                                  onPressed: () =>
                                      {Navigator.of(dialogContext).pop()},
                                  child: Text(
                                    S.of(context).cancel,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Europa',
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 15,
                                  right: 15,
                                ),
                                child: CustomTextButton(
                                  shape: StadiumBorder(),
                                  color: Colors.orange,
                                  padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                                  onPressed: () async {
                                    onDismissed!();
                                    Navigator.of(dialogContext).pop();
                                  },
                                  child: Text(
                                    S.of(context).delete,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Europa',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: S.of(context).delete,
                  ),
                ],
              )
            : null,
        child: Container(
          margin: EdgeInsets.fromLTRB(5, 5, 5, 0),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            color: Colors.white,
            shadows: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                spreadRadius: 2,
                blurRadius: 3,
              )
            ],
          ),
          child: ListTile(
            title: Text(title),
            leading: photoUrl != null
                ? CircleAvatar(
                    radius: 22,
                    backgroundImage: CachedNetworkImageProvider(photoUrl!),
                  )
                : CustomAvatar(
                    radius: 22,
                    name: entityName ?? " ",
                  ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subTitle != null ? subTitle.trim() : '',
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeAgo.format(
                        DateTime.fromMillisecondsSinceEpoch(
                          timestamp,
                        ),
                        locale: S.of(context).localeName == 'sn'
                            ? 'en'
                            : S.of(context).localeName,
                      ),
                    ),
                    Text(
                      "${DateFormat.yMMMMd('en_US').format(DateTime.fromMillisecondsSinceEpoch(
                        timestamp,
                      ))}",
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => onPressed != null
                ? isRedundantClick(DateTime.now())
                    ? null
                    : onPressed!()
                : null,
          ),
        ),
      ),
    );
  }
}
