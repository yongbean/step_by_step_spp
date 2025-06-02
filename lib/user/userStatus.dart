import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserStatusPage extends StatefulWidget {
  const UserStatusPage({super.key});

  @override
  State<UserStatusPage> createState() => _UserStatusPageStatus();
}

class _UserStatusPageStatus extends State<UserStatusPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
        title: const Text('user status'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('user').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text("Something went wrong: ${snapshot.error}");
          }

          if (snapshot.hasData && !snapshot.data!.exists) {
            return const Text("Document does not exist");
          }
          if (snapshot.connectionState == ConnectionState.done) {
            Map<String, dynamic> data =
                snapshot.data!.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.go('/userStatus/profile');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage(
                              'assets/avatar.png',
                            ), // substitute with actual image
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['name']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                '@${data['name']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.edit, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_run,
                          color: Colors.yellow,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Current jogging',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              '01:09:44',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text(
                              '10.9 km',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              '539 kcal',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go('/userStatus/activity');
                        },
                        child: const Text('All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        (data['trackedPaths'] == null ||
                                data['trackedPaths'].isEmpty)
                            ? const Center(child: Text('No recent activity'))
                            : ListView.builder(
                              itemCount: (data['trackedPaths'] as List).length,
                              itemBuilder: (context, index) {
                                final activity = data['trackedPaths'][index];
                                final date =
                                    (activity['timestamp'] as Timestamp?)
                                        ?.toDate();
                                final path = activity['path'] as List<dynamic>;

                                final distanceKm = _calculateDistance(
                                  path,
                                ).toStringAsFixed(2);
                                final kcal = _estimateKcal(distanceKm);
                                final avgSpeed = _estimateSpeed(
                                  distanceKm,
                                ); // or dummy

                                return _buildActivityItem(
                                  context,
                                  date != null
                                      ? _formatDate(date)
                                      : 'Unknown date',
                                  '$distanceKm km',
                                  '$kcal kcal',
                                  '$avgSpeed km/h',
                                  index, // pass index as ID for navigation
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No data available'));
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

double _calculateDistance(List<dynamic> path) {
  if (path.length < 2) return 0.0;

  double total = 0.0;
  for (int i = 1; i < path.length; i++) {
    final p1 = path[i - 1];
    final p2 = path[i];
    total += _haversine(p1['lat'], p1['lng'], p2['lat'], p2['lng']);
  }
  return total;
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth radius in km
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = 
    (sin(dLat / 2) * sin(dLat / 2)) +
    cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
    sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _deg2rad(double deg) => deg * (pi / 180);

String _estimateKcal(String kmStr) {
  final km = double.tryParse(kmStr) ?? 0.0;
  return (km * 50).toStringAsFixed(0); // 예: 1km당 50kcal
}

String _estimateSpeed(String kmStr) {
  final km = double.tryParse(kmStr) ?? 0.0;
  return (km / 1.0).toStringAsFixed(1); // 예: 1시간 달렸다고 가정
}


  Widget _buildActivityItem(
    BuildContext context,
    String date,
    String distance,
    String kcal,
    String speed,
    int id,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: const DecorationImage(
              image: AssetImage('assets/map_placeholder.png'), // 실제 썸네일로 변경 가능
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(date),
        subtitle: Text('$kcal   $speed'),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(distance, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        onTap: () {
          context.go('/userStatus/activity/$id');
        },
      ),
    );
  }
}
