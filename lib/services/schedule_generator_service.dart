import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dorm_app/models/location_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Resident record used internally by the generator
// ─────────────────────────────────────────────────────────────────────────────
class _ResidentRecord {
  final String uid;
  final String name;
  final String photoUrl;
  final Map<String, int> locationCounts;

  _ResidentRecord({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.locationCounts,
  });

  int countFor(String locationName) => locationCounts[locationName] ?? 0;
  int get totalVisits => locationCounts.values.fold(0, (a, b) => a + b);
}

// ─────────────────────────────────────────────────────────────────────────────
/// Summary returned after generation
// ─────────────────────────────────────────────────────────────────────────────
class CreationResult {
  final int shiftsCreated;
  final int residentsAssigned;
  final DateTime friday;
  final int weekNumber;

  const CreationResult({
    required this.shiftsCreated,
    required this.residentsAssigned,
    required this.friday,
    required this.weekNumber,
  });
}


const List<Map<String, String>> kDutyAreas = [
  {'zone': 'Cafeteria Sweep',    'location': 'Sweep the cafeteria area.'},
  {'zone': 'Cafeteria Mop',      'location': 'Mop the cafeteria floor.'},
  {'zone': 'Cafeteria Tables',   'location': 'Wipe the cafeteria tables and arrange the chairs properly.'},
  {'zone': 'Kitchen & Trash',    'location': 'Clean the kitchen and dispose of cafeteria trash.'},
  {'zone': 'Trash Collection',   'location': 'Collect trash from all areas and dispose of it in the main trash collection area.'},
  {'zone': 'Cafeteria Terrace',  'location': 'Sweep and mop the cafeteria terrace.'},
  {'zone': 'Thomas House Hall',  'location': 'Clean the ground hall of Thomas House (beside and in front of the study room).'},
  {'zone': 'Dorm Terrace Sweep', 'location': 'Sweep the dormitory terrace from front to back.'},
  {'zone': 'Dorm Terrace Mop',   'location': 'Mop the dormitory terrace from front to back.'},
  {'zone': 'Ceilings & Walls',   'location': 'Clean the ceilings and walls.'},
];

// ─────────────────────────────────────────────────────────────────────────────
class ScheduleGeneratorService {
  final FirebaseFirestore _db;

