import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<LatLng> _trackedLocations = [];
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _trackingTimer;
  bool _initialLocationSet = false;

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

    final data = {
      'timestamp': DateTime.now(),
      'path':
          _trackedLocations
              .map(
                (latLng) => {'lat': latLng.latitude, 'lng': latLng.longitude},
              )
              .toList(),
    };

    await FirebaseFirestore.instance.collection('tracked_paths').add(data);
    debugPrint('Tracked locations saved to Firestore');
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
            right: 20,
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
