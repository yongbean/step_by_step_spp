import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:step_by_step_app/firebase_options.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      final credential = await fb_auth.FirebaseAuth.instance.signInAnonymously();
      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('user').doc(user.uid).set({
          'uid': user.uid,
          'name': 'Anonymous',
          'createdAt': FieldValue.serverTimestamp(),
        });
        context.pushReplacement('/');
      }
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      providers: [
        EmailAuthProvider(),
        GoogleProvider(clientId: DefaultFirebaseOptions.currentPlatform.iosClientId!),
      ],
      footerBuilder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ElevatedButton(
          onPressed: () => _signInAnonymously(context),
          child: const Text('Sign in as Guest'),
        ),
      ),
      actions: [
        AuthStateChangeAction((context, state) async {
          final user = switch (state) {
            SignedIn state => state.user,
            UserCreated state => state.credential.user,
            _ => null,
          };
          if (user != null) {
            final docRef = FirebaseFirestore.instance.collection('user').doc(user.uid);
            final doc = await docRef.get();
            if (!doc.exists) {
              await docRef.set({
                'uid': user.uid,
                'name': user.displayName ?? 'Guest',
                'email': user.email ?? 'Anonymous',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            context.go('/');
          }
        }),
      ],
    );
  }
}
