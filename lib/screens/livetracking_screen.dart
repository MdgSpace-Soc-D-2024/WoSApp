import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
            ],
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:permission_handler/permission_handler.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(); // Initialize Firebase
//   runApp(LiveTrackingScreen());
// }

// class LiveTrackingScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Contact Manager',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: HomeScreen(),
//     );
//   }
// }

// class HomeScreen extends StatefulWidget {
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   List<Contact> phoneContacts = []; // Store device contacts
//   List<Contact> filteredContacts = []; // Store filtered contacts for search
//   String searchQuery = '';

//   List<Map<String, String>> closeContacts =
//       []; // Store the added "Close Contacts" from Firebase
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     requestPermissions();
//     fetchCloseContactsFromFirebase();
//   }

//   // Request permissions to access contacts
//   Future<void> requestPermissions() async {
//     if (await Permission.contacts.request().isGranted) {
//       fetchContacts();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Permission to access contacts denied.'),
//       ));
//     }
//   }

//   // Fetch contacts from the phone
//   Future<void> fetchContacts() async {
//     try {
//       final contacts = await FlutterContacts.getContacts(withProperties: true);
//       setState(() {
//         phoneContacts = contacts;
//         filteredContacts = phoneContacts; // Initialize filtered list
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Failed to load contacts: $e'),
//       ));
//     }
//   }

//   // Fetch close contacts from Firestore
//   Future<void> fetchCloseContactsFromFirebase() async {
//     try {
//       QuerySnapshot snapshot =
//           await _firestore.collection('close_contacts').get();
//       setState(() {
//         closeContacts = snapshot.docs
//             .map((doc) => {
//                   'name': doc['name'] as String,
//                   'phone': doc['phone'] as String,
//                   'id': doc.id, // Ensure type compatibility
//                 })
//             .toList()
//             .cast<Map<String, String>>(); // Explicitly cast to the correct type
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Failed to fetch close contacts: $e'),
//       ));
//     }
//   }

//   // Filter contacts based on search query
//   void filterContacts(String query) {
//     List<Contact> results = [];
//     if (query.isNotEmpty) {
//       results = phoneContacts
//           .where((contact) =>
//               contact.displayName.toLowerCase().contains(query.toLowerCase()))
//           .toList();
//     } else {
//       results = [];
//     }

//     setState(() {
//       searchQuery = query;
//       filteredContacts = results;
//     });
//   }

//   // Save selected contact to Firebase
//   Future<void> saveContactToFirebase(String name, String phone) async {
//     try {
//       // Check if contact already exists
//       bool exists = closeContacts.any((contact) => contact['phone'] == phone);
//       if (exists) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('$name is already in the Close Contacts list.'),
//         ));
//         return;
//       }

//       DocumentReference docRef =
//           await _firestore.collection('close_contacts').add({
//         'name': name,
//         'phone': phone,
//         'timestamp': FieldValue.serverTimestamp(),
//       });

//       setState(() {
//         closeContacts.add({'name': name, 'phone': phone, 'id': docRef.id});
//       });

//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('$name has been added to Firebase.'),
//       ));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Failed to add contact to Firebase: $e'),
//       ));
//     }
//   }

//   // Delete contact from Firebase
//   Future<void> deleteContactFromFirebase(String id) async {
//     try {
//       await _firestore.collection('close_contacts').doc(id).delete();

//       setState(() {
//         closeContacts.removeWhere((contact) => contact['id'] == id);
//       });

//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Contact deleted successfully.'),
//       ));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Failed to delete contact: $e'),
//       ));
//     }
//   }

//   // Add new contact to the "Close Contacts" list
//   void addCloseContact() {
//     String name = nameController.text;
//     String phone = phoneController.text;

//     if (name.isNotEmpty && phone.isNotEmpty) {
//       setState(() {
//         closeContacts.add({
//           'name': name,
//           'phone': phone,
//           'id': '',
//         });
//       });

//       saveContactToFirebase(name, phone);

//       nameController.clear();
//       phoneController.clear();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Please provide both name and phone number.'),
//       ));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('LIVE TRACKING'),
//         bottom: PreferredSize(
//           preferredSize: Size.fromHeight(50),
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Column(
//               children: [
//                 TextField(
//                   decoration: InputDecoration(
//                     hintText: 'Search contacts...',
//                     prefixIcon: Icon(Icons.search),
//                     filled: true,
//                     fillColor: Colors.white,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(25),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                   onChanged: (query) {
//                     setState(() {
//                       searchQuery = query;
//                     });
//                     filterContacts(query);
//                   },
//                 ),
//                 if (searchQuery.isNotEmpty && filteredContacts.isNotEmpty)
//                   Container(
//                     constraints: BoxConstraints(maxHeight: 200),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(10),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.grey.shade300,
//                           blurRadius: 5,
//                           offset: Offset(0, 3),
//                         ),
//                       ],
//                     ),
//                     child: ListView.builder(
//                       shrinkWrap: true,
//                       itemCount: filteredContacts.length,
//                       itemBuilder: (context, index) {
//                         Contact contact = filteredContacts[index];
//                         String name = contact.displayName;
//                         String phone = contact.phones.isNotEmpty
//                             ? contact.phones.first.number
//                             : 'No Number';

//                         return ListTile(
//                           title: Text(name),
//                           subtitle: Text(phone),
//                           onTap: () {
//                             saveContactToFirebase(name, phone);
//                             setState(() {
//                               searchQuery = '';
//                               filteredContacts = [];
//                             });
//                           },
//                         );
//                       },
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             children: [
//               ElevatedButton(
//                 onPressed: addCloseContact,
//                 child: Text('Add New Contact'),
//               ),
//               SizedBox(height: 30),
//               Container(
//                 padding: EdgeInsets.all(10.0),
//                 decoration: BoxDecoration(
//                   color: Colors.blue[50],
//                   borderRadius: BorderRadius.circular(10.0),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Close Contacts',
//                       style:
//                           TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 10),
//                     closeContacts.isNotEmpty
//                         ? ListView.builder(
//                             shrinkWrap: true,
//                             itemCount: closeContacts.length,
//                             itemBuilder: (context, index) {
//                               String name =
//                                   closeContacts[index]['name'] ?? 'No Name';
//                               String phone =
//                                   closeContacts[index]['phone'] ?? 'No Number';
//                               String id = closeContacts[index]['id'] ?? '';

//                               return ListTile(
//                                 leading: CircleAvatar(
//                                   child: Text(name[0].toUpperCase()),
//                                 ),
//                                 title: Text(name),
//                                 subtitle: Text(phone),
//                                 trailing: IconButton(
//                                   icon: Icon(Icons.delete, color: Colors.red),
//                                   onPressed: () =>
//                                       deleteContactFromFirebase(id),
//                                 ),
//                               );
//                             },
//                           )
//                         : Center(
//                             child: Text('No close contacts added yet'),
//                           ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
