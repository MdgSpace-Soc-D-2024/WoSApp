import 'package:flutter/material.dart';

//import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'dart:convert';
//import 'package:http/http.dart' as http;

Future<List<String>> fetchPhoneNumbers() async {
  // Reference to the 'close_contacts' collection in Firestore
  CollectionReference ref =
      FirebaseFirestore.instance.collection('close_contacts');

  try {
    // Fetch the documents in the 'close_contacts' collection
    QuerySnapshot snapshot = await ref.get();

    if (snapshot.docs.isNotEmpty) {
      List<String> phoneNumbers = [];

      // Loop through the documents and fetch phone numbers
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Ensure the 'phone' field exists before adding to the list
        if (data['phone'] != null) {
          phoneNumbers.add(data['phone']);
        }
      }

      return phoneNumbers;
    } else {
      throw Exception('No contacts found.');
    }
  } catch (e) {
    throw Exception('Error fetching phone numbers: $e');
  }
}

Image logoWidget(String imagename) {
  return Image.asset(
    imagename,
    fit: BoxFit.fitWidth,
    width: 200,
    height: 200,
    color: Colors.white,
  );
}

TextField reusableTextField(String text, IconData icon, bool ispasswordtype,
    TextEditingController controller) {
  return TextField(
    controller: controller,
    obscureText: ispasswordtype,
    enableSuggestions: !ispasswordtype,
    autocorrect: !ispasswordtype,
    cursorColor: Colors.white,
    style: TextStyle(color: Colors.white.withAlpha(240)),
    decoration: InputDecoration(
      prefixIcon: Icon(
        icon,
        color: Colors.white,
      ),
      labelText: text,
      labelStyle: TextStyle(color: Colors.white.withAlpha(240)),
      filled: true,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      fillColor: Colors.white.withAlpha(128),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: const BorderSide(width: 0, style: BorderStyle.none)),
    ),
    keyboardType: ispasswordtype
        ? TextInputType.visiblePassword
        : TextInputType.emailAddress,
  );
}

Container signInSignUpButton(
    BuildContext context, bool islogin, Function onTap) {
  return Container(
    width: MediaQuery.of(context).size.width,
    height: 50,
    margin: const EdgeInsets.fromLTRB(0, 10, 0, 20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(90)),
    child: ElevatedButton(
      onPressed: () {
        onTap();
      },
      style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black26;
            }
            return Colors.white;
          }),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)))),
      child: Text(
        islogin ? "LOG IN" : "SIGN UP",
        style: const TextStyle(
            color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}

Container gps(BuildContext context, String write, Function onTap) {
  return Container(
    width: MediaQuery.of(context).size.width,
    height: 50,
    margin: const EdgeInsets.fromLTRB(0, 10, 0, 20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(90)),
    child: ElevatedButton(
      onPressed: () {
        onTap();
      },
      style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black26;
            }
            return Colors.white;
          }),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)))),
      child: Text(
        write,
        style: const TextStyle(
            color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}
