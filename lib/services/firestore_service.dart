import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/inventory_item.dart';
import '../models/duty_proof_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<UserModel>> residentsStream({dynamic floorId}) {
    Query query = _db
        .collection('users')
        .where('role', isEqualTo: 'resident');
    if (floorId != null) {
      query = query.where('floor', isEqualTo: floorId);
    }
    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map(
                (d) => UserModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList(),
    );
  }

  Stream<List<UserModel>> allUsersStream() {
    return _db.collection('users').snapshots().map(
      (snap) =>
          snap.docs
              .map(
                (d) => UserModel.fromMap(
                  d.data(),
                  d.id,
                ),
              )
              .toList(),
    );
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).update(data);
  }

  Future<void> addUserDoc(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).set(data);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<int> countResidents() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .get();
    return snap.docs.length;
  }


  Future<void> setData({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(collection).doc(docId).set(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getData({
    required String collection,
    required String docId,
  }) async {
    return await _db.collection(collection).doc(docId).get();
  }

  // ═══════════════════════════════════════════
  // INVENTORY
  // ═══════════════════════════════════════════

  Stream<List<InventoryItem>> inventoryStream({String? floorId}) {
    Query query = _db.collection('inventory');
    if (floorId != null) {
      query = query.where('floorId', isEqualTo: floorId);
    }
    return query.orderBy('name').snapshots().map(
      (snap) =>
          snap.docs
              .map(
                (d) => InventoryItem.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList(),
    );
  }

  Future<void> addInventoryItem(Map<String, dynamic> data) {
    return _db.collection('inventory').add(data);
  }

  Future<void> updateInventoryQuantity(
    String itemId,
    int newQty,
    String updatedBy,
  ) {
    return _db.collection('inventory').doc(itemId).update({
      'quantity': newQty,
      'updatedAt': Timestamp.now(),
      'updatedBy': updatedBy,
    });
  }

  Future<void> deleteInventoryItem(String itemId) {
    return _db.collection('inventory').doc(itemId).delete();
  }

  Future<int> countLowStockItems() async {
    final snap = await _db.collection('inventory').get();
    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final qty = (data['quantity'] as int?) ?? 0;
      final min = (data['minimumQuantity'] as int?) ?? 0;
      if (qty <= min) count++;
    }
    return count;
  }

  // ═══════════════════════════════════════════
  // SCHEDULES
  // ═══════════════════════════════════════════

  Future<int> countTodaySchedules() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _db
        .collection('schedules')
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.length;
  }

  // ═══════════════════════════════════════════
  // DUTY PROOFS
  // ═══════════════════════════════════════════

  Stream<List<DutyProofModel>> dutyProofsStream({
    String? floorId,
    String? status,
  }) {
    Query query = _db.collection('duty_proofs');
    if (floorId != null) {
      query = query.where('floorId', isEqualTo: floorId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.orderBy('submittedAt', descending: true).snapshots().map(
      (snap) =>
          snap.docs
              .map(
                (d) => DutyProofModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList(),
    );
  }

  Future<void> submitDutyProof(Map<String, dynamic> data) {
    return _db.collection('duty_proofs').add(data);
  }

  Future<void> updateDutyProofStatus(
    String proofId,
    DutyProofStatus status,
  ) {
    return _db.collection('duty_proofs').doc(proofId).update({
      'status': status.name,
    });
  }
}
