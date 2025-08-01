import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Map<String, dynamic>? _routeData;

  @override
  void initState() {
    super.initState();
    _fetchRoute(widget.routeId);
  }

  Future<void> _fetchRoute(String routeId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('tracked_paths')
            .doc(routeId)
            .get();

    final data = doc.data();
    if (data == null || !data.containsKey('path')) {
      setState(() => _isLoading = false);
      return;
    }

    final points =
        (data['path'] as List)
            .map((point) => LatLng(point['lat'], point['lng']))
            .toList();

    setState(() {
      _routePoints = points;
      _routeData = data;
      _isLoading = false;
    });
  }

  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    final swLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final swLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final neLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final neLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

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

  Widget _buildMapDescriptionPanel(ScrollController scrollController) {
    final startAddress = _routeData?['startAddress'] ?? 'Unknown location';
    final timestamp = (_routeData?['timestamp'] as Timestamp?)?.toDate();
    final createdDate =
        timestamp != null ? timestamp.toString().split(' ')[0] : '-';
    final description = _routeData?['description'] ?? '';
    final user = _routeData?['userName'] ?? 'Anonymous';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(width: 40, height: 4, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Text(
            '📍 Location: $startAddress',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '👤 User: $user',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('📝 Description: $description'),
          const SizedBox(height: 8),
          Text(
            '🕒 Created: $createdDate',
            style: const TextStyle(color: Colors.grey),
          ),
          // const SizedBox(height: 8),
          // const Text('⭐ Rating: 4.5 (example)', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_routeData?['userId'] == user?.uid) ...[
            IconButton(
              icon: const Icon(Icons.create),
              onPressed: () {
                context.push('/savePage/${widget.routeId}');
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('tracked_paths')
                    .doc(widget.routeId)
                    .delete();
                if (context.canPop()) context.pop();
              },
            ),
          ],
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFF0F3FF)],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _routePoints.isEmpty
                ? const Center(child: Text('No route data found'))
                : Stack(
                  children: [
                    GoogleMap(
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
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                        ),
                      },
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.25,
                      minChildSize: 0.15,
                      maxChildSize: 0.6,
                      builder:
                          (context, scrollController) =>
                              _buildMapDescriptionPanel(scrollController),
                    ),
                  ],
                ),
      ),
    );
  }
}
