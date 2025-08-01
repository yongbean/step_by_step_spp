import 'package:flutter/material.dart';

const Gradient appGradientBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF00F5A0),
    Color(0xFF00D9F5),
    Color(0xFFF0F3FF),
  ],
);

const TextStyle largeBlueText = TextStyle(
  fontSize: 48,
  fontWeight: FontWeight.bold,
  color: Colors.blue,
);

final ButtonStyle roundedBlueButton = ElevatedButton.styleFrom(
  backgroundColor: Colors.blueAccent,
  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(30),
  ),
);

const Color appBarColor = Colors.deepPurple;

const TextStyle appBarTextStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

const TextStyle pageTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
);
