import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dorm_app/screens/floorleader/floorleader_manage_resident.dart';
import 'package:dorm_app/screens/floorleader/floorleader_schedule_management.dart';
import 'package:dorm_app/screens/floorleader/floorleader_proof_review_screen.dart';
import 'package:dorm_app/screens/floorleader/floorleader_inventory_management_screen.dart';
import 'package:dorm_app/screens/floorleader/floorleader_profile_screen.dart';
import 'package:dorm_app/screens/floorleader/floorleader_duty_reports_screen.dart';
import 'package:dorm_app/providers/auth_provider.dart' as app_auth;
import 'package:provider/provider.dart';

class FloorLeaderDashboard extends StatefulWidget {
  const FloorLeaderDashboard({super.key});

  @override
  State<FloorLeaderDashboard> createState() =>
      _FloorLeaderDashboardScreenState();
}

class _FloorLeaderDashboardScreenState extends State<FloorLeaderDashboard> {
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
                          _buildDutyOverviewSection(),
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

  // ── Header Card ──
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
              const CircleAvatar(
                radius: 26,
                backgroundImage: AssetImage("assets/images/profile.jpg"),
                backgroundColor: Color(0xFFE0E0E0),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FLOOR LEADER • FLOOR ${data['floorId'] ?? '1'}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['name'] ?? 'Pcunk',
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

  // ── Duty Overview Section ──
  // Counts total scheduled tasks per category across ALL schedules.
  Widget _buildDutyOverviewSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Count tasks per category
        int workCount = 0;
        int roomCount = 0;

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final category = d['category']?.toString() ?? 'campus_work';
          if (category == 'campus_work') {
            workCount++;
          } else if (category == 'room_cleaning') {
            roomCount++;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Duty Overview",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDutyCard(
                    icon: Icons.school_outlined,
                    label: "WORK DUTY",
                    count: workCount,
                    color: const Color(0xFF3D5AFE),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildDutyCard(
                    icon: Icons.cleaning_services_outlined,
                    label: "ROOM CLEANING",
                    count: roomCount,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDutyCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
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
            '$count',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            'schedules',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
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
            MaterialPageRoute(builder: (_) => const ManageResidentsScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.calendar_month_outlined,
        label: "Duty\nSchedules",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScheduleManagementScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.task_alt_outlined,
        label: "Proof\nReview",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DutyProofReviewScreen()),
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
              builder: (_) => const InventoryManagementScreen(),
            ),
          );
        },
      ),
      _MenuItem(
        icon: Icons.bar_chart_outlined,
        label: "Duty\nReports",
        badge: 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DutyReportsScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.campaign_outlined,
        label: "Announce-\nments",
        badge: 0,
        onTap: () {},
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
            MaterialPageRoute(builder: (_) => const FloorLeaderProfileScreen()),
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
