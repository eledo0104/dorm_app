import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dorm_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final snapshot = await FirebaseFirestore.instance.collection('users').get();
  print('--- User List ---');
  for (var doc in snapshot.docs) {
    final data = doc.data();
    print(
      'Name: ${data['name']}, ID: ${data['studentId']}, Role: ${data['role']}, Email: ${data['email']}',
    );
  }
  print('-----------------');
}
