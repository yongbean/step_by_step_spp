import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:step_by_step_app/style.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  Widget _buildActivityItem(
    BuildContext context,
    String date,
    String docId,
    String? startAddress,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          startAddress ?? 'Unknown location',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        onTap: () {
          context.push('/userStatus/activity/$docId');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
        title: const Text('Routes', style: appBarTextStyle),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: appGradientBackground,
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tracked_paths')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No recent activities.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final date =
                    data['timestamp']?.toDate().toString().split(' ')[0] ?? '-';
                final startAddress = data['startAddress'] as String?;
                final docId = docs[index].id;

                return _buildActivityItem(context, date, docId, startAddress);
              },
            );
          },
        ),
      ),
    );
  }
}
