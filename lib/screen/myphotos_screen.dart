import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lesson3part1/controller/firebasecontroller.dart';
import 'package:lesson3part1/model/constant.dart';
import 'package:lesson3part1/model/photomemo.dart';
import 'package:lesson3part1/model/room.dart';
import 'package:lesson3part1/model/userrecord.dart';
import 'package:lesson3part1/screen/myview/mydetailedview.dart';
import 'package:lesson3part1/screen/myview/myimage.dart';

import 'myview/mydialog.dart';

class MyPhotoScreen extends StatefulWidget {
  static const routeName = '/myPhotosScreen';

  @override
  State<StatefulWidget> createState() {
    return _MyPhotoScreenState();
  }
}

class _MyPhotoScreenState extends State<MyPhotoScreen> {
  _Controller con;
  List<PhotoMemo> photoMemoList;
  UserRecord userRecord;
  List<Room> roomList;

  @override
  void initState() {
    super.initState();
    con = _Controller(this);
  }

  void render(func) => setState(func);

  @override
  Widget build(BuildContext context) {
    Map args = ModalRoute.of(context).settings.arguments;
    photoMemoList ??= args[Constant.ARG_PHOTOMEMOLIST];
    userRecord ??= args[Constant.ARG_USERRECORD];
    roomList ??= args[Constant.ARG_ROOMLIST];

    return Scaffold(
      appBar: AppBar(
        title: Text('My Photos'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          con.deleteMemo != null
              ? IconButton(icon: Icon(Icons.cancel), onPressed: con.cancelDelete)
              : SizedBox(),
          con.deleteMemo != null
              ? IconButton(icon: Icon(Icons.delete), onPressed: con.delete)
              : SizedBox(),
        ],
      ),
      body: con.generateWall(),
    );
  }
}

class _Controller {
  _MyPhotoScreenState state;
  _Controller(this.state);
  PhotoMemo deleteMemo;

  Widget generateWall() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: getRows(),
        ),
      ),
    );
  }

  void onLongPress(PhotoMemo m) {
    state.render(() => deleteMemo = m);
  }

  void cancelDelete() {
    state.render(() => deleteMemo = null);
  }

  void delete() async {
    try {
      var room = state.roomList.where((r) => deleteMemo.roomName == r.roomName);
      room.elementAt(0).memos.removeWhere((memo) => deleteMemo.docID == memo);
      await FirebaseController.updateRoom(
          emails: room.elementAt(0).members, room: room.elementAt(0));
      await FirebaseController.deletePhotoMemo(deleteMemo);
      state.render(
        () {
          state.photoMemoList.remove(deleteMemo);
          deleteMemo = null;
        },
      );
    } catch (e) {
      MyDialog.info(
        context: state.context,
        title: 'delete photomemo error',
        content: '$e',
      );
    }
  }

  List<Widget> getRows() {
    List<Color> colors = [Colors.red, Colors.blue, Colors.green];
    var width = MediaQuery.of(state.context).size.width * .31;
    List<Widget> w = [];
    int counter = 0;
    int size = state.photoMemoList.length; // 3
    Row row;
    List<Widget> widgies = [];

    for (var m in state.photoMemoList) {
      // 3
      widgies.add(
        Stack(
          children: [
            Container(
              width: width,
              height: width,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: MaterialButton(
                  child: MyImage.network(url: m.photoURL, context: state.context),
                  onPressed: () {
                    focusMemoView(m);
                    state.render(() {});
                  },
                  onLongPress: () => onLongPress(m),
                ),
              ),
              color: Colors.transparent,
            ),
          ],
        ),
      );
      size--;
      if (counter != 2) widgies.add(SizedBox(width: 2.0));
      if (counter == 2) {
        row = Row(children: widgies);
        w.add(row);
        w.add(SizedBox(height: 5.0));
        widgies = [];
        counter = -1;
      }
      counter++;
    }
    print(size);
    if (size == 0) {
      row = Row(children: widgies);
      w.add(row);
      w.add(SizedBox());
    }
    return w;
  }

  void focusMemoView(PhotoMemo m) async {
    int commentCount = await FirebaseController.getPhotomemoCommentCount(photoMemo: m);

    var focusWidth = MediaQuery.of(state.context).size.width * 0.8;
    var focusHeight = MediaQuery.of(state.context).size.height * 0.8;
    showDialog(
      context: state.context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            contentPadding: EdgeInsets.all(0.0),
            backgroundColor: Colors.transparent,
            content: SingleChildScrollView(
              child: Column(
                children: [
                  Column(
                    children: [
                      SizedBox(height: 0.0),
                      Stack(
                        children: [
                          Container(
                            height: focusWidth,
                            width: focusWidth,
                            color: Colors.transparent,
                            child: FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: MyImage.network(
                                    url: m.photoURL, context: state.context)),
                          ),
                        ],
                      ),
                      Container(
                        height: focusHeight * 0.48,
                        width: focusWidth,
                        color: Colors.grey[800],
                        child: DetailedView(
                          photoMemo: m,
                          commentCount: commentCount,
                          ownerUsername: state.userRecord.username,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
