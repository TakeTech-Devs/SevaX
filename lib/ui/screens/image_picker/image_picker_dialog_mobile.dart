import 'dart:developer';
import 'package:universal_io/io.dart' as io;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as pathExt;
import 'package:sevaexchange/components/sevaavatar/image_picker_handler.dart';
import 'package:sevaexchange/flavor_config.dart';
import 'package:sevaexchange/l10n/l10n.dart';
import 'package:sevaexchange/new_baseline/models/profanity_image_model.dart';
import 'package:sevaexchange/utils/data_managers/user_data_manager.dart';
import 'package:sevaexchange/utils/soft_delete_manager.dart';
import 'package:sevaexchange/utils/utils.dart';
import 'package:sevaexchange/views/image_url_view.dart';
import 'package:sevaexchange/widgets/custom_buttons.dart';

class ImagePickerDialogMobile extends StatefulWidget {
  final ImagePickerType imagePickerType;
  final Function(String imageUrl) onLinkCreated;
  final Function(io.File imageFile) storeImageFile;
  final Function(io.File pdfFile) storPdfFile;
  final Color color;

  ImagePickerDialogMobile({
    required this.imagePickerType,
    required this.onLinkCreated,
    required this.storeImageFile,
    required this.storPdfFile,
    required this.color,
  });

  @override
  _ImagePickerDialogMobileState createState() =>
      _ImagePickerDialogMobileState();
}

