import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  await Firebase.initializeApp();
  runApp(Gps());
}

class Gps extends StatelessWidget {
  const Gps({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
