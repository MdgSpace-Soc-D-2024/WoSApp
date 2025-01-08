import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wosapp/reusable_widgets/reusable_widgets.dart';
import 'package:wosapp/screens/gps_screen.dart';
import 'package:wosapp/screens/livetracking_screen.dart';
import 'package:wosapp/screens/signin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'WoSApp',
          style: TextStyle(
            color: Colors.green,
            fontFamily: "SeymourOne",
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'Profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                  break;
                case 'Logout':
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Logout"),
                        content: Text("Are you sure you want to logout?"),
                        actions: [
                          TextButton(
                            child: Text("Cancel"),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          TextButton(
                            child: Text("Logout"),
                            onPressed: () {
                              // Perform logout action
                              FirebaseAuth.instance.signOut().then((value) {
                                print("Signed Out");
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Signin()));
                              });
                            },
                          ),
                        ],
                      );
                    },
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Profile', 'Logout'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Container(
        child: Column(children: <Widget>[
          SizedBox(
            height: 40.0,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 100.0,
              width: 100.0,
              child: FloatingActionButton.large(
                onPressed: () {},
                backgroundColor: const Color.fromARGB(255, 150, 14, 4),
                child: Text("SOS",
                    style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ),
          SizedBox(
            height: 40.0,
          ),
          gps(context, "GPS", () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => GpsScreen()));
          }),
          SizedBox(
            height: 20.0,
          ),
          gps(context, "Live Tracking", () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => LiveTrackingScreen()));
          })
        ]),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Profile')),
      ),
      body: Container(
        child: Text('This is the Profile Page'),
      ),
    );
  }
}