class _ImagePickerDialogMobileState extends State<ImagePickerDialogMobile> {
  late io.File imagefile;
  late BuildContext parentContext;
  @override
  Widget build(BuildContext context) {
    parentContext = context;
    return Dialog(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
            maxHeight: 311, minHeight: 180, maxWidth: 450, minWidth: 400),
        child: Column(
          children: [
            AppBar(
              centerTitle: false,
              backgroundColor: Colors.white,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back),
              ),
              title: Text(
                S.of(context).add_image,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
            SizedBox(
              height: 5,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: getImagePickerType(),
            ),
          ],
        ),
      ),
    );
  }

  Widget getImagePickerType() {
    switch (widget.imagePickerType) {
      case ImagePickerType.FEED:
        return feedType();
        break;
      case ImagePickerType.REGISTER:
        return registerType();
        break;
      case ImagePickerType.LENDING_OFFER:
        return lendingOfferType();
        break;
      case ImagePickerType.MESSAGE:
      case ImagePickerType.PROJECT:
      case ImagePickerType.TIMEBANK:
      case ImagePickerType.USER:
      case ImagePickerType.REQUEST:
      case ImagePickerType.SPONSOR:
        return defaultType();
        break;

      default:
        return defaultType();
    }
  }

  Widget feedType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        cameraImageWidget(),
        SizedBox(
          height: 10,
        ),
        galleryImageWidget(),
        SizedBox(
          height: 10,
        ),
        webImageUrlWidget(),
        SizedBox(
          height: 10,
        ),
        pdfWidget(),
      ],
    );
  }

  Widget lendingOfferType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        cameraImageWidget(),
        SizedBox(
          height: 50,
        ),
        galleryImageWidget(),
        SizedBox(
          height: 10,
        ),
      ],
    );
  }

  Widget registerType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        cameraImageWidget(),
        SizedBox(
          height: 10,
        ),
        galleryImageWidget(),
        SizedBox(
          height: 10,
        ),
        // stockImageWidget(),
        // SizedBox(
        //   height: 10,
        // ),
        webImageUrlWidget(),
        // SizedBox(
        //   height: 15,
        // ),
        // pdfWidget(),
      ],
    );
  }

  Widget defaultType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        cameraImageWidget(),
        SizedBox(
          height: 10,
        ),
        galleryImageWidget(),
        SizedBox(
          height: 10,
        ),
        stockImageWidget(),
        SizedBox(
          height: 10,
        ),
        webImageUrlWidget(),
      ],
    );
  }

  Widget stockImageWidget() {
    return imagePickerOption(
        title: S.of(context).stock_images,
        icon: Icons.photo_library,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (mcontext) => SearchStockImages(
                themeColor: Theme.of(context).primaryColor,
                onChanged: (stockImage) {
                  // progress
                  widget.onLinkCreated(stockImage);
                  Navigator.of(mcontext).pop();
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        });
  }

  Widget webImageUrlWidget() {
    return imagePickerOption(
        title: S.of(context).add_image_url,
        icon: Icons.link,
        onTap: () {
          showDialog(
              context: context,
              builder: (BuildContext dialogContext) {
                return ImageUrlView(
                  themeColor: Theme.of(context).primaryColor,
                  onLinkCreated: (String link) {
                    widget.onLinkCreated(link);
                    Navigator.of(context).pop();
                  },
                  isCover: false,
                );
              });
        });
  }

  Widget cameraImageWidget() {
    return imagePickerOption(
        title: S.of(context).camera,
        icon: Icons.add_circle_outline,
        onTap: () async {
          final picker = ImagePicker();
          final XFile? pickedFile =
              await picker.pickImage(source: ImageSource.camera);
          if (pickedFile == null) return;
          String _extension =
              pathExt.extension(pickedFile.path).split('?').first;

          if (_extension == 'gif' || _extension == '.gif') {
            showProgressDialog(parentContext);
            uploadImage(io.File(pickedFile.path));
          } else {
            cropImage(pickedFile.path);
          }
        });
  }

  Widget galleryImageWidget() {
    return imagePickerOption(
      title: S.of(context).gallery,
      icon: Icons.add_circle_outline,
      onTap: () async {
        final picker = ImagePicker();
        final XFile? pickedFile =
            await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return;
        String _extension = pathExt.extension(pickedFile.path).split('?').first;

        if (_extension == 'gif' || _extension == '.gif') {
          showProgressDialog(parentContext);
          uploadImage(io.File(pickedFile.path));
        } else {
          cropImage(pickedFile.path);
        }
      },
    );
  }

  Widget pdfWidget() {
    return imagePickerOption(
        title: S.of(context).choose_pdf_file,
        icon: Icons.picture_as_pdf,
        onTap: () async {
          try {
            String? _path = '';
            FilePickerResult? result = await FilePicker.platform
                .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
            if (result != null) {
              _path = result.files.single.path;
            }
            if (_path != null && _path.isNotEmpty) {
              widget.storPdfFile(io.File(_path));
            }
          } on PlatformException catch (e) {
            throw e;
          }

          // getPdfFileWeb().then(
          //       (File file) {
          //     if (file != null) {
          //       widget.storPdfFile(file);
          //       Navigator.of(context).pop();
          //     }
          //   },
          // );
        });
  }

  Widget imagePickerOption({String? title, IconData? icon, Function? onTap}) {
    final String safeTitle = title ?? '';
    return Container(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(10),
      ),
      height: 50,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap as GestureTapCallback?,
        leading: safeTitle.contains('Add Image')
            ? Image.asset('images/icons/link.png',
                height: 16, color: Colors.white)
            : safeTitle.contains('Stock')
                ? Image.asset('images/icons/multi_image.png',
                    height: 16, color: Colors.white)
                : Icon(icon, color: Colors.white),
        title: Text(
          safeTitle,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  late BuildContext dialogContext;

  void showProgressDialog(BuildContext context) {
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
  }

  Future<String> uploadImage(io.File file) async {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    String timestampString = timestamp.toString();
    String imageURL = '';
    String folderName = '';
    // ImageUploadToFirestore imageData;
    if (widget.imagePickerType == ImagePickerType.FEED) {
      folderName = 'newsimages/';
    } else if (widget.imagePickerType == ImagePickerType.PROJECT) {
      folderName = 'projects_avtaar/';
    } else if (widget.imagePickerType == ImagePickerType.TIMEBANK) {
      folderName = 'timebanklogos/';
    } else if (widget.imagePickerType == ImagePickerType.MESSAGE) {
      folderName = 'multiUserMessagingLogo/';
    } else if (widget.imagePickerType == ImagePickerType.REQUEST) {
      folderName = 'request_images/';
    } else if (widget.imagePickerType == ImagePickerType.SPONSOR) {
      folderName = 'sponsorsLogos/';
    } else if (widget.imagePickerType == ImagePickerType.LENDING_OFFER) {
      folderName = 'lendingImages/';
    } else {
      folderName = 'profile_images/';
    }

    Reference ref = FirebaseStorage.instance
        .ref()
        .child(folderName)
        .child(timestampString + '.jpg');
    UploadTask uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentLanguage: 'en',
        customMetadata: <String, String>{'activity': folderName},
      ),
    );
    // UploadTask uploadTask = ref.putFile(File.)

    try {
      await uploadTask;
      imageURL = await ref.getDownloadURL();
      await profanityCheck(
        imageURL: imageURL,
        storagePath: imageURL,
      );
    } catch (e) {
      log('Image upload failed: $e');
      imageURL = '';
    }
    // imageData =
    // await uploadImageWeb(file, folderName + timestampString + '.jpg');
    // imageURL = imageData.imageUrl;

    return imageURL;
  }

  Future cropImage(String path) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: CropAspectRatio(
        ratioX: 1.0,
        ratioY: 1.0,
      ),
      maxWidth: 200,
      maxHeight: 200,
    );
    if (croppedFile == null) return;
    showProgressDialog(parentContext);

    uploadImage(io.File(croppedFile.path));
  }

  Future<void> profanityCheck(
      {required String? imageURL, required String storagePath}) async {
    ProfanityImageModel profanityImageModel = ProfanityImageModel();
    ProfanityStatusModel profanityStatusModel = ProfanityStatusModel();
    // _newsImageURL = imageURL;
    profanityImageModel = await checkProfanityForImage(
      imageUrl: imageURL ?? '',
      storagePath: storagePath,
    );

    // Remove null check for profanityImageModel, as it can't be null
    // Instead, check if imageURL is null or empty
    if (imageURL == null || imageURL.isEmpty) {
      Navigator.of(dialogContext).pop();
      showFailedLoadImage(context: context).then((value) {
        deleteFireBaseImage(imageUrl: imageURL ?? '').then((value) {
          if (value) {
            // Assign a dummy File or handle accordingly
            // imagefile = null; // Not allowed, so skip or re-initialize
          }
          Navigator.of(context).pop();
        });
      });
      return;
    }

    profanityStatusModel =
        await getProfanityStatus(profanityImageModel: profanityImageModel);

    if (profanityStatusModel.isProfane == true) {
      Navigator.of(dialogContext).pop();
      showProfanityImageAlert(
              context: context, content: profanityStatusModel.category ?? '')
          .then((status) {
        if (status == 'Proceed') {
          deleteFireBaseImage(imageUrl: imageURL).then((value) {
            if (value) {
              // Assign a dummy File or handle accordingly
              // imagefile = null; // Not allowed, so skip or re-initialize
            }
          }).catchError((e) {
            log(e.toString());
            return null;
          });
        }
      });
    } else {
      widget.onLinkCreated(imageURL);
      Navigator.of(dialogContext).pop();
      Navigator.of(parentContext).pop();
      // Navigator.of(context).pop();
    }
  }
}

enum ImagePickerType {
  FEED,
  USER,
  PROJECT,
  MESSAGE,
  TIMEBANK,
  REGISTER,
  REQUEST,
  LENDING_OFFER,
  SPONSOR
}
