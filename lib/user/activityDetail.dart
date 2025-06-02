import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, required String routeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: const Center(
        child: Text('Activity Detail Page'),
      ),
    );
  }
}