import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:step_by_step_app/style.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.push('/userStatus');
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appGradientBackground),
        child: const Center(
          child: Text(
            'Profile Page',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}