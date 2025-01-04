import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wosapp/reusable_widgets/reusable_widgets.dart';
import 'package:wosapp/screens/home_screen.dart';
import 'package:wosapp/screens/signup_screen.dart';
import 'package:wosapp/utls/color_utls.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final TextEditingController _emailTextController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
            gradient: LinearGradient(
          colors: [
            hexStringToColor("CB2393"),
            hexStringToColor("9546C4"),
            hexStringToColor("5E61F4")
          ],
        )),
        child: SingleChildScrollView(
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).size.height * 0.2, 20, 0),
                child: Column(
                  children: <Widget>[
                    Text(
                      "WoSApp",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 60.0,
                        fontFamily: "RubikVinyl",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    logoWidget("assets/logo-removebg-preview.png"),
                    SizedBox(
                      height: 60.0,
                    ),
                    reusableTextField("Enter Email", Icons.person_outlined,
                        false, _emailTextController),
                    SizedBox(
                      height: 20.0,
                    ),
                    reusableTextField("Enter Password", Icons.lock_outline,
                        true, _passwordTextController),
                    SizedBox(
                      height: 20.0,
                    ),
                    signInSignUpButton(context, true, () {
                      FirebaseAuth.instance
                          .signInWithEmailAndPassword(
                              email: _emailTextController.text,
                              password: _passwordTextController.text)
                          .then((value) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => HomeScreen()));
                      }).onError((error, stackTrace) {
                        print("Error ${error.toString()}");
                      });
                    }),
                    signUpOption()
                  ],
                ))),
      ),
    );
  }

  Row signUpOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have account?",
            style: TextStyle(color: Colors.white70)),
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => SignUpScreen()));
          },
          child: const Text(
            " Sign Up",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}
