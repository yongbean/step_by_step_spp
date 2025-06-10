import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class UserStatusPage extends StatefulWidget {
  const UserStatusPage({super.key});

  @override
  State<UserStatusPage> createState() => _UserStatusPageState();
}

class _UserStatusPageState extends State<UserStatusPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<Map<String, dynamic>> _userActivityData;

  @override
  void initState() {
    super.initState();
    // Initialize the future in initState to prevent it from being called on every build
    _userActivityData = _fetchUserActivityData();
  }

  /// Fetches both user data and their recent activities in a single operation.
  Future<Map<String, dynamic>> _fetchUserActivityData() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      // If user is not logged in, throw an error to be caught by the FutureBuilder.
      throw Exception('User not logged in.');
    }

    // 1. Fetch the user's document to get their profile info and path IDs
    final userDoc = await _firestore.collection('user').doc(user.uid).get();
    if (!userDoc.exists) {
      throw Exception('User document does not exist.');
    }

    final userData = userDoc.data()!;
    final List<String> pathIds = List<String>.from(userData['trackedPathIds'] ?? []);

    List<DocumentSnapshot> activities = [];
    if (pathIds.isNotEmpty) {
      // 2. Fetch all activity documents corresponding to the IDs
      final activityDocs = await _firestore
          .collection('tracked_paths')
          .where(FieldPath.documentId, whereIn: pathIds)
          .get();

      // Create a map for quick lookups
      final activityMap = {for (var doc in activityDocs.docs) doc.id: doc};
      
      // 3. Order the fetched activities based on the original `pathIds` list
      activities = pathIds.map((id) => activityMap[id]).whereType<DocumentSnapshot>().toList();
    }

    // 4. Return both user data and the list of activities
    return {'userData': userData, 'activities': activities};
  }

  /// Formats a DateTime object into a more readable string.
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('User Status'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userActivityData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Something went wrong: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No data available."));
          }

          final Map<String, dynamic> userData = snapshot.data!['userData'];
          final List<DocumentSnapshot> activities = snapshot.data!['activities'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- User Profile Section ---
                GestureDetector(
                  onTap: () => context.go('/userStatus/profile'),
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
                          backgroundImage: AssetImage('assets/avatar.png'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData['name'] ?? 'No Name',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '@${userData['name'] ?? 'username'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              // Display the last known address if it exists
                              if (userData['startAddress'] != null &&
                                  (userData['startAddress'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          color: Colors.white70, size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Last at: ${userData['startAddress']}',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // --- Recent Activity Section ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/userStatus/activity'),
                      child: const Text('See All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: activities.isEmpty
                      ? const Center(
                          child: Text(
                            'No recent activity.\nStart tracking to see your runs here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: activities.length,
                          itemBuilder: (context, index) {
                            final activity = activities[index];
                            final activityData = activity.data() as Map<String, dynamic>;
                            
                            // Safely get timestamp and convert it to DateTime
                            final timestamp = activityData['timestamp'] as Timestamp?;
                            final date = timestamp?.toDate();

                            return _buildActivityItem(
                              context: context,
                              startAddress: activityData['startAddress'] ?? 'Unknown Location',
                              date: date != null ? _formatDate(date) : 'Unknown Date',
                              activityId: activity.id,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds a single activity item card for the list.
  Widget _buildActivityItem({
    required BuildContext context,
    required String startAddress,
    required String date,
    required String activityId,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
            image: const DecorationImage(
              image: AssetImage('assets/map_placeholder.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: const Icon(Icons.location_on, color: Colors.deepPurple),
        ),
        title: Text(
          startAddress,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(date),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          // Navigate to a detailed view of the activity using its unique ID
          context.push('/userStatus/activity/$activityId');
        },
      ),
    );
  }
}
