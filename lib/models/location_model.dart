import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single cleaning duty location with capacity constraints.
class DutyLocation {
  final String id;
  final String name;       // e.g. "Parking Area"
  final String label;      // e.g. "Front Parking Lot"
  final int minPeople;     // minimum residents required
  final int maxPeople;     // maximum residents allowed
  final int order;         // display / assignment order

  const DutyLocation({
    required this.id,
    required this.name,
    required this.label,
    required this.minPeople,
    required this.maxPeople,
    required this.order,
  });

  factory DutyLocation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DutyLocation(
      id: doc.id,
      name: d['name'] ?? '',
      label: d['label'] ?? '',
      minPeople: (d['minPeople'] as num?)?.toInt() ?? 1,
      maxPeople: (d['maxPeople'] as num?)?.toInt() ?? 10,
      order: (d['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'label': label,
        'minPeople': minPeople,
        'maxPeople': maxPeople,
        'order': order,
        'isActive': true,
      };
}
