import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(Gps());
}

class Gps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GPSNavigationScreen(),
    );
  }
}

class GPSNavigationScreen extends StatefulWidget {
  @override
  _GPSNavigationScreenState createState() => _GPSNavigationScreenState();
}

class _GPSNavigationScreenState extends State<GPSNavigationScreen> {
  GoogleMapController? _mapController;
  LatLng _userPosition = LatLng(28.7041, 77.1025); // Default to New Delhi
  Set<Polyline> _polylines = {};
  List<String> _directions = [];
  List<LatLng> _routeCoordinates = [];
  Location _location = Location();
  late Stream<LocationData> _locationStream;
  Map<String, int> _routeReports = {}; // Track reports for each route
  List<LatLng> _unsafeRoutes = []; // Unsafe routes based on reports

  @override
  void initState() {
    super.initState();
    _locationStream = _location.onLocationChanged;
    _startTrackingUser();
  }

  // Fetch Directions from Google Maps API
  Future<void> fetchDirections(LatLng origin, LatLng destination) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&key=AIzaSyBh-_JWFESJ5MDxUbdUJ_P5xoKFEiR_LW8';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if the response contains valid route data
        if (data != null &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          List<LatLng> polylinePoints = [];

          for (var route in data['routes']) {
            for (var leg in route['legs']) {
              for (var step in leg['steps']) {
                _directions.add(step['html_instructions']);
                polylinePoints.add(LatLng(
                    step['end_location']['lat'], step['end_location']['lng']));
              }
            }

            // Initially all routes will be green (safe)
            _polylines.add(Polyline(
              polylineId: PolylineId(route['overview_polyline']['points']),
              points: polylinePoints,
              color: Colors.green, // Safe route initially
              width: 5,
            ));
          }

          setState(() {
            _routeCoordinates = polylinePoints;
          });
        } else {
          throw Exception('No routes found');
        }
      } else {
        throw Exception('Failed to fetch directions');
      }
    } catch (error) {
      print('Error fetching directions: $error');
    }
  }

  // Start tracking user location
  void _startTrackingUser() {
    _locationStream.listen((LocationData currentLocation) {
      setState(() {
        _userPosition =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
      });
      if (_mapController != null) {
        _mapController!
            .animateCamera(CameraUpdate.newLatLngZoom(_userPosition, 14));
      }
    });
  }

  // Report unsafe areas in Firebase
  // Report unsafe areas in Firebase
  void _reportUnsafeArea(LatLng location) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'location': GeoPoint(location.latitude, location.longitude),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'unsafe',
    });

    // Update route colors after reporting
    _fetchAndUpdateRouteColors();
  }

// Fetch reports from Firestore and update route colors
  void _fetchAndUpdateRouteColors() async {
    QuerySnapshot reportsSnapshot =
        await FirebaseFirestore.instance.collection('reports').get();

    Map<String, int> routeReportsCount = {};

    for (var doc in reportsSnapshot.docs) {
      GeoPoint point = doc['location'];
      String routeId =
          _getRouteIdFromLocation(LatLng(point.latitude, point.longitude));

      if (routeReportsCount.containsKey(routeId)) {
        routeReportsCount[routeId] = routeReportsCount[routeId]! + 1;
      } else {
        routeReportsCount[routeId] = 1;
      }
    }

    _routeReports = routeReportsCount;

    // Update polylines with safe (green), caution (orange), or unsafe (red) color
    _polylines = _polylines.map((polyline) {
      String routeId = polyline.polylineId.value;
      int reportCount = _routeReports[routeId] ?? 0;

      Color polylineColor;
      if (reportCount >= 7) {
        polylineColor = Colors.red; // Unsafe
      } else if (reportCount >= 3) {
        polylineColor = Colors.orange; // Caution
      } else {
        polylineColor = Colors.green; // Safe
      }

      return Polyline(
        polylineId: polyline.polylineId,
        points: polyline.points,
        color: polylineColor,
        width: 5,
      );
    }).toSet();

    setState(() {});
  }

// Get route identifier from location (simplified for this example)
  String _getRouteIdFromLocation(LatLng location) {
    // This should be based on actual route segments, but for now using coordinates as an identifier
    return "${location.latitude}_${location.longitude}";
  }

//method to handle map creation
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapController != null) {
      _mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(_userPosition, 14));
    } else {
      print("Map controller is not initialized yet");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GPS Navigation')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _userPosition,
                zoom: 14.0,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('user_location'),
                  position: _userPosition,
                  infoWindow: InfoWindow(title: 'Your Location'),
                ),
              },
              polylines: _polylines,
              onLongPress: (LatLng tappedPoint) {
                _reportUnsafeArea(tappedPoint); // Report unsafe area
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                LatLng origin = _userPosition;
                LatLng destination = LatLng(28.7041,
                    77.2090); // Example destination (e.g., New Delhi to Gurgaon)
                fetchDirections(origin, destination);
              },
              child: Text('Get Directions'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _directions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_directions[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
