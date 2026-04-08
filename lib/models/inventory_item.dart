import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class InventoryItem {
  final String id;
  final String floorId;
  final String name;
  final InventoryCategory category;
  final int quantity;
  final int minimumQuantity;
  final String? description;
  final String? unit;
  final DateTime updatedAt;
  final String updatedBy;

  const InventoryItem({
    required this.id,
    required this.floorId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minimumQuantity,
    this.description,
    this.unit,
    required this.updatedAt,
    required this.updatedBy,
  });

  bool get isLow => quantity <= minimumQuantity;
  bool get isEmpty => quantity == 0;

  factory InventoryItem.fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryItem(
      id: documentId,
      floorId: map['floorId'] ?? '',
      name: map['name'] ?? '',
      category: InventoryCategory.values.firstWhere(
        (e) => e.name == (map['category'] ?? 'other'),
        orElse: () => InventoryCategory.other,
      ),
      quantity: map['quantity'] ?? 0,
      minimumQuantity: map['minimumQuantity'] ?? 0,
      description: map['description'],
      unit: map['unit'],
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'floorId': floorId,
      'name': name,
      'category': category.name,
      'quantity': quantity,
      'minimumQuantity': minimumQuantity,
      'description': description,
      'unit': unit,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }
}
