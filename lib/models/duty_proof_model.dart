import 'package:cloud_firestore/cloud_firestore.dart';

enum DutyProofStatus { pending, approved, rejected }

class DutyProofModel {
  final String id;
  final String scheduleId;
  final String submittedBy; 
  final String submittedByName;
  final String description;
  final String? imageUrl;
  final DutyProofStatus status;
  final DateTime submittedAt;
  final String? floorId;
  final String? zone;
  final String? location;

  const DutyProofModel({
    required this.id,
    required this.scheduleId,
    required this.submittedBy,
    required this.submittedByName,
    required this.description,
    this.imageUrl,
    required this.status,
    required this.submittedAt,
    this.floorId,
    this.zone,
    this.location,
  });

  factory DutyProofModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DutyProofModel(
      id: documentId,
      scheduleId: map['scheduleId'] ?? '',
      submittedBy: map['submittedBy'] ?? '',
      submittedByName: map['submittedByName'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      status: DutyProofStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => DutyProofStatus.pending,
      ),
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      floorId: map['floorId'],
      zone: map['zone'],
      location: map['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'description': description,
      'imageUrl': imageUrl,
      'status': status.name,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'floorId': floorId,
      'zone': zone,
      'location': location,
    };
  }

  DutyProofModel copyWith({DutyProofStatus? status}) {
    return DutyProofModel(
      id: id,
      scheduleId: scheduleId,
      submittedBy: submittedBy,
      submittedByName: submittedByName,
      description: description,
      imageUrl: imageUrl,
      status: status ?? this.status,
      submittedAt: submittedAt,
      floorId: floorId,
      zone: zone,
      location: location,
    );
  }
}
