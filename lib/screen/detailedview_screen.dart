import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lesson3part1/controller/firebasecontroller.dart';
import 'package:lesson3part1/model/photomemo.dart';
import 'package:lesson3part1/model/constant.dart';

import 'myview/mydialog.dart';
import 'myview/myimage.dart';

class DetailedViewScreen extends StatefulWidget {
  static const routeName = '/detailedViewScreen';

  @override
  State<StatefulWidget> createState() {
    return _DetailedViewState();
  }
}

class _DetailedViewState extends State<DetailedViewScreen> {
  _Controller con;
  User user;
  PhotoMemo onePhotoMemoOriginal;
  PhotoMemo onePhotoMemoTemp;
  bool editMode = false;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String progressMessage;

  @override
  void initState() {
    super.initState();
    con = _Controller(this);
  }

  void render(func) => setState(func);

  @override
  Widget build(BuildContext context) {
    Map args = ModalRoute.of(context).settings.arguments;
    user ??= args[Constant.ARG_USER];
    onePhotoMemoOriginal ??= args[Constant.ARG_ONE_PHOTOMEMO];
    onePhotoMemoTemp ??= PhotoMemo.clone(onePhotoMemoOriginal);

    return Scaffold(
      appBar: AppBar(
        actions: [
          editMode
              ? IconButton(icon: Icon(Icons.check), onPressed: con.update)
              : IconButton(icon: Icon(Icons.edit), onPressed: con.edit),
        ],
        title: Text('Detailed View'),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: con.photoFile == null
                        ? MyImage.network(
                            context: context,
                            url: onePhotoMemoTemp.photoURL,
                          )
                        : Image.file(
                            con.photoFile,
                            fit: BoxFit.fill,
                          ),
                  ),
                  editMode
                      ? Positioned(
                          right: 0.0,
                          bottom: 0.0,
                          child: Container(
                            color: Colors.lightBlue[200],
                            child: PopupMenuButton<String>(
                              onSelected: con.getPhoto,
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: Constant.SRC_CAMERA,
                                  child: Row(
                                    children: [
                                      Icon(Icons.photo_camera),
                                      Text(Constant.SRC_CAMERA),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: Constant.SRC_GALLERY,
                                  child: Row(
                                    children: [
                                      Icon(Icons.photo_library),
                                      Text(Constant.SRC_GALLERY),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 1.0,
                        ),
                ],
              ),
              progressMessage == null
                  ? SizedBox(
                      height: 1.0,
                    )
                  : Text(
                      progressMessage,
                      style: Theme.of(context).textTheme.headline6,
                    ),
              TextFormField(
                enabled: editMode,
                style: Theme.of(context).textTheme.headline6,
                decoration: InputDecoration(
                  hintText: 'Enter Title',
                ),
                initialValue: onePhotoMemoTemp.title,
                autocorrect: true,
                validator: PhotoMemo.validateTitle,
                onSaved: con.saveTitle,
              ),
              TextFormField(
                enabled: editMode,
                decoration: InputDecoration(
                  hintText: 'Enter Memo',
                ),
                initialValue: onePhotoMemoTemp.memo,
                autocorrect: true,
                keyboardType: TextInputType.multiline,
                maxLines: 6,
                validator: PhotoMemo.validateMemo,
                onSaved: con.saveMemo,
              ),
              TextFormField(
                enabled: editMode,
                decoration: InputDecoration(
                  hintText: 'Enter Shared With',
                ),
                initialValue: onePhotoMemoTemp.sharedWith.join(','),
                autocorrect: false,
                keyboardType: TextInputType.multiline,
                maxLines: 2,
                validator: PhotoMemo.validateSharedWith,
                onSaved: con.saveSharedWith,
              ),
              SizedBox(
                height: 5.0,
              ),
              Constant.DEV
                  ? Text('Image Labels generated by ML',
                      style: Theme.of(context).textTheme.bodyText1)
                  : SizedBox(height: 1.0),
              Constant.DEV
                  ? Text(onePhotoMemoTemp.imageLabels.join(' | '))
                  : SizedBox(height: 1.0),
            ],
          ),
        ),
      ),
      // Text(onePhotoMemo.imageLabels.join(' | ')),
    );
  }
}

