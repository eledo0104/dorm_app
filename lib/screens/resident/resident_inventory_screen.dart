import 'package:dorm_app/models/inventory_item.dart';
import 'package:dorm_app/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DormInventoryScreen extends StatefulWidget {
  const DormInventoryScreen({super.key});

  @override
  State<DormInventoryScreen> createState() => _DormInventoryScreenState();
}

class _DormInventoryScreenState extends State<DormInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Firestore stream ──
  Stream<List<InventoryItem>> _inventoryStream() {
    return FirebaseFirestore.instance
        .collection('inventory')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(
                    (d) => InventoryItem.fromMap(
                      // ignore: unnecessary_cast
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList(),
        );
  }

  // ── Icon mapping dari InventoryCategory ──
  IconData _iconFor(InventoryCategory category) {
    final name = category.name;
    switch (name) {
      case 'toiletries':
        return Icons.wash_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'laundry':
        return Icons.local_laundry_service_outlined;
      case 'trash':
        return Icons.delete_outline;
      case 'kitchen':
        return Icons.kitchen_outlined;
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

  // ── Quantity label pakai unit dari model ──
  String _quantityLabel(InventoryItem item) {
    final unitLabel = item.unit ?? 'Units';
    return '${item.quantity} $unitLabel';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              // ── Title ──
              const Text(
                "Dorm Inventory",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Check essential supplies availability",
                style: TextStyle(fontSize: 14, color: Color(0xFF8A9BB5)),
              ),
              const SizedBox(height: 24),

              // ── Search bar ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged:
                      (val) => setState(() => _searchQuery = val.toLowerCase()),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF0D1B3E),
                  ),
                  decoration: InputDecoration(
                    hintText: "Search items",
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── List ──
              Expanded(
                child: StreamBuilder<List<InventoryItem>>(
                  stream: _inventoryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items =
                        (snapshot.data ?? [])
                            .where(
                              (item) => item.name.toLowerCase().contains(
                                _searchQuery,
                              ),
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
                              _searchQuery.isEmpty
                                  ? "No items in inventory"
                                  : "No items match \"$_searchQuery\"",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, index) => _buildItemCard(items[index]),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    // Warna quantity: merah kalau empty, orange kalau low, abu kalau normal
    Color quantityColor;
    if (item.isEmpty) {
      quantityColor = Colors.red.shade400;
    } else if (item.isLow) {
      quantityColor = Colors.orange.shade400;
    } else {
      quantityColor = const Color(0xFF8A9BB5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border:
            item.isEmpty
                ? Border.all(color: Colors.red.shade200, width: 1)
                : item.isLow
                ? Border.all(color: Colors.orange.shade200, width: 1)
                : null,
      ),
      child: Row(
        children: [
          // ── Icon box ──
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  item.isEmpty
                      ? Colors.red.shade50
                      : item.isLow
                      ? Colors.orange.shade50
                      : const Color(0xFFE8EEF9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _iconFor(item.category),
              color:
                  item.isEmpty
                      ? Colors.red.shade400
                      : item.isLow
                      ? Colors.orange.shade400
                      : const Color(0xFF1A6DD4),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),

          // ── Name + description ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B3E),
                  ),
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A9BB5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Quantity ──
          Text(
            _quantityLabel(item),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: quantityColor,
            ),
          ),
        ],
      ),
    );
  }
}
