import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(LiveTrackingScreen());
}

class LiveTrackingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Contact> phoneContacts = []; // Store device contacts
  List<Contact> filteredContacts = []; // Store filtered contacts for search
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  // Request permissions to access contacts
  Future<void> requestPermissions() async {
    if (await Permission.contacts.request().isGranted) {
      fetchContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Permission to access contacts denied.'),
      ));
    }
  }

  // Fetch contacts from the phone
  Future<void> fetchContacts() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    setState(() {
      phoneContacts = contacts.toList();
      filteredContacts = phoneContacts; // Initialize filtered list
    });
  }

  // Filter contacts based on search query
  void filterContacts(String query) {
    List<Contact> results = [];
    if (query.isNotEmpty) {
      results = phoneContacts
          .where((contact) =>
              contact.displayName != null &&
              contact.displayName!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } else {
      results = phoneContacts;
    }

    setState(() {
      searchQuery = query;
      filteredContacts = results;
    });
  }

  // Save selected contact to Firebase
  Future<void> saveContactToFirebase(String name, String phone) async {
    await _firestore.collection('contacts').add({'name': name, 'phone': phone});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name has been added to Firebase.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phone Contacts'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: filterContacts,
            ),
          ),
        ),
      ),
      body: phoneContacts.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                Contact contact = filteredContacts[index];
                String name = contact.displayName ?? 'No Name';
                String phone = contact.phones?.isNotEmpty == true
                    ? contact.phones!.first.value ?? 'No Number'
                    : 'No Number';

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(name[0].toUpperCase()),
                  ),
                  title: Text(name, style: TextStyle(fontSize: 18)),
                  subtitle: Text(phone, style: TextStyle(fontSize: 16)),
                  trailing: IconButton(
                    icon: Icon(Icons.save, color: Colors.blue),
                    onPressed: () {
                      saveContactToFirebase(name, phone);
                    },
                  ),
                );
              },
            ),
    );
  }
}