class _Controller {
  _DetailedViewState state;
  _Controller(this.state);
  File photoFile; // camera or gallery

  void update() async {
    if (!state.formKey.currentState.validate()) return;

    state.formKey.currentState.save();

    try {
      MyDialog.circularProggressStart(state.context);
      Map<String, dynamic> updateInfo = {};

      if (photoFile != null) {
        Map photoInfo = await FirebaseController.uploadPhotoFile(
          profilePic: false,
          photo: photoFile,
          uid: state.user.uid,
          fileName: state.onePhotoMemoTemp.photoFilename,
          listener: (double message) {
            state.render(
              () {
                if (message == null)
                  state.progressMessage = null;
                else {
                  message *= 100;
                  state.progressMessage =
                      'Uploading ' + message.toStringAsFixed(1) + '%';
                }
              },
            );
          },
        );

        state.onePhotoMemoTemp.photoURL = photoInfo[Constant.ARG_DOWNLOADURL];
        state.render(() => state.progressMessage = 'ML image labeler started');
        List<dynamic> labels =
            await FirebaseController.getImageLabels(photoFile: photoFile);
        state.onePhotoMemoTemp.imageLabels = labels;

        updateInfo[PhotoMemo.PHOTO_URL] = photoInfo[Constant.ARG_DOWNLOADURL];
        updateInfo[PhotoMemo.IMAGE_LABELS] = labels;
      }

      // determine updated fields
      if (state.onePhotoMemoOriginal.title != state.onePhotoMemoTemp.title)
        updateInfo[PhotoMemo.TITLE] = state.onePhotoMemoTemp.title;

      if (state.onePhotoMemoOriginal.memo != state.onePhotoMemoTemp.memo)
        updateInfo[PhotoMemo.MEMO] = state.onePhotoMemoTemp.memo;

      if (!listEquals(state.onePhotoMemoOriginal.sharedWith,
          state.onePhotoMemoTemp.sharedWith))
        updateInfo[PhotoMemo.SHARED_WITH] = state.onePhotoMemoTemp.sharedWith;

      updateInfo[PhotoMemo.TIMESTAMP] = DateTime.now();

      await FirebaseController.updatePhotoMemo(
          state.onePhotoMemoTemp.docID, updateInfo);

      state.onePhotoMemoOriginal.assign(state.onePhotoMemoTemp);

      // end loading circle
      MyDialog.circularProgressStop(state.context);

      // return to home page
      Navigator.pop(state.context);
    } catch (e) {
      MyDialog.circularProgressStop(state.context);
      MyDialog.info(
          context: state.context,
          title: 'Update PhotoMemo Error',
          content: '$e');
    }
  }

  void edit() {
    state.render(() => state.editMode = true);
  }

  void getPhoto(String src) async {
    try {
      PickedFile _photoFile;
      if (src == Constant.SRC_CAMERA) {
        _photoFile = await ImagePicker().getImage(source: ImageSource.camera);
      } else {
        _photoFile = await ImagePicker().getImage(source: ImageSource.gallery);
      }

      if (_photoFile == null) return; // selection canceled

      state.render(() => photoFile = File(_photoFile.path));
    } catch (e) {
      MyDialog.info(
          context: state.context, title: 'getPhoto error', content: '$e');
    }
  }

  void saveTitle(String value) {
    state.onePhotoMemoTemp.title = value;
  }

  void saveMemo(String value) {
    state.onePhotoMemoTemp.memo = value;
  }

  void saveSharedWith(String value) {
    if (value.trim().length != 0) {
      state.onePhotoMemoTemp.sharedWith =
          value.split(RegExp('(,| )+')).map((e) => e.trim()).toList();
    }
  }
}
