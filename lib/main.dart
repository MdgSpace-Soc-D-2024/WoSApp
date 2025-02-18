import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wosapp/screens/signin_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
