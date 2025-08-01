import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:step_by_step_app/route_save.dart';
import 'package:step_by_step_app/routes.dart';
import 'package:step_by_step_app/user/activity.dart';
import 'package:step_by_step_app/user/activityDetail.dart';
import 'package:step_by_step_app/app_state.dart';
import 'package:step_by_step_app/firebase_options.dart';
import 'package:step_by_step_app/home.dart';
import 'package:step_by_step_app/login.dart';
import 'package:step_by_step_app/user/userStatus.dart';
import 'package:step_by_step_app/user/profile.dart';
import 'package:step_by_step_app/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 Firebase initialized successfully');
  } catch (e) {
    debugPrint('❗ Firebase initialization failed: $e');
  }
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/start',
  routes: [
    GoRoute(
      path: '/start',
      builder: (context, state) => const StartPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/routes',
      builder: (context, state) => const RoutePage(),
    ),
    GoRoute(
      path: '/savePage/:id',
      builder: (context, state) {
        final routeId = state.pathParameters['id']!;
        return RouteSavePage(routeId: routeId);
      },
    ),
    GoRoute(
      path: '/userStatus',
      builder: (context, state) => const UserStatusPage(),
      routes: [
        GoRoute(
          path: 'profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: 'activity',
          builder: (context, state) => const ActivityPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final routeId = state.pathParameters['id']!;
                return ActivityDetailPage(routeId: routeId);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Step by Step',
      routerConfig: _router,
      theme: ThemeData.light(useMaterial3: true),
    );
  }
}

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: appGradientBackground),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('STEP', style: largeBlueText),
                const Text('BY', style: largeBlueText),
                const Text('STEP', style: largeBlueText),
                const SizedBox(height: 50),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: roundedBlueButton,
                  child: const Text(
                    'Press to Start',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}