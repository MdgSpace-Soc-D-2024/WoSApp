import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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
  bool isTracking = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Contact> phoneContacts = []; // Store device contacts
  List<Contact> filteredContacts = []; // Store filtered contacts for search
  String searchQuery = '';

  List<Map<String, String>> closeContacts =
      []; // Store the added "Close Contacts" from Firebase

  @override
  void initState() {
    super.initState();
    requestPermissions();
    fetchCloseContactsFromFirebase();
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
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        phoneContacts = contacts;
        filteredContacts = phoneContacts; // Initialize filtered list
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load contacts: $e'),
      ));
    }
  }

  // Fetch close contacts from Firestore
  Future<void> fetchCloseContactsFromFirebase() async {
    try {
      QuerySnapshot snapshot =
          await _firestore.collection('close_contacts').get();
      setState(() {
        closeContacts = snapshot.docs
            .map((doc) => {
                  'name': doc['name'] as String,
                  'phone': doc['phone'] as String,
                  'id': doc.id as String, // Ensure type compatibility
                })
            .toList()
            .cast<Map<String, String>>(); // Explicitly cast to the correct type
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to fetch close contacts: $e'),
      ));
    }
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
      results = [];
    }

    setState(() {
      searchQuery = query;
      filteredContacts = results;
    });
  }

  // Save selected contact to Firebase
  Future<void> saveContactToFirebase(String name, String phone) async {
    try {
      // Check if contact already exists
      bool exists = closeContacts.any((contact) => contact['phone'] == phone);
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name is already in the Close Contacts list.'),
        ));
        return;
      }

      DocumentReference docRef =
          await _firestore.collection('close_contacts').add({
        'name': name,
        'phone': phone,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        closeContacts.add({'name': name, 'phone': phone, 'id': docRef.id});
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name has been added to Firebase.'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add contact to Firebase: $e'),
      ));
    }
  }

  // Delete contact from Firebase
  Future<void> deleteContactFromFirebase(String id) async {
    try {
      await _firestore.collection('close_contacts').doc(id).delete();

      setState(() {
        closeContacts.removeWhere((contact) => contact['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Contact deleted successfully.'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete contact: $e'),
      ));
    }
  }

  // Show dialog to add new contact manually
  void showAddContactDialog() {
    String name = '';
    String phone = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Name'),
              onChanged: (value) {
                name = value;
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                phone = "+91$value";
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty && phone.isNotEmpty) {
                saveContactToFirebase(name, phone);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Please fill all fields.'),
                ));
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
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
            child: Column(
              children: [
                TextField(
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
                  onChanged: (query) {
                    setState(() {
                      searchQuery = query;
                    });
                    filterContacts(query);
                  },
                ),
                if (searchQuery.isNotEmpty && filteredContacts.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        Contact contact = filteredContacts[index];
                        String name = contact.displayName ?? 'No Name';
                        String phone = contact.phones.isNotEmpty
                            ? contact.phones.first.number ?? 'No Number'
                            : 'No Number';

                        return ListTile(
                          title: Text(name),
                          subtitle: Text(phone),
                          onTap: () {
                            saveContactToFirebase(name, phone);
                            setState(() {
                              searchQuery = '';
                              filteredContacts = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: showAddContactDialog,
                child: Text('Add New Contact'),
              ),
              SizedBox(height: 30),
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
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    closeContacts.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: closeContacts.length,
                            itemBuilder: (context, index) {
                              String name =
                                  closeContacts[index]['name'] ?? 'No Name';
                              String phone =
                                  closeContacts[index]['phone'] ?? 'No Number';
                              String id = closeContacts[index]['id'] ?? '';

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(name[0].toUpperCase()),
                                ),
                                title: Text(name),
                                subtitle: Text(phone),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      deleteContactFromFirebase(id),
                                ),
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
              ElevatedButton(
                onPressed: isTracking ? null : startLiveTracking,
                child: Text('Start Live Tracking'),
              )
            ],
          ),
        ),
      ),
    );
  }

  bool smsSent = false;
  late IO.Socket socket;
  void startLiveTracking() async {
    setState(() {
      isTracking = true;
    });

    // Initialize the Socket.IO connection
    socket = IO.io(
      'https://live-location-tracking-zo66.onrender.com', // Your Socket.IO server URL
      IO.OptionBuilder()
          .setTransports(['websocket']) // Use WebSocket as the transport method
          .disableAutoConnect() // Disable auto-connect until you explicitly connect
          .build(),
    );

    // Connect to the server
    socket.connect();

    // Listen for location updates and send them to the server
    Geolocator.getPositionStream().listen((Position position) async {
      double latitude = position.latitude;
      double longitude = position.longitude;

      sendLocationToChatroom(latitude, longitude);

      if (!smsSent) {
        bool smsSuccess = await sendSmsToContacts();
        smsSent = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(smsSuccess
                ? 'Live tracking activated. SMS sent to close contacts.'
                : 'Failed to send SMS. Please try again.'),
            duration: Duration(seconds: 3),
            backgroundColor: smsSuccess ? Colors.green : Colors.red,
          ),
        );
      }
    });

    // Listen for messages from the server (for example, other users in the chatroom)
    socket.on('message', (data) {
      print('Received message from server: $data');
    });

    socket.on('disconnect', (_) {
      print('Disconnected from server');
    });

    socket.on('connect_error', (error) {
      print('Connection error: $error');
    });
  }

// Sends real-time location updates to the chatroom using Socket.IO
  void sendLocationToChatroom(double latitude, double longitude) {
    final locationData = {
      'type': 'location',
      'latitude': latitude,
      'longitude': longitude,
    };
    // Log the location data before sending
    print('Sending location data to chatroom: $locationData');

    socket.emit(
        'send location', locationData); // Emit the location to the server
  }

// Sends SMS to contacts with the chatroom URL
  Future<bool> sendSmsToContacts() async {
    String accountSid = dotenv.env['twilio_accountSid'] ?? '';
    String authToken = dotenv.env['twilio_authToken'] ?? '';
    String fromPhoneNumber = dotenv.env['twilio_fromPhoneNumber'] ?? '';

    // Chatroom URL where location updates will be visible
    String chatroomURL = "https://live-location-tracking-zo66.onrender.com";

    var url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

    try {
      List<String> contacts = await fetchCloseContacts();

      for (String contact in contacts) {
        var response = await http.post(
          url,
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
          },
          body: {
            'From': fromPhoneNumber,
            'To': contact,
            'Body':
                '🚨 LIVE TRACKING STARTED 🚨\nJoin the chatroom and track live location: $chatroomURL',
          },
        );

        if (response.statusCode != 201) {
          print('Failed to send SMS to $contact. Response: ${response.body}');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

// Function to fetch contacts from Firestore
  Future<List<String>> fetchCloseContacts() async {
    List<String> contacts = [];
    final snapshot =
        await FirebaseFirestore.instance.collection('close_contacts').get();
    for (var doc in snapshot.docs) {
      contacts.add(
          doc['phone']); // Assumes 'phone' field contains the contact number
    }
    return contacts;
  }
}
