import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uni_links5/uni_links.dart';
import 'package:wosapp/main.dart';
import 'package:wosapp/reusable_widgets/reusable_widgets.dart';
import 'package:wosapp/screens/gps_screen.dart';
import 'package:wosapp/screens/livetracking_screen.dart';
import 'package:wosapp/screens/signin_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';


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
      body: Stack(
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
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => GpsScreen()));
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

void onSOSPressed() async {
  await dotenv.load(fileName: "Dialogflow.env");
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

// Chatbot Integration
class DialogflowService {
  final String projectId = dotenv.env['project_id'] ?? '';
  final String sessionId = Uuid().v4();
  final String languageCode = "en";
  final String serviceAccountKeyPath = "assets/robo-way-nafc-5b483855702a.json";

  Future<String> sendMessage(String message, BuildContext context) async {
    // Load service account credentials
    final jsonKey = await DefaultAssetBundle.of(context)
        .loadString(serviceAccountKeyPath);
    final credentials = json.decode(jsonKey);

    // Generate JWT for authentication
    final token = await _getAccessToken(credentials);

    // API URL
    final url =
        "https://dialogflow.googleapis.com/v2/projects/$projectId/agent/sessions/$sessionId:detectIntent";

    // Request body
    final body = jsonEncode({
      "queryInput": {
        "text": {
          "text": message,
          "languageCode": languageCode,
        }
      }
    });

    // Send POST request to Dialogflow
    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["queryResult"]["fulfillmentText"] ?? "No response from bot.";
    } else {
      throw Exception(
          "Failed to communicate with Dialogflow API: ${response.body}");
    }
  }

  Future<String> _getAccessToken(Map<String, dynamic> credentials) async {
    final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Issued at
    final exp = iat + 3600; // Expiry (1 hour)
    final header = {'alg': 'RS256', 'typ': 'JWT'};
    final payload = {
      'iss': credentials['client_email'],
      'sub': credentials['client_email'],
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': iat,
      'exp': exp,
    };

    // Encode header and payload to Base64Url
    final headerBase64 = base64Url.encode(utf8.encode(json.encode(header)));
    final payloadBase64 = base64Url.encode(utf8.encode(json.encode(payload)));

    // Create the JWT signature
    final signatureInput = '$headerBase64.$payloadBase64';
    final key = utf8.encode(credentials['private_key']);
    final hmac = Hmac(sha256, key);
    final signature = base64Url.encode(hmac.convert(utf8.encode(signatureInput)).bytes);

    // Combine all parts to form the JWT
    final jwt = '$signatureInput.$signature';

    // Exchange JWT for an access token
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': jwt,
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['access_token'];
    } else {
      throw Exception("Failed to generate access token: ${response.body}");
    }
  }
}
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  final DialogflowService _dialogflow = DialogflowService();

  void _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add("You: $message");
    });

    _controller.clear();

    try {
      final response = await _dialogflow.sendMessage(message, context); // Pass context here
      setState(() {
        _messages.add("Bot: $response");
      });
    } catch (e) {
      setState(() {
        _messages.add("Error: Unable to reach the chatbot.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chatbot"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(_messages[index]));
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
                    decoration: InputDecoration(labelText: "Type a message"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
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