  ScheduleGeneratorService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── ISO week number (1-53) ──────────────────────────────────────────────────
  static int isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1)
        .add(Duration(days: (4 - DateTime(thursday.year, 1, 1).weekday + 7) % 7));
    return ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
  }

  // ── Next Friday from today ──────────────────────────────────────────────────
  static DateTime nextFriday([DateTime? from]) {
    final now = from ?? DateTime.now();
    final daysUntilFriday = (5 - now.weekday + 7) % 7;
    final friday = now.add(Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday));
    return DateTime(friday.year, friday.month, friday.day, 7, 0);
  }

  // ── Seeded shuffle (tiebreaker — same week → same order) ──────────────────
  List<T> _seededShuffle<T>(List<T> list, int seed) {
    final rng = Random(seed);
    final copy = List<T>.from(list);
    for (int i = copy.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  // ── Fetch residents with their locationCounts ──────────────────────────────
  Future<List<_ResidentRecord>> _fetchResidents() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      final counts = Map<String, int>.from(
        (d['locationCounts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
      return _ResidentRecord(
        uid: doc.id,
        name: d['name'] ?? 'Unknown',
        photoUrl: d['photoUrl'] ?? '',
        locationCounts: counts,
      );
    }).toList();
  }

  // ── Fetch active locations from Firestore (falls back to kDutyAreas) ───────
  Future<List<DutyLocation>> _fetchLocations() async {
    try {
      final snap = await _db
          .collection('locations')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map(DutyLocation.fromFirestore).toList();
      }
    } catch (_) {}
    // Fallback to hardcoded list with default capacity 1–10
    return kDutyAreas.asMap().entries.map((e) => DutyLocation(
      id: 'area_${e.key}',
      name: e.value['zone']!,
      label: e.value['location']!,
      minPeople: 1,
      maxPeople: 10,
      order: e.key,
    )).toList();
  }

  // ── Check if schedule already exists for a given Friday ───────────────────
  Future<bool> scheduleExistsForFriday(DateTime friday) async {
    final start = DateTime(friday.year, friday.month, friday.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _db
        .collection('schedules')
        .where('category', isEqualTo: 'campus_work')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN CREATION — history-weighted greedy rotation
  // ══════════════════════════════════════════════════════════════════════════
  Future<CreationResult> createWeeklyCampusSchedule({
    int rotationOffset = 0,
    bool overwriteExisting = false,
    String? createdByUid,
  }) async {
    final friday = nextFriday(
      DateTime.now().add(Duration(days: rotationOffset * 7)),
    );
    final weekNum = isoWeekNumber(friday);
    final seed = friday.year * 100 + weekNum;

    // 1. Delete existing schedule docs for this Friday (if overwrite)
    if (overwriteExisting) {
      await _deleteExistingForFriday(friday);
    }

    // 2. Load data in parallel
    final results = await Future.wait([
      _fetchResidents(),
      _fetchLocations(),
    ]);
    final residents = results[0] as List<_ResidentRecord>;
    final locations = results[1] as List<DutyLocation>;

    if (residents.isEmpty) throw Exception('No residents found in Firestore.');
    if (locations.isEmpty) throw Exception('No active locations found.');

    // 3. Tiebreaker: seeded shuffle so equal-count residents are ordered deterministically
    final shuffled = _seededShuffle(residents, seed);

    // 4. Compute per-location slot counts (respects min/max)
    final slotCounts = _computeSlotCounts(
      totalResidents: shuffled.length,
      locations: locations,
    );

    // 5. History-weighted greedy assignment
    final assignments = _assignResidents(
      residents: shuffled,
      locations: locations,
      slotCounts: slotCounts,
    );

    // 6. Persist: schedule docs + locationCounts updates (batched)
    await _persistAssignments(
      friday: friday,
      weekNum: weekNum,
      seed: seed,
      locations: locations,
      assignments: assignments,
      createdByUid: createdByUid,
    );

    // 7. Write history snapshot
    await _writeHistorySnapshot(
      friday: friday,
      weekNum: weekNum,
      assignments: assignments,
      totalResidents: residents.length,
    );

    return CreationResult(
      shiftsCreated: locations.length,
      residentsAssigned: residents.length,
      friday: friday,
      weekNumber: weekNum,
    );
  }

  // ── Compute slot counts per location ──────────────────────────────────────
  Map<String, int> _computeSlotCounts({
    required int totalResidents,
    required List<DutyLocation> locations,
  }) {
    final slotCounts = <String, int>{};
    final base = totalResidents ~/ locations.length;

    for (final loc in locations) {
      slotCounts[loc.name] = base.clamp(loc.minPeople, loc.maxPeople);
    }

    // Distribute remaining slots to locations with most headroom
    int assigned = slotCounts.values.fold(0, (a, b) => a + b);
    int remaining = totalResidents - assigned;

    final sortedByHeadroom = List<DutyLocation>.from(locations)
      ..sort((a, b) =>
          (b.maxPeople - slotCounts[b.name]!) -
          (a.maxPeople - slotCounts[a.name]!));

    int idx = 0;
    while (remaining > 0) {
      final loc = sortedByHeadroom[idx % sortedByHeadroom.length];
      if (slotCounts[loc.name]! < loc.maxPeople) {
        slotCounts[loc.name] = slotCounts[loc.name]! + 1;
        remaining--;
      }
      idx++;
      if (idx > sortedByHeadroom.length * 2) break; // safety
    }

    return slotCounts;
  }

  // ── History-weighted greedy assignment ────────────────────────────────────
  Map<String, List<_ResidentRecord>> _assignResidents({
    required List<_ResidentRecord> residents,
    required List<DutyLocation> locations,
    required Map<String, int> slotCounts,
  }) {
    final assignments = <String, List<_ResidentRecord>>{
      for (final loc in locations) loc.name: [],
    };
    final unassigned = Set<String>.from(residents.map((r) => r.uid));

    // Strictest capacity first (smallest maxPeople → filled first)
    final sortedLocations = List<DutyLocation>.from(locations)
      ..sort((a, b) => a.maxPeople.compareTo(b.maxPeople));

    for (final loc in sortedLocations) {
      final needed = slotCounts[loc.name] ?? loc.minPeople;

      // Sort unassigned residents: fewest visits to THIS location first,
      // then fewest total visits overall (tiebreaker — seeded shuffle already applied)
      final candidates = residents
          .where((r) => unassigned.contains(r.uid))
          .toList()
        ..sort((a, b) {
          final diff = a.countFor(loc.name) - b.countFor(loc.name);
          if (diff != 0) return diff;
          return a.totalVisits - b.totalVisits;
        });

      final picked = candidates.take(needed).toList();
      assignments[loc.name] = picked;
      for (final r in picked) {
        unassigned.remove(r.uid);
      }
    }

    // Distribute any leftover residents to least-filled locations
    for (final uid in unassigned) {
      final resident = residents.firstWhere((r) => r.uid == uid);
      final targetLoc = locations.reduce((a, b) {
        final aFill = assignments[a.name]!.length / a.maxPeople;
        final bFill = assignments[b.name]!.length / b.maxPeople;
        return aFill <= bFill ? a : b;
      });
      assignments[targetLoc.name]!.add(resident);
    }

    return assignments;
  }

  // ── Persist schedule docs + update locationCounts ─────────────────────────
  Future<void> _persistAssignments({
    required DateTime friday,
    required int weekNum,
    required int seed,
    required List<DutyLocation> locations,
    required Map<String, List<_ResidentRecord>> assignments,
    String? createdByUid,
  }) async {
    WriteBatch batch = _db.batch();
    int opCount = 0;

    // Write one schedule doc per location
    for (final loc in locations) {
      final assignedList = assignments[loc.name] ?? [];
      final ref = _db.collection('schedules').doc();
      batch.set(ref, {
        'category': 'campus_work',
        'weekNumber': weekNum,
        'year': friday.year,
        'zone': loc.name,
        'zoneType': loc.name.toUpperCase(),
        'location': loc.label,
        'title': 'Work Duty – ${loc.name}',
        'shiftLabel': 'Work Duty',
        'timeStart': '07:00 AM',
        'timeEnd': '09:00 AM',
        'scheduledAt': Timestamp.fromDate(friday),
        'date': Timestamp.fromDate(
            DateTime(friday.year, friday.month, friday.day)),
        'assignedResidents': assignedList
            .map((r) => {'uid': r.uid, 'name': r.name, 'avatarUrl': r.photoUrl})
            .toList(),
        'assignedUids': assignedList.map((r) => r.uid).toList(),
        'totalResidents': assignedList.length,
        'rotationSeed': seed,
        'generatedBy': createdByUid ?? '',
        'isManuallyEdited': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      opCount++;
    }

    // Increment locationCounts for each resident
    for (final loc in locations) {
      for (final resident in assignments[loc.name] ?? []) {
        final userRef = _db.collection('users').doc(resident.uid);
        batch.update(userRef, {
          'locationCounts.${loc.name}': FieldValue.increment(1),
        });
        opCount++;

        // Firestore batch limit = 500; commit & start a new batch when close
        if (opCount >= 490) {
          await batch.commit();
          batch = _db.batch();
          opCount = 0;
        }
      }
    }

    await batch.commit();
  }

  // ── History snapshot ──────────────────────────────────────────────────────
  Future<void> _writeHistorySnapshot({
    required DateTime friday,
    required int weekNum,
    required Map<String, List<_ResidentRecord>> assignments,
    required int totalResidents,
  }) async {
    final historyId =
        '${friday.year}_W${weekNum.toString().padLeft(2, '0')}';
    final assignmentMap = <String, String>{};
    for (final entry in assignments.entries) {
      for (final resident in entry.value) {
        assignmentMap[resident.uid] = entry.key;
      }
    }
    await _db.collection('schedule_history').doc(historyId).set({
      'weekNumber': weekNum,
      'year': friday.year,
      'fridayDate': Timestamp.fromDate(friday),
      'totalResidents': totalResidents,
      'assignmentMap': assignmentMap,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Delete existing schedule docs for a Friday ────────────────────────────
  Future<void> _deleteExistingForFriday(DateTime friday) async {
    final start = DateTime(friday.year, friday.month, friday.day);
    final end = start.add(const Duration(days: 1));
    final existing = await _db
        .collection('schedules')
        .where('category', isEqualTo: 'campus_work')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MANUAL ADJUSTMENT OPERATIONS
  // All methods mark the affected schedule doc(s) as isManuallyEdited = true.
  // NOTE: locationCounts are NOT updated for manual moves to avoid skewing
  // the algorithm — only auto-generation updates counts.
  // ══════════════════════════════════════════════════════════════════════════

  /// Move [resident] from [fromScheduleId] to [toScheduleId].
  Future<void> moveResident({
    required String residentUid,
    required String fromScheduleId,
    required String toScheduleId,
    required Map<String, String> residentInfo,
  }) async {
    final batch = _db.batch();
    final from = _db.collection('schedules').doc(fromScheduleId);
    final to = _db.collection('schedules').doc(toScheduleId);

    batch.update(from, {
      'assignedResidents': FieldValue.arrayRemove([residentInfo]),
      'assignedUids': FieldValue.arrayRemove([residentUid]),
      'totalResidents': FieldValue.increment(-1),
      'isManuallyEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(to, {
      'assignedResidents': FieldValue.arrayUnion([residentInfo]),
      'assignedUids': FieldValue.arrayUnion([residentUid]),
      'totalResidents': FieldValue.increment(1),
      'isManuallyEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Swap [residentA] (in [scheduleAId]) with [residentB] (in [scheduleBId]).
  Future<void> swapResidents({
    required String scheduleAId,
    required Map<String, String> residentA,
    required String scheduleBId,
    required Map<String, String> residentB,
  }) async {
    final batch = _db.batch();
    final refA = _db.collection('schedules').doc(scheduleAId);
    final refB = _db.collection('schedules').doc(scheduleBId);
    final now = FieldValue.serverTimestamp();

    // Remove each from their current schedule
    batch.update(refA, {
      'assignedResidents': FieldValue.arrayRemove([residentA]),
      'assignedUids': FieldValue.arrayRemove([residentA['uid']]),
      'isManuallyEdited': true,
      'updatedAt': now,
    });
    batch.update(refB, {
      'assignedResidents': FieldValue.arrayRemove([residentB]),
      'assignedUids': FieldValue.arrayRemove([residentB['uid']]),
      'isManuallyEdited': true,
      'updatedAt': now,
    });
    // Add each to the other's schedule
    batch.update(refA, {
      'assignedResidents': FieldValue.arrayUnion([residentB]),
      'assignedUids': FieldValue.arrayUnion([residentB['uid']]),
    });
    batch.update(refB, {
      'assignedResidents': FieldValue.arrayUnion([residentA]),
      'assignedUids': FieldValue.arrayUnion([residentA['uid']]),
    });

    await batch.commit();
  }

  /// Add a resident to a schedule (e.g. to fill a gap).
  Future<void> addResident({
    required String scheduleId,
    required Map<String, String> residentInfo,
  }) async {
    await _db.collection('schedules').doc(scheduleId).update({
      'assignedResidents': FieldValue.arrayUnion([residentInfo]),
      'assignedUids': FieldValue.arrayUnion([residentInfo['uid']!]),
      'totalResidents': FieldValue.increment(1),
      'isManuallyEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a resident from a schedule.
  Future<void> removeResident({
    required String scheduleId,
    required String residentUid,
    required Map<String, String> residentInfo,
  }) async {
    await _db.collection('schedules').doc(scheduleId).update({
      'assignedResidents': FieldValue.arrayRemove([residentInfo]),
      'assignedUids': FieldValue.arrayRemove([residentUid]),
      'totalResidents': FieldValue.increment(-1),
      'isManuallyEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of all schedule docs for the given Friday (real-time updates).
  Stream<QuerySnapshot> scheduleStreamForFriday(DateTime friday) {
    final start = DateTime(friday.year, friday.month, friday.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection('schedules')
        .where('category', isEqualTo: 'campus_work')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledAt')
        .snapshots();
  }
}
