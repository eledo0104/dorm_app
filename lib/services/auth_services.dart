import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dorm_app/firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===============================
  // CREATE USER ACCOUNT (for admin/floor leader adding users)
  // Uses a secondary Firebase app to avoid signing out the current user
  // ===============================
  Future<String> createUserAccount({
    required String email,
    required String password,
    required String name,
    required String studentId,
    required String role,
    String? gender,
    String? floor,
    String? room,
    String? phone,
  }) async {
    // Create a temporary secondary Firebase app
    FirebaseApp tempApp;
    try {
      tempApp = Firebase.app('tempUserCreation');
    } catch (_) {
      tempApp = await Firebase.initializeApp(
        name: 'tempUserCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // Create the auth account on the secondary app (won't affect current session)
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Sign out from temp app immediately
      await tempAuth.signOut();

      // Write the Firestore user document with the correct auth UID
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'studentId': studentId,
        'role': role,
        'gender': gender?.toLowerCase(),
        'floorId': floor?.isEmpty ?? true ? null : floor,
        'roomNumber': room?.isEmpty ?? true ? null : room,
        'phoneNumber': phone?.isEmpty ?? true ? null : phone,
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      return uid;
    } catch (e) {
      rethrow;
    }
  }

  // ===============================
  // LOGIN WITH EMAIL
  // ===============================
  Future<User?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // ===============================
  // LOGIN WITH STUDENT ID
  // ===============================
  // Future<User?> loginWithStudentId(String studentId, String password) async {
  //   try {
  //     final snapshot =
  //         await _firestore
  //             .collection('users')
  //             .where('studentId', isEqualTo: studentId)
  //             .limit(1)
  //             .get();

  //     if (snapshot.docs.isEmpty) {
  //       throw Exception("Student ID not found");
  //     }

  //     final email = snapshot.docs.first['email'];

  //     final credential = await _auth.signInWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );

  //     return credential.user;
  //   } on FirebaseAuthException catch (e) {
  //     throw Exception(e.message);
  //   }
  // }

  Future<Map<String, dynamic>> loginWithStudentId(
    String studentId,
    String password,
  ) async {
    final snapshot =
        await _firestore
            .collection('users')
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      throw Exception("Student ID not found");
    }

    final userDoc = snapshot.docs.first;
    final email = userDoc['email'];

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return {"user": credential.user, "role": userDoc['role']};
  }

  Future<User?> signup({
    required String email,
    required String password,
    required String name,
    required String studentId,
    required String role,
    required String gender,
    int? floor,
    int? room,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print("🔥 USER CREATED IN AUTH: ${credential.user?.uid}");

      if (credential.user == null) {
        throw Exception("Auth returned null user");
      }

      print("Before Firestore write: uid=${credential.user!.uid}");

      final docRef = _firestore.collection('users').doc(credential.user!.uid);
      try {
        await docRef.set({
          'name': name,
          'studentId': studentId,
          'email': email,
          'role': role,
          'gender': gender.toLowerCase(),
          if (floor != null) 'floorId': floor.toString(),
          if (room != null) 'roomNumber': room.toString(),
          'createdAt': Timestamp.now(),
        });

        print("After Firestore write: wrote to ${docRef.path}");
      } on FirebaseException catch (e, st) {
        print("Firestore set failed: ${e.code} ${e.message}\n$st");
        rethrow;
      }

      return credential.user;
    } on FirebaseAuthException catch (e, st) {
      print("Auth error: ${e.code} ${e.message}\n$st");
      rethrow;
    } on FirebaseException catch (e, st) {
      print("Firestore error: ${e.code} ${e.message}\n$st");
      rethrow;
    } catch (e, st) {
      print("Unknown signup error: $e\n$st");
      rethrow;
    }
  }

  // ===============================
  // GET USER DATA
  // ===============================
  Future<DocumentSnapshot> getCurrentUserData(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  // ===============================
  // LOGOUT
  // ===============================
  Future<void> logout() async {
    await _auth.signOut();
  }
}
