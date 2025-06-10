import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActivityDetailPage extends StatefulWidget {
  final String routeId;

  const ActivityDetailPage({super.key, required this.routeId});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  List<LatLng> _routePoints = [];
  GoogleMapController? _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoute(widget.routeId);
  }

  Future<void> _fetchRoute(String routeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('tracked_paths')
        .doc(routeId)
        .get();

    final data = doc.data();
    if (data == null || !data.containsKey('path')) {
      setState(() => _isLoading = false);
      return;
    }

    final points = (data['path'] as List)
        .map((point) => LatLng(point['lat'], point['lng']))
        .toList();

    setState(() {
      _routePoints = points;
      _isLoading = false;
    });
  }

  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    final swLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final swLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final neLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final neLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    return LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    if (_routePoints.isNotEmpty) {
      final bounds = _getLatLngBounds(_routePoints);
      await Future.delayed(const Duration(milliseconds: 100));
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routePoints.isEmpty
              ? const Center(child: Text('No route data found'))
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _routePoints.first,
                    zoom: 17,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('selected_route'),
                      points: _routePoints,
                      color: Colors.blue,
                      width: 5,
                    ),
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('start'),
                      position: _routePoints.first,
                      infoWindow: const InfoWindow(title: 'Start'),
                    ),
                    Marker(
                      markerId: const MarkerId('end'),
                      position: _routePoints.last,
                      infoWindow: const InfoWindow(title: 'End'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                  },
                ),
    );
  }
}
