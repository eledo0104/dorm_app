import 'package:dorm_app/core/theme.dart';
import 'package:dorm_app/providers/auth_provider.dart' as auth_provider;
import 'package:dorm_app/screens/admin/admin_dashboard.dart';
import 'package:dorm_app/screens/auth/role_redirect_screen.dart';
import 'package:dorm_app/screens/auth/signup_screen.dart';
import 'package:dorm_app/screens/floorleader/floor_leader_dashboard.dart';
import 'package:dorm_app/screens/resident/resident_dashboard.dart';
import 'package:dorm_app/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => auth_provider.AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JIU Dormitory',
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/redirect': (_) => const RoleRedirectScreen(),

        '/admin': (_) => const AdminDashboard(),
        '/floor_leader': (_) => const FloorLeaderDashboard(),
        '/resident': (_) => const ResidentDashboardScreen(),
      },
    );
  }
}
