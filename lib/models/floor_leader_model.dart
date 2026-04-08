import 'package:cloud_firestore/cloud_firestore.dart';

class FloorModel {
  final String id;
  final String name;
  final int floorNumber;
  final String floorLeaderId;
  final int totalRooms;
  final int occupiedRooms;
  final DateTime createdAt;

  const FloorModel({
    required this.id,
    required this.name,
    required this.floorNumber,
    required this.floorLeaderId,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.createdAt,
  });

  int get availableRooms => totalRooms - occupiedRooms;

  factory FloorModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FloorModel(
      id: documentId,
      name: map['name'] ?? '',
      floorNumber: map['floorNumber'] ?? 0,
      floorLeaderId: map['floorLeaderId'] ?? '',
      totalRooms: map['totalRooms'] ?? 0,
      occupiedRooms: map['occupiedRooms'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'floorNumber': floorNumber,
      'floorLeaderId': floorLeaderId,
      'totalRooms': totalRooms,
      'occupiedRooms': occupiedRooms,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
