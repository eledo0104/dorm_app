import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;

  final String? floorId; // nullable (admin tidak punya floor)
  final String? roomNumber; // nullable (admin tidak punya kamar)

  final String? phoneNumber;
  final String? photoUrl;
  final String? studentId;

  final String? gender;
  final ResidentStatus status;
  final DateTime createdAt;
  final DateTime? checkInDate;
  final DateTime? checkOutDate;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.floorId,
    this.roomNumber,
    this.phoneNumber,
    this.photoUrl,
    this.studentId,
    this.gender,
    this.status = ResidentStatus.active,
    required this.createdAt,
    this.checkInDate,
    this.checkOutDate,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isFloorLeader => role == UserRole.floorLeader;
  bool get isResident => role == UserRole.resident;

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: _parseRole(map['role']),
      floorId: map['floorId'],
      roomNumber: map['roomNumber'],
      phoneNumber: map['phoneNumber'],
      photoUrl: map['photoUrl'],
      studentId: map['studentId'],
      gender: map['gender'],
      status: UserRole.values.any((e) => e.name == map['status']) // prevent crashing if status is invalid
          ? ResidentStatus.active // Default if not found
          : ResidentStatus.values.firstWhere(
            (e) => e.name == map['status'],
            orElse: () => ResidentStatus.active,
          ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkInDate: (map['checkInDate'] as Timestamp?)?.toDate(),
      checkOutDate: (map['checkOutDate'] as Timestamp?)?.toDate(),
    );
  }

  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.resident;
    switch (roleStr) {
      case 'admin':
        return UserRole.admin;
      case 'floor_leader':
      case 'floorLeader':
        return UserRole.floorLeader;
      case 'resident':
      default:
        return UserRole.resident;
    }
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.floorLeader:
        return 'floor_leader';
      case UserRole.resident:
        return 'resident';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': _roleToString(role),
      'floorId': floorId,
      'roomNumber': roomNumber,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'studentId': studentId,
      'gender': gender,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'checkInDate':
          checkInDate != null ? Timestamp.fromDate(checkInDate!) : null,
      'checkOutDate':
          checkOutDate != null ? Timestamp.fromDate(checkOutDate!) : null,
    };
  }
}
