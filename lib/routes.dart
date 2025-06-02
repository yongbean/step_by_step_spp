import 'package:flutter/material.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routes')),
      body: Center(
        child: Text(
          'This is the routes page.',
        ),
      ),
    );
  }
}