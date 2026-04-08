import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/inventory_item.dart';
import '../../models/user_role.dart';

class AdminCheckInventoryScreen extends StatefulWidget {
  const AdminCheckInventoryScreen({super.key});

  @override
  State<AdminCheckInventoryScreen> createState() =>
      _AdminCheckInventoryScreenState();
}

class _AdminCheckInventoryScreenState
    extends State<AdminCheckInventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
        title: const Text('Check Inventory'),
        backgroundColor: const Color(0xFF1A4FD6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stats summary
          StreamBuilder<List<InventoryItem>>(
            stream: _inventoryStream(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final lowStock = items.where((i) => i.isLow && !i.isEmpty).length;
              final outOfStock = items.where((i) => i.isEmpty).length;

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A4FD6), Color(0xFF2F6FED)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _summaryTile('Total', '${items.length}', Icons.inventory_2),
                    _verticalDivider(),
                    _summaryTile('Low Stock', '$lowStock', Icons.warning_amber),
                    _verticalDivider(),
                    _summaryTile('Out of Stock', '$outOfStock', Icons.remove_circle_outline),
                  ],
                ),
              );
            },
          ),

          // Search bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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

          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _inventoryStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!
                    .where((i) => i.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No items found', style: TextStyle(color: Colors.grey.shade400)),
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

  Widget _summaryTile(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 50, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8));
  }

  Widget _buildItemCard(InventoryItem item) {
    Color statusColor;
    String statusLabel;

    if (item.isEmpty) {
      statusColor = Colors.red;
      statusLabel = 'OUT OF STOCK';
    } else if (item.isLow) {
      statusColor = Colors.orange;
      statusLabel = 'LOW STOCK';
    } else {
      statusColor = Colors.green;
      statusLabel = 'IN STOCK';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
        border: item.isEmpty
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
            child: Icon(_iconFor(item.category), color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} ${item.unit ?? 'units'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
