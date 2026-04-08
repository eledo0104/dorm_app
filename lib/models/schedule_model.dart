import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleShift {
  final String id;
  final String zone;
  final String zoneType;
  final String category; // 'campus_work' or 'room_cleaning'
  final String shiftLabel;
  final String location;
  final String timeStart;
  final String timeEnd;
  final DateTime date;
  final List<Map<String, String>> assignedResidents;
  final List<String> assignedUids;
  final String? roomNumber; // for room_cleaning schedules only
  final int weekNumber;
  final int year;
  final bool isManuallyEdited;
  final String generatedBy;

  ScheduleShift({
    required this.id,
    required this.zone,
    required this.zoneType,
    required this.category,
    required this.shiftLabel,
    required this.location,
    required this.timeStart,
    required this.timeEnd,
    required this.date,
    required this.assignedResidents,
    required this.assignedUids,
    this.roomNumber,
    this.weekNumber = 0,
    this.year = 0,
    this.isManuallyEdited = false,
    this.generatedBy = '',
  });

  factory ScheduleShift.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final residents =
        (d['assignedResidents'] as List<dynamic>? ?? [])
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
    return ScheduleShift(
      id: doc.id,
      zone: d['zone'] ?? '',
      zoneType: d['zoneType'] ?? '',
      category: d['category'] ?? 'campus_work',
      shiftLabel: d['shiftLabel'] ?? '',
      location: d['location'] ?? '',
      timeStart: d['timeStart'] ?? '',
      timeEnd: d['timeEnd'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ??
          (d['scheduledAt'] as Timestamp).toDate(),
      assignedResidents: residents,
      assignedUids: List<String>.from(d['assignedUids'] ?? []),
      roomNumber: d['roomNumber'] as String?,
      weekNumber: (d['weekNumber'] as num?)?.toInt() ?? 0,
      year: (d['year'] as num?)?.toInt() ?? 0,
      isManuallyEdited: d['isManuallyEdited'] as bool? ?? false,
      generatedBy: d['generatedBy'] as String? ?? '',
    );
  }
}
