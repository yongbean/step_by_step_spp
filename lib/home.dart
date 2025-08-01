import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';
import 'package:step_by_step_app/app_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:step_by_step_app/style.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  loc.LocationData? _currentLocation;
  final loc.Location _location = loc.Location();
  bool _isTracking = false;
  final List<LatLng> _trackedLocations = [];
  Timer? _trackingTimer;
  bool _initialLocationSet = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DateTime _trackingStartTime;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

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
      if (hasPermission == loc.PermissionStatus.granted ||
          await _location.requestPermission() == loc.PermissionStatus.granted) {
        _currentLocation = await _location.getLocation();
        setState(() => _initialLocationSet = true);
        if (_mapController != null) _moveToCurrentLocation();
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
    _trackingStartTime = DateTime.now();
    _trackedLocations.clear();
    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng = LatLng(locationData.latitude!, locationData.longitude!);
        setState(() => _trackedLocations.add(latLng));
        debugPrint('Tracked: $latLng');
      }
    });
  }

  void _stopTracking() async {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    final docId = await _saveTrackedLocationsToDB();
    if (context.mounted && docId != null) {
      context.push('/savePage/$docId');
    }
  }

  Future<String?> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.locality ?? ''} ${place.subLocality ?? ''} ${place.street ?? ''}"
            .trim();
      }
    } catch (e) {
      debugPrint('Failed to get address: $e');
    }
    return null;
  }

  Future<String?> _saveTrackedLocationsToDB() async {
    if (_trackedLocations.isEmpty) return null;
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final duration =
          DateTime.now().difference(_trackingStartTime).inSeconds / 60.0;
      final startAddress = await _getAddressFromLatLng(_trackedLocations.first);

      final newDocRef = await FirebaseFirestore.instance
          .collection('tracked_paths')
          .add({
            'userId': user.uid,
            'userName': user.displayName ?? 'Anonymous',
            'timestamp': FieldValue.serverTimestamp(),
            'path':
                _trackedLocations
                    .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                    .toList(),
            'startAddress': startAddress ?? 'Unknown location',
            'timeDuration': duration.toStringAsFixed(2),
          });

      final userDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc(user.uid);
      final userDoc = await userDocRef.get();
      List<dynamic> pathIds = userDoc.data()?['trackedPathIds'] ?? [];

      pathIds.insert(0, newDocRef.id);
      if (pathIds.length > 10) pathIds = pathIds.sublist(0, 10);

      await userDocRef.update({
        'trackedPathIds': pathIds,
        'lastTrackedAt': FieldValue.serverTimestamp(),
        'startAddress': startAddress ?? 'Unknown location',
      });

      return newDocRef.id;
    } catch (e) {
      debugPrint('Error saving tracked path: $e');
      return null;
    }
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
    setState(() => _isTracking = !_isTracking);
  }

  @override
  Widget build(BuildContext context) {
    final loginState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
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
                context.pop();
                context.go('/');
              },
            ),
            ListTile(
              title: const Text('Routes'),
              onTap: () => context.go('/routes'),
            ),
            ListTile(
              title: const Text('User Status'),
              onTap: () => context.go('/userStatus'),
            ),
            ListTile(
              title: const Text('Logout'),
              onTap: () {
                loginState.signOut();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appGradientBackground),
        child: Stack(
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
      ),
    );
  }
}
