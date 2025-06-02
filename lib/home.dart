import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:step_by_step_app/app_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LocationData? _currentLocation;
  final Location _location = Location();
  bool _isTracking = false;
  final List<LatLng> _trackedLocations = [];
  Timer? _trackingTimer;
  bool _initialLocationSet = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  GoogleMapController? _mapController;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _moveToCurrentLocation();
    }
  }

  void _moveToCurrentLocation() {
    final latLng = LatLng(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await _location.hasPermission();
      if (hasPermission == PermissionStatus.granted ||
          await _location.requestPermission() == PermissionStatus.granted) {
        _currentLocation = await _location.getLocation();

        setState(() {
          _initialLocationSet = true;
        });

        if (_mapController != null) {
          _moveToCurrentLocation();
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Set<Polyline> _buildPolylines() {
    return {
      Polyline(
        polylineId: const PolylineId('tracking_path'),
        points: _trackedLocations,
        color: Colors.blue,
        width: 5,
      ),
    };
  }

  void _startTracking() {
    _trackedLocations.clear();
    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng = LatLng(locationData.latitude!, locationData.longitude!);
        setState(() {
          _trackedLocations.add(latLng);
        });
        debugPrint('Tracked: $latLng');
      }
    });
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  Future<void> _saveTrackedLocationsToDB() async {
    if (_trackedLocations.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('User not logged in. Cannot save to Firestore.');
      return;
    }

    final newPath = {
      'timestamp': FieldValue.serverTimestamp(),
      'path':
          _trackedLocations
              .map(
                (latLng) => {'lat': latLng.latitude, 'lng': latLng.longitude},
              )
              .toList(),
    };

    final userDocRef = FirebaseFirestore.instance
        .collection('user')
        .doc(user.uid);

    try {
      final userDoc = await userDocRef.get();
      List<dynamic> trackedPaths = [];

      if (userDoc.exists && userDoc.data()?['trackedPaths'] is List) {
        trackedPaths = List.from(userDoc['trackedPaths']);
      }

      // 새 path를 추가하고, 최신 순으로 정렬 후 상위 10개만 유지
      trackedPaths.insert(0, newPath);
      if (trackedPaths.length > 10) {
        trackedPaths = trackedPaths.sublist(0, 10);
      }

      await userDocRef.update({
        'trackedPaths': trackedPaths,
        'lastTrackedAt': FieldValue.serverTimestamp(),
      });

      // 동시에 tracked_paths에도 기록 (옵션)
      await FirebaseFirestore.instance.collection('tracked_paths').add({
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'path': newPath['path'],
      });

      debugPrint('Tracked locations saved to Firestore: ${user.uid}');
    } catch (e) {
      debugPrint('Error saving tracked locations: $e');
    }
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
      _saveTrackedLocationsToDB();

      setState(() {
        _isTracking = false;
      });
    } else {
      _startTracking();
      setState(() {
        _isTracking = true;
      });
    }
  }

  // San Francisco coordinates
  @override
  Widget build(BuildContext context) {
    final loginState = context.watch<AppState>();
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Select an option'),
            ),
            ListTile(
              title: const Text('Home'),
              onTap: () {
                // Navigate to the home page
                context.pop();
                context.go('/');
              },
            ),
            ListTile(
              title: const Text('Routes'),
              onTap: () {
                // Navigate to the routes page
                context.pop();
                context.go('/routes');
              },
            ),
            ListTile(
              title: const Text('User Status'),
              onTap: () {
                // Navigate to the profile page
                context.pop();
                context.go('/userStatus');
              },
            ),
            ListTile(
              title: const Text('Settings'),
              onTap: () {
                // Navigate to the settings page
                context.pop();
                context.go('/settings');
              },
            ),
            ListTile(
              title: const Text('Logout'),
              onTap: () {
                // Perform logout action
                context.pop();
                context.go('/login');
                loginState.signOut();
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_initialLocationSet)
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentLocation!.latitude!,
                  _currentLocation!.longitude!,
                ),
                zoom: 17,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: {
                Marker(
                  markerId: const MarkerId('currentLocation'),
                  position: LatLng(
                    _currentLocation!.latitude!,
                    _currentLocation!.longitude!,
                  ),
                  infoWindow: const InfoWindow(title: 'You are here'),
                ),
              },
              polylines: _buildPolylines(),
            )
          else
            const Center(child: CircularProgressIndicator()),

          Positioned(
            bottom: 30,
            left: MediaQuery.of(context).size.width / 2 - 28,
            child: FloatingActionButton(
              onPressed: _toggleTracking,
              backgroundColor: _isTracking ? Colors.red : Colors.deepPurple,
              shape: const CircleBorder(),
              child: Icon(
                _isTracking ? Icons.pause : Icons.play_arrow,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
