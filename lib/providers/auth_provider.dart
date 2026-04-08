import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dorm_app/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? user;
  String? role;
  bool isLoading = false;

  Future<void> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    user = await _authService.login(email, password);

    if (user != null) {
      DocumentSnapshot data = await _authService.getCurrentUserData(user!.uid);
      role = data['role'];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required String studentId,
    required String role,
    required String gender,
    int? floor,
    int? room,
  }) async {
    isLoading = true;
    notifyListeners();

    user = await _authService.signup(
      email: email,
      password: password,
      name: name,
      studentId: studentId,
      role: role,
      gender: gender,
      floor: floor,
      room: room,
    );

    this.role = role;

    isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    role = null;
    notifyListeners();
  }

  // Future<void> loginWithStudentId(String studentId, String password) async {
  //   isLoading = true;
  //   notifyListeners();

  //   user = await _authService.loginWithStudentId(studentId, password);

  //   if (user != null) {
  //     DocumentSnapshot data = await _authService.getCurrentUserData(user!.uid);
  //     role = data['role'];
  //   }

  //   isLoading = false;
  //   notifyListeners();

  Future<void> loginWithStudentId(String studentId, String password) async {
    isLoading = true;
    notifyListeners();

    final result = await _authService.loginWithStudentId(studentId, password);

    user = result["user"];
    role = result["role"];

    isLoading = false;
    notifyListeners();
  }
}
