import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wosapp/screens/signin_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// void sendSmsToContacts(double latitude, double longitude) async {
//   String link = 'https://www.google.com/maps?q=$latitude,$longitude';
//   var url = Uri.parse('http://your-server-ip/send-sms');
//   await http.post(url, body: {
//     'latitude': latitude.toString(),
//     'longitude': longitude.toString(),
//     'contacts': ['+1234567890', '+0987654321'],
//   });
// }
Future<void> requestLocationPermission() async {
  LocationPermission permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) {
    // Handle permission denial
  }
}

void main() async {
  await dotenv.load(fileName: "Twilio.env");
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBad89bzJSNUhB5ynMUds8BokejP2QiGM4",
            authDomain: "wosapp-a2214.firebaseapp.com",
            projectId: "wosapp-a2214",
            storageBucket: "wosapp-a2214.firebasestorage.app",
            messagingSenderId: "1073439472535",
            appId: "1:1073439472535:web:061e579e9018edab71e2d2",
            measurementId: "G-QB04FM108G"));
  } else {
    Firebase.initializeApp();
  }

  runApp(MaterialApp(
    home: wosapp(),
  ));
}
/*

class WoSApp extends StatelessWidget {
  const WoSApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 193, 90, 124),
      appBar: AppBar(
        title: Text("WoSApp"),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(
          image: NetworkImage(
              "data:image/jpeg;base64,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"),
          fit: BoxFit.contain,
        )),
      ),
      /*Text(
            "Hey Ninjas!!!",
            style: TextStyle(
              fontSize: 28.0,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
              fontFamily: "RubikVinyl",
            ),*/

      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.greenAccent[400],
        child: Text("Click"),
      ),
    );
  }
}
*/

// ignore: camel_case_types
class wosapp extends StatelessWidget {
  const wosapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const Signin(),
    );
  }
}

Future<void> sendSms(String phoneNumber, String message) async {
  String accountSid = dotenv.env['twilio_accountSid'] ?? '';
  String authToken = dotenv.env['twilio_authToken'] ?? '';
  String fromPhoneNumber = dotenv.env['twilio_fromPhoneNumber'] ?? '';

  final Uri url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

  final response = await http.post(
    url,
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
    },
    body: {
      'From': fromPhoneNumber,
      'To': phoneNumber,
      'Body': message,
    },
  );

  if (response.statusCode == 201 || response.statusCode == 200) {
    print('SMS sent successfully!');
  } else {
    throw Exception('Failed to send SMS: ${response.body}');
  }
}

/*
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
*/
