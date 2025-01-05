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

  List<Contact> closeContacts = []; // Store the added "Close Contacts"
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

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
    try {
      // Store the contact in the Firestore "close_contacts" collection
      await _firestore.collection('close_contacts').add({
        'name': name,
        'phone': phone,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name has been added to Firebase.'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add contact to Firebase.'),
      ));
    }
  }

  // Add new contact to the "Close Contacts" list
  void addCloseContact() {
    String name = nameController.text;
    String phone = phoneController.text;

    if (name.isNotEmpty && phone.isNotEmpty) {
      Contact newContact = Contact()
        ..givenName = name
        ..phones = [Item(label: 'mobile', value: phone)];

      setState(() {
        closeContacts
            .add(newContact); // Add the contact to the close contacts list
      });

      // Save the contact to Firestore
      saveContactToFirebase(name, phone);

      nameController.clear();
      phoneController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please provide both name and phone number.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LIVE TRACKING'),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Add Contact Section
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Enter Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Enter Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: addCloseContact,
                child: Text('Add Contact'),
              ),

              SizedBox(height: 30),

              // Display "Close Contacts"
              Container(
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Close Contacts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    closeContacts.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: closeContacts.length,
                            itemBuilder: (context, index) {
                              Contact contact = closeContacts[index];
                              String name = contact.givenName ?? 'No Name';
                              String phone = contact.phones?.isNotEmpty == true
                                  ? contact.phones!.first.value ?? 'No Number'
                                  : 'No Number';

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(name[0].toUpperCase()),
                                ),
                                title: Text(name),
                                subtitle: Text(phone),
                              );
                            },
                          )
                        : Center(
                            child: Text('No close contacts added yet'),
                          ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // Display Phone Contacts
              phoneContacts.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      shrinkWrap: true,
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
                          title: Text(name),
                          subtitle: Text(phone),
                          trailing: IconButton(
                            icon: Icon(Icons.save, color: Colors.blue),
                            onPressed: () {
                              saveContactToFirebase(name, phone);
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
