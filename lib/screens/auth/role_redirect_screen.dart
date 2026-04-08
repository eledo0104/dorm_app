import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleRedirectScreen extends StatefulWidget {
  const RoleRedirectScreen({super.key});

  @override
  State<RoleRedirectScreen> createState() => _RoleRedirectScreenState();
}

class _RoleRedirectScreenState extends State<RoleRedirectScreen> {
  @override
  void initState() {
    super.initState();
    _handleRedirect();
  }

  Future<void> _handleRedirect() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UX transition

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

    final rawRole = doc.data()?['role']?.toString().toLowerCase() ?? '';

    if (!mounted) return;

    if (rawRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (rawRole == 'floor_leader' || rawRole == 'floorleader') {
      Navigator.pushReplacementNamed(context, '/floor_leader');
    } else {
      // Default to resident if role is unknown or 'resident'
      Navigator.pushReplacementNamed(context, '/resident');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

