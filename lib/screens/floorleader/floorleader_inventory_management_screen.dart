import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/inventory_item.dart';
import '../../models/user_role.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<InventoryItem>> _inventoryStream() {
    return FirebaseFirestore.instance
        .collection('inventory')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => InventoryItem.fromMap(d.data(), d.id))
                  .toList(),
        );
  }

  IconData _iconFor(InventoryCategory cat) {
    switch (cat.name) {
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'equipment':
        return Icons.build_outlined;
      case 'furniture':
        return Icons.chair_outlined;
      case 'electronics':
        return Icons.devices_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Future<void> _updateQty(InventoryItem item, int delta) async {
    final newQty = (item.quantity + delta).clamp(0, 99999);
    await FirebaseFirestore.instance
        .collection('inventory')
        .doc(item.id)
        .update({
          'quantity': newQty,
          'updatedAt': Timestamp.now(),
          'updatedBy': _currentUid ?? '',
        });
  }

  Future<void> _deleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this item?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('inventory').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted')),
        );
      }
    }
  }

  void _showItemDialog({InventoryItem? item}) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(text: item?.quantity.toString() ?? '0');
    final minQtyCtrl = TextEditingController(text: item?.minimumQuantity.toString() ?? '0');
    final unitCtrl = TextEditingController(text: item?.unit ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    InventoryCategory selectedCat = item?.category ?? InventoryCategory.cleaning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setState2) => Container(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isEdit ? 'Edit Item' : 'Add New Item',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _field(
                          nameCtrl,
                          'Item Name',
                          Icons.inventory_2_outlined,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                qtyCtrl,
                                'Quantity',
                                Icons.numbers,
                                inputType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                minQtyCtrl,
                                'Min Qty',
                                Icons.warning_amber_outlined,
                                inputType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                unitCtrl,
                                'Unit (pcs, box, etc)',
                                Icons.straighten,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _field(
                          descCtrl,
                          'Description (optional)',
                          Icons.description_outlined,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<InventoryCategory>(
                          value: selectedCat,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            filled: true,
                            fillColor: const Color(0xFFF4F6F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items:
                              InventoryCategory.values
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState2(() => selectedCat = v!),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A4FD6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final data = {
                                'name': nameCtrl.text.trim(),
                                'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                                'minimumQuantity':
                                    int.tryParse(minQtyCtrl.text) ?? 0,
                                'unit':
                                    unitCtrl.text.trim().isEmpty
                                        ? null
                                        : unitCtrl.text.trim(),
                                'description':
                                    descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                'category': selectedCat.name,
                                'floorId': item?.floorId,
                                'updatedAt': Timestamp.now(),
                                'updatedBy': _currentUid ?? '',
                              };

                              if (isEdit) {
                                await FirebaseFirestore.instance
                                    .collection('inventory')
                                    .doc(item.id)
                                    .update(data);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('inventory')
                                    .add(data);
                              }

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEdit ? 'Item updated' : 'Item added'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            child: Text(
                              isEdit ? 'Save Changes' : 'Add Item',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF4F6F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Stock & Inventory'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _inventoryStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items =
                    snapshot.data!
                        .where(
                          (i) => i.name.toLowerCase().contains(_searchQuery),
                        )
                        .toList();

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No items yet. Tap + to add one.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildItemCard(items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    Color statusColor;
    if (item.isEmpty) {
      statusColor = Colors.red;
    } else if (item.isLow) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border:
            item.isEmpty
                ? Border.all(color: Colors.red.shade200)
                : item.isLow
                ? Border.all(color: Colors.orange.shade200)
                : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(item.category), color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${item.quantity} ${item.unit ?? 'units'} • min: ${item.minimumQuantity}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // Action controls
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                onPressed: () => _showItemDialog(item: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _deleteItem(item.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
