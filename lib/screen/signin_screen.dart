import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lesson3part1/controller/firebasecontroller.dart';
import 'package:lesson3part1/model/constant.dart';
import 'package:lesson3part1/model/photomemo.dart';
import 'package:lesson3part1/screen/myview/mydialog.dart';
import 'package:lesson3part1/screen/userhome_screen.dart';

class SignInScreen extends StatefulWidget {
  static const routeName = '/signInScreen';

  @override
  State<StatefulWidget> createState() {
    return _SignInState();
  }
}

class _SignInState extends State<SignInScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  _Controller con;

  @override
  void initState() {
    super.initState();
    con = _Controller(this);
  }

  void render(func) => setState(func);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In Screen'),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: con.validateEmail,
                onSaved: con.saveEmail,
              ),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Password',
                ),
                autocorrect: false,
                obscureText: true,
                validator: con.validatePassword,
                onSaved: con.savePassword,
              ),
              RaisedButton(
                onPressed: con.signIn,
                child: Text(
                  'Sign In',
                  style: Theme.of(context).textTheme.button,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _Controller {
  _SignInState state;
  _Controller(this.state);

  String email;
  String password;

  String validatePassword(String value) {
    if (value.length < 6)
      return 'too short';
    else
      return null;
  }

  void savePassword(String value) {
    password = value;
  }

  String validateEmail(String value) {
    if (value.contains('@') && value.contains('.'))
      return null;
    else
      return 'invalid email address';
  }

  void saveEmail(String value) {
    email = value;
  }

  void signIn() async {
    if (!state.formKey.currentState.validate()) return;

    // now validated
    state.formKey.currentState.save();

    User user;
    MyDialog.circularProggressStart(state.context);
    try {
      user = await FirebaseController.signIn(email: email, password: password);
      print('============ ${user.email}');
    } catch (e) {
      MyDialog.circularProgressStop(
          state.context); // must make sure to stop load symbol in all possible paths
      MyDialog.info(
        context: state.context,
        title: 'Sign In Error',
        content: e.toString(),
      );
      return; // sign in failed
    }

    // sign in success
    try {
      List<PhotoMemo> photoMemoList =
          await FirebaseController.getPhotoMemoList(email: user.email);
      MyDialog.circularProgressStop(state.context);
      Navigator.pushNamed(
        state.context,
        UserHomeScreen.routeName,
        arguments: {
          Constant.ARG_USER: user,
          Constant.ARG_PHOTOMEMOLIST: photoMemoList,
        },
      );
    } catch (e) {
      MyDialog.circularProgressStop(state.context);
      MyDialog.info(
          context: state.context,
          title: 'Firestore getPhotoMemoList error',
          content: '$e');
    }
  }
}
