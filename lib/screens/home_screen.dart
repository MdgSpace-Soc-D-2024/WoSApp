import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:dialogflow_flutter/dialogflowFlutter.dart';
import 'package:dialogflow_flutter/googleAuth.dart';
import 'package:dialogflow_flutter/language.dart';
import 'package:encrypt/encrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/digests/sha256.dart';
import 'package:uni_links5/uni_links.dart';
import 'package:wosapp/main.dart';
import 'package:wosapp/reusable_widgets/reusable_widgets.dart';
import 'package:wosapp/screens/gps_screen.dart';
import 'package:wosapp/screens/livetracking_screen.dart';
import 'package:wosapp/screens/signin_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:wosapp/utls/color_utls.dart';

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
          decoration: BoxDecoration(
              gradient: LinearGradient(
            colors: [
              hexStringToColor("CB2393"),
              hexStringToColor("9546C4"),
              hexStringToColor("5E61F4")
            ],
          )),
          child: Stack(
            children: [
              Column(
                children: <Widget>[
                  SizedBox(height: 40.0),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 100.0,
                      width: 100.0,
                      child: FloatingActionButton.large(
                        onPressed: onSOSPressed,
                        backgroundColor: const Color.fromARGB(255, 150, 14, 4),
                        child: Text("SOS",
                            style: TextStyle(
                                fontSize: 40.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                  SizedBox(height: 40.0),
                  gps(context, "GPS", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => GPSNavigationScreen()));
                  }),
                  SizedBox(height: 20.0),
                  gps(context, "Live Tracking", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LiveTrackingScreen()));
                  }),
                ],
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChatScreen()),
                    );
                  },
                  backgroundColor: Colors.green,
                  child: Icon(Icons.chat, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        ));
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

void onSOSPressed() async {
  //await dotenv.load(fileName: "Dialogflow.env");
  try {
    // Step 1: Fetch all phone numbers from Firebase
    List<String> phoneNumbers = await fetchPhoneNumbers();

    // Step 2: SOS message
    String message = 'Help! I am in danger. Please assist me immediately.';

    // Step 3: Send SMS to each contact
    for (var phoneNumber in phoneNumbers) {
      await sendSms(phoneNumber, message);
    }

    print('SOS alerts sent successfully!');
  } catch (e) {
    print('Error sending SOS alerts: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(home: ChatScreen()));
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();

  // Reference to Firestore Collection
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void sendMessage(String message) async {
    if (message.isEmpty) return;

    // Add user message locally
    setState(() {
      messages.insert(0, {'text': message, 'isUser': true});
    });

    // Save user message to Firestore
    await _firestore.collection('chats').add({
      'text': message,
      'isUser': true,
      'timestamp': Timestamp.now(),
    });

    _controller.clear();

    // Initialize Dialogflow
    final authGoogle =
        await AuthGoogle(fileJson: "assets/robo-way-nafc-5b483855702a.json")
            .build();
    final dialogflow =
        DialogFlow(authGoogle: authGoogle, language: Language.ENGLISH);

    // Get response from Dialogflow
    final response = await dialogflow.detectIntent(message);
    final botMessage = response.getMessage() ?? "I didn't understand that!";

    // Add bot message locally
    setState(() {
      messages.insert(0, {'text': botMessage, 'isUser': false});
    });

    // Save bot message to Firestore
    await _firestore.collection('chats').add({
      'text': botMessage,
      'isUser': false,
      'timestamp': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chatbot')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final chatDocs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final message = chatDocs[index];
                    return Align(
                      alignment: message['isUser']
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: message['isUser']
                              ? Colors.blue
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          message['text'],
                          style: TextStyle(
                              color: message['isUser']
                                  ? Colors.white
                                  : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: () => sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChatScreen(),
    );
  }
}

//Deep linking for sos
void initDeepLinking() async {
  // Handle the incoming deep link
  try {
    final link = await getInitialLink();
    if (link != null && link.contains('sos')) {
      // Trigger your SOS logic (e.g., call emergency services, notify authorities, etc.)
      sendSOSAlert();
    }
  } catch (e) {
    print('Error: $e');
  }

  // You can also listen for new deep links while the app is running
  linkStream.listen((link) {
    if (link != null && link.contains('sos')) {
      sendSOSAlert();
    }
  });
}

void sendSOSAlert() {
  // Your SOS logic (e.g., call emergency services, send an alert)
  print('SOS Alert sent!');
  onSOSPressed();
}

class MainScreen extends StatefulWidget {
  @override
  Chatbot_sos createState() => Chatbot_sos();
}

void chatbot() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class Chatbot_sos extends State<MainScreen> {
  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['action'] == 'triggerSOS') {
        triggerSOS();
      }
    });
  }

  void triggerSOS() {
    // Your existing SOS functionality here
    onSOSPressed();
    print('SOS Activated!');
    // Example: Navigate to an SOS screen or call your SOS function
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
