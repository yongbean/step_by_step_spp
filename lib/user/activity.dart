import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User\'s Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/userStatus');
          },
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Activity 1'),
            subtitle: Text('Description of Activity 1'),
          ),
          ListTile(
            title: Text('Activity 2'),
            subtitle: Text('Description of Activity 2'),
          ),
          ListTile(
            title: Text('Activity 3'),
            subtitle: Text('Description of Activity 3'),
          ),
        ],
      ),
    );
  }
}