import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:dorm_app/providers/auth_provider.dart' as app_auth;
import 'admin_manage_residents_screen.dart';
import 'admin_oversee_duty_screen.dart';
import 'admin_check_inventory_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_weekly_reports_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child:
            user == null
                ? const Center(child: Text("No user found"))
                : StreamBuilder<DocumentSnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text("User data not found"));
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(data),
                          const SizedBox(height: 28),
                          _buildOverviewSection(),
                          const SizedBox(height: 28),
                          _buildManagementMenu(context),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }

  // ── Header Card (same style as floor leader) ──
  Widget _buildHeaderCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.grey.withOpacity(0.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE0E0E0),
                backgroundImage: data['photoUrl'] != null
                    ? NetworkImage(data['photoUrl'])
                    : null,
                child: data['photoUrl'] == null
                    ? const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28)
                    : null,
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DORMITORY ADMIN",
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['name'] ?? 'Administrator',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 22,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Overview Section (same layout as floor leader duty overview) ──
  Widget _buildOverviewSection() {
    return FutureBuilder<List<int>>(
      future: Future.wait([_countResidents(), _counttodaySchedules(), _countLowStock()]),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? [0, 0, 0];
        return Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Overview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.people_outlined,
                    label: "RESIDENTS",
                    value: "${counts[0]}",
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.calendar_today_outlined,
                    label: "TODAY'S DUTIES",
                    value: "${counts[1]}",
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<int> _countResidents() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .get();
    return snap.docs.length;
  }

  Future<int> _counttodaySchedules() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final snap = await FirebaseFirestore.instance
        .collection('schedules')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.length;
  }

  Future<int> _countLowStock() async {
    final snap = await FirebaseFirestore.instance.collection('inventory').get();
    int count = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      final qty = (d['quantity'] as int?) ?? 0;
      final min = (d['minimumQuantity'] as int?) ?? 0;
      if (qty <= min) count++;
    }
    return count;
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.grey.withOpacity(0.07),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF3D5AFE), size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black45,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Management Menu ──
  Widget _buildManagementMenu(BuildContext context) {
    final List<_MenuItem> items = [
      _MenuItem(
        icon: Icons.person_add_outlined,
        label: "Manage\nResidents",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminManageResidentsScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.calendar_month_outlined,
        label: "Oversee\nDuty",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminOverseeDutyScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.task_alt_outlined,
        label: "Proof\nReview",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminOverseeDutyScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.inventory_2_outlined,
        label: "Stock &\nInventory",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminCheckInventoryScreen(),
            ),
          );
        },
      ),
      _MenuItem(
        icon: Icons.bar_chart_outlined,
        label: "Weekly\nReports",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminWeeklyReportsScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.settings_outlined,
        label: "Settings",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Management Menu",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.0,
          children: items.map((item) => _buildMenuTile(item)).toList(),
        ),
      ],
    );
  }

  Widget _buildMenuTile(_MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.grey.withOpacity(0.07),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      color: const Color(0xFF3D5AFE),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Badge
            if (item.badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${item.badge}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ──
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
          );
          return;
        }
        setState(() => _currentIndex = index);
      },
      iconSize: 24,
      selectedIconTheme: const IconThemeData(size: 24),
      unselectedIconTheme: const IconThemeData(size: 24),
      selectedItemColor: const Color(0xFF2196F3),
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 10,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
    );
  }
}

// ── Helper class ──
class _MenuItem {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
  });
}
