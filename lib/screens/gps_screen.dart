import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_webservice/places.dart' as point;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as auto;

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
  loc.Location _location = loc.Location();
  late Stream<loc.LocationData> _locationStream;
  Map<String, int> _routeReports = {}; // Track reports for each route

  TextEditingController _startController = TextEditingController();
  TextEditingController _endController = TextEditingController();

  get placesSdk => null;

  Future<void> handlePlaceSearch(
      String query, bool isStart, TextEditingController controller) async {
    // Fetch autocomplete predictions
    final result = await placesSdk.findAutocompletePredictions(
      query,
      countries: ["IN"], // Limit search to India (optional)
    );

    if (result.predictions.isNotEmpty) {
      final selectedPrediction = result.predictions.first;

      // Fetch place details using place ID
      final details = await point.GoogleMapsPlaces(
              apiKey: "AIzaSyBh-_JWFESJ5MDxUbdUJ_P5xoKFEiR_LW8")
          .getDetailsByPlaceId(selectedPrediction.placeId!);

      if (details.status == "OK") {
        double lat = details.result.geometry!.location.lat;
        double lng = details.result.geometry!.location.lng;
        String address = details.result.formattedAddress!;

        controller.text = address; // Set the address in TextField

        print("Selected Place: $address");
        print("Latitude: $lat, Longitude: $lng");

        // You can now use lat/lng for mapping, routing, etc.
      } else {
        print("Error fetching place details: ${details.status}");
      }
    } else {
      print("No predictions found!");
    }
  }

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

        print('Fetched directions: ${data['routes']}');

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          List<LatLng> polylinePoints = [];

          for (var route in data['routes']) {
            for (var leg in route['legs']) {
              for (var step in leg['steps']) {
                _directions.add(step['html_instructions']);
                polylinePoints.add(LatLng(
                    step['end_location']['lat'], step['end_location']['lng']));
              }
            }

            String routeId = route['overview_polyline']['points'];

            // Initially all routes will be green (safe)
            _polylines.add(Polyline(
              polylineId: PolylineId(routeId),
              points: polylinePoints,
              color: Colors.green, // Safe route initially
              width: 5,
            ));
          }

          setState(() {
            _routeCoordinates = polylinePoints;
          });

          if (_routeCoordinates.isNotEmpty) {
            LatLngBounds bounds = _getBoundsFromCoordinates(_routeCoordinates);
            if (_mapController != null) {
              _mapController!
                  .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
            }
          }
        } else {
          print('No routes found');
        }
      } else {
        print('Failed to fetch directions');
      }
    } catch (error) {
      print('Error fetching directions: $error');
    }
  }

  // Get route bounds from coordinates
  LatLngBounds _getBoundsFromCoordinates(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (var point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLng == null || point.longitude < minLng) minLng = point.longitude;
      if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // Start tracking user location
  void _startTrackingUser() {
    _locationStream.listen((loc.LocationData currentLocation) {
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
    return "${location.latitude}_${location.longitude}";
  }

  // Fetch location and convert it into LatLng
  Future<LatLng> _getLocationFromPlace(String place) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$place&key=AIzaSyBh-_JWFESJ5MDxUbdUJ_P5xoKFEiR_LW8';
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data['results'].isNotEmpty) {
      double lat = data['results'][0]['geometry']['location']['lat'];
      double lng = data['results'][0]['geometry']['location']['lng'];
      return LatLng(lat, lng);
    } else {
      throw Exception('Failed to get location');
    }
  }

  // method to handle map creation
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
          // Location input fields
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _startController,
              decoration: InputDecoration(labelText: 'Enter Start Location'),
              onChanged: (query) =>
                  handlePlaceSearch(query, true, _startController),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _endController,
              decoration:
                  InputDecoration(labelText: 'Enter Destination Location'),
              onChanged: (query) =>
                  handlePlaceSearch(query, false, _endController),
            ),
          ),
          // Get Directions button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                LatLng origin =
                    await _getLocationFromPlace(_startController.text);
                LatLng destination =
                    await _getLocationFromPlace(_endController.text);
                fetchDirections(origin, destination);
              },
              child: Text('Get Directions'),
            ),
          ),
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
        ],
      ),
    );
  }
}
