import 'package:cloud_firestore/cloud_firestore.dart';

/// Seeds the `locations` Firestore collection with the real campus Work Duty areas.
/// Calling seed() always deletes old docs and writes the current list fresh.
class LocationSeederService {
  final FirebaseFirestore _db;

  LocationSeederService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static const _locations = [
    {'name': 'Cafeteria Sweep',        'label': 'Sweep the cafeteria area.',                                                           'min': 1, 'max': 4},
    {'name': 'Cafeteria Mop',          'label': 'Mop the cafeteria floor.',                                                            'min': 1, 'max': 4},
    {'name': 'Cafeteria Tables',       'label': 'Wipe the cafeteria tables and arrange the chairs properly.',                          'min': 1, 'max': 4},
    {'name': 'Kitchen & Trash',        'label': 'Clean the kitchen and dispose of cafeteria trash.',                                   'min': 1, 'max': 4},
    {'name': 'Trash Collection',       'label': 'Collect trash from all areas and dispose of it in the main trash collection area.',   'min': 1, 'max': 4},
    {'name': 'Cafeteria Terrace',      'label': 'Sweep and mop the cafeteria terrace.',                                               'min': 1, 'max': 4},
    {'name': 'Thomas House Hall',      'label': 'Clean the ground hall of Thomas House (beside and in front of the study room).',     'min': 1, 'max': 4},
    {'name': 'Dorm Terrace Sweep',     'label': 'Sweep the dormitory terrace from front to back.',                                    'min': 1, 'max': 4},
    {'name': 'Dorm Terrace Mop',       'label': 'Mop the dormitory terrace from front to back.',                                     'min': 1, 'max': 4},
    {'name': 'Ceilings & Walls',       'label': 'Clean the ceilings and walls.',                                                      'min': 1, 'max': 4},
  ];

  /// Returns true only when the collection already has exactly the expected
  /// number of locations (i.e. this exact version of the list is seeded).
  Future<bool> isSeeded() async {
    final snap = await _db.collection('locations').get();
    return snap.docs.length == _locations.length;
  }

  /// Deletes all existing location docs and writes the current list fresh.
  Future<void> seed() async {
    // 1. Delete all existing location docs
    final existing = await _db.collection('locations').get();
    final deleteBatch = _db.batch();
    for (final doc in existing.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    // 2. Write the new locations
    final batch = _db.batch();
    for (int i = 0; i < _locations.length; i++) {
      final loc = _locations[i];
      final docId = (loc['name'] as String).toLowerCase().replaceAll(' ', '_').replaceAll('&', 'and');
      final ref = _db.collection('locations').doc(docId);
      batch.set(ref, {
        'name': loc['name'],
        'label': loc['label'],
        'minPeople': loc['min'],
        'maxPeople': loc['max'],
        'order': i,
        'isActive': true,
      });
    }
    await batch.commit();
  }
}
