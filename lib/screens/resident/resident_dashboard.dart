import 'package:dorm_app/screens/resident/resident_profile_screen.dart';
import 'package:dorm_app/screens/resident/resident_inventory_screen.dart';
import 'package:dorm_app/widgets/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resident_schedule_screen.dart';
import 'resident_task_detail_screen.dart';
import 'resident_notifications_screen.dart';
import 'package:dorm_app/models/schedule_model.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({super.key});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user found")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("User data not found")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          bottomNavigationBar: _buildBottomNav(),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeContent(data),
              const FullScheduleScreen(),
              const DormInventoryScreen(),
              const ProfileScreen(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeContent(Map<String, dynamic> data) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(data),
              const SizedBox(height: 32),
              const Text(
                "Campus Responsibilities",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildCampusWorkDutyCard(),
              // Daily Duty section — title lives inside _buildRoomCard,
              // so it only appears when a schedule exists
              _buildRoomCard(data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> data) {
    final String floor = data['floorId']?.toString() ?? '1';
    final String name = data['name'] ?? 'Scholar';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage(data['profileImage'] ?? 'assets/images/profile.jpg'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "RESIDENT • FLOOR $floor",
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Hello $name",
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ResidentNotificationsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCampusWorkDutyCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('assignedUids', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        String nextShiftText = "No upcoming shifts";
        bool isActive = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final now = DateTime.now();
          final shifts = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'date': (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'timeStart': data['timeStart'] ?? '',
            };
          }).where((s) => (s['date'] as DateTime).isAfter(now.subtract(const Duration(hours: 24))))
            .toList();

          shifts.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

          if (shifts.isNotEmpty) {
            final nextShift = shifts.first;
            final date = nextShift['date'] as DateTime;
            final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
            final isTomorrow = date.day == now.add(const Duration(days: 1)).day && date.month == now.add(const Duration(days: 1)).month && date.year == now.add(const Duration(days: 1)).year;

            String dateLabel = "${date.month}/${date.day}";
            if (isToday) dateLabel = "Today";
            else if (isTomorrow) dateLabel = "Tomorrow";

            nextShiftText = "Next shift: $dateLabel, ${nextShift['timeStart']}";
            isActive = true;
          }
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.asset(
                  "assets/images/lobbythomashall.jpg",
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: const Color(0xFFE2E8F0),
                    child: const Icon(Icons.apartment, size: 48, color: Colors.white),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Campus Work Duty",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          nextShiftText,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? "SCHEDULED" : "NO SCHEDULE",
                            style: TextStyle(
                              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _currentIndex = 1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            minimumSize: const Size(0, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "View Schedule",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> data) {
    final String floor = data['floorId']?.toString() ?? '1';
    final String room = data['roomNumber']?.toString() ?? '';
    final String genderLabel = (data['gender'] ?? 'WOMEN').toString().toUpperCase();
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // If room is not set, hide entire section
    if (room.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .where('floorId', isEqualTo: floor)
          .where('roomNumber', isEqualTo: room)
          .snapshots(),
      builder: (context, roomSnapshot) {
        final roomResidents = roomSnapshot.data?.docs ?? [];
        final roomResidentUids = roomResidents.take(10).map((d) => d.id).toList();

        final todayNow = DateTime.now();
        final start = DateTime(todayNow.year, todayNow.month, todayNow.day);
        final end = start.add(const Duration(days: 1));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schedules')
              .where('category', isEqualTo: 'room_cleaning')
              .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
              .snapshots(),
          builder: (context, scheduleSnapshot) {
            if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            // Filter schedules to only those matching THIS resident's room
            final allSchedules = scheduleSnapshot.data?.docs ?? [];
            final schedules = allSchedules.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final scheduleRoom = d['roomNumber'] as String? ?? '';
              // If no roomNumber on schedule, fall back to assignedUids
              if (scheduleRoom.isEmpty) {
                final uids = List<String>.from(d['assignedUids'] ?? []);
                return uids.contains(currentUid);
              }
              return scheduleRoom == room;
            }).toList();

            // No schedule for this room today — hide entire section
            if (schedules.isEmpty) return const SizedBox.shrink();

            final scheduleDoc = schedules.first;
            final scheduleId = scheduleDoc.id;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('duty_proofs')
                  .where('scheduleId', isEqualTo: scheduleId)
                  .where('submittedBy', whereIn: roomResidentUids.isNotEmpty ? roomResidentUids : ['none'])
                  .snapshots(),
              builder: (context, proofSnapshot) {
                final Map<String, String> proofStatusByUid = {};
                for (final doc in (proofSnapshot.data?.docs ?? [])) {
                  final d = doc.data() as Map<String, dynamic>;
                  final uid = d['submittedBy'] as String? ?? '';
                  final status = d['status'] as String? ?? 'pending';
                  if (uid.isNotEmpty) proofStatusByUid[uid] = status;
                }

                // Wrap in Column that includes the section header
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      "Daily Duty",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRoomCardContent(
                      floor, room, genderLabel, currentUid,
                      roomResidents, proofStatusByUid, scheduleDoc,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRoomCardContent(
    String floor,
    String room,
    String genderLabel,
    String currentUid,
    List<QueryDocumentSnapshot> residents,
    Map<String, String> proofStatusByUid,
    DocumentSnapshot? schedule,
  ) {
    final int total = residents.isNotEmpty ? residents.length : 1;
    final int approvedCount = proofStatusByUid.values.where((s) => s == 'approved').length;
    final double progress = total > 0 ? approvedCount / total : 0.0;

    final String title = schedule != null
        ? (schedule.data() as Map<String, dynamic>)['zone'] ?? 'Daily Room Cleaning'
        : 'Daily Room Cleaning';

    // Is the current user's proof approved?
    final String myStatus = proofStatusByUid[currentUid] ?? 'none';
    final bool myProofApproved = myStatus == 'approved';
    final bool myProofPending = myStatus == 'pending';
    final bool needsSubmission = schedule != null && myStatus == 'none';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _roomTag("${floor}RD FLOOR - $genderLabel", isPrimary: true),
              const SizedBox(width: 8),
              _roomTag("ROOM $room", isPrimary: false),
            ],
          ),
          const SizedBox(height: 24),

          // ── Progress bar ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Room Cleaning Status",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "$approvedCount/$total approved",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: progress == 1.0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: progress == 1.0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),

          // ── Per-resident checklist ──
          if (residents.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "ROOMMATES",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            ...residents.map((resDoc) {
              final resData = resDoc.data() as Map<String, dynamic>;
              final resName = resData['name'] as String? ?? 'Resident';
              final resUid = resDoc.id;
              final isMe = resUid == currentUid;
              final status = proofStatusByUid[resUid] ?? 'none';

              Color dotColor;
              IconData dotIcon;
              String statusLabel;

              switch (status) {
                case 'approved':
                  dotColor = const Color(0xFF10B981);
                  dotIcon = Icons.check_circle_rounded;
                  statusLabel = 'Approved';
                  break;
                case 'pending':
                  dotColor = const Color(0xFFF59E0B);
                  dotIcon = Icons.hourglass_top_rounded;
                  statusLabel = 'Under Review';
                  break;
                case 'rejected':
                  dotColor = const Color(0xFFEF4444);
                  dotIcon = Icons.cancel_rounded;
                  statusLabel = 'Rejected';
                  break;
                default:
                  dotColor = const Color(0xFFCBD5E1);
                  dotIcon = Icons.radio_button_unchecked;
                  statusLabel = 'Not Submitted';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(dotIcon, color: dotColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMe ? '$resName (You)' : resName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: dotColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: dotColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── Action row ──
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  needsSubmission
                      ? "Pending your submission"
                      : myProofPending
                          ? "Your proof is under review"
                          : myProofApproved
                              ? (progress == 1.0 ? "All set for today! 🎉" : "You're done! Waiting for roommates")
                              : (schedule == null ? "No duty scheduled today" : "Waiting for roommates"),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (needsSubmission)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResidentTaskDetailScreen(
                          shift: ScheduleShift.fromFirestore(schedule!),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    minimumSize: const Size(0, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Submit Proof",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              else if (myProofApproved)
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28)
              else if (myProofPending)
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 26)
              else
                const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 26),
            ],
          ),
        ],
      ),
    );
  }


  // ── Helpers ──────────────────────────────────────────────────────────────
  /// Parse a time string like "07:00 AM" or "14:30" into total minutes since midnight.
  int _parseMinutes(String timeStr) {
    try {
      timeStr = timeStr.trim();
      // Handle AM/PM format
      if (timeStr.toUpperCase().contains('AM') || timeStr.toUpperCase().contains('PM')) {
        final isPm = timeStr.toUpperCase().contains('PM');
        timeStr = timeStr.replaceAll(RegExp(r'[APMapm\s]+'), '');
        final parts = timeStr.split(':');
        int h = int.parse(parts[0]);
        final m = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPm && h != 12) h += 12;
        if (!isPm && h == 12) h = 0;
        return h * 60 + m;
      } else {
        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = parts.length > 1 ? int.parse(parts[1]) : 0;
        return h * 60 + m;
      }
    } catch (_) {
      return 0;
    }
  }

  Widget _buildDailyDutyOverview(Map<String, dynamic> userData) {
    final String floorId = userData['floorId']?.toString() ?? '';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('scheduledAt', isLessThan: Timestamp.fromDate(todayEnd))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // ── Aggregate per category ───────────────────────────────────────
        final Map<String, int> categoryMinutes = {};
        int totalMinutes = 0;

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final category = (d['category'] as String? ?? 'campus_work');
          final timeStart = d['timeStart'] as String? ?? '00:00';
          final timeEnd = d['timeEnd'] as String? ?? '00:00';
          final duration = (_parseMinutes(timeEnd) - _parseMinutes(timeStart)).clamp(0, 1440);

          categoryMinutes[category] = (categoryMinutes[category] ?? 0) + duration;
          totalMinutes += duration;
        }

        // ── Category display config ──────────────────────────────────────
        final categories = [
          {
            'key': 'room_cleaning',
            'label': 'Room Cleaning',
            'icon': Icons.cleaning_services_outlined,
            'color': const Color(0xFF10B981),
            'bgColor': const Color(0xFFD1FAE5),
          },
          {
            'key': 'campus_work',
            'label': 'Campus Work',
            'icon': Icons.school_outlined,
            'color': const Color(0xFF2563EB),
            'bgColor': const Color(0xFFEFF6FF),
          },
        ];

        final hasData = totalMinutes > 0;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Total time banner ────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Duty Time Today',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? '${totalMinutes ~/ 60}h ${totalMinutes % 60}m'
                            : 'No duties scheduled',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (!hasData) ...[
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available_outlined, size: 44, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'All clear for today!',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 28),
                const Text(
                  'BY CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Category rows ────────────────────────────────────
                ...categories.map((cat) {
                  final key = cat['key'] as String;
                  final label = cat['label'] as String;
                  final icon = cat['icon'] as IconData;
                  final color = cat['color'] as Color;
                  final bgColor = cat['bgColor'] as Color;
                  final mins = categoryMinutes[key] ?? 0;
                  final pct = totalMinutes > 0 ? mins / totalMinutes : 0.0;
                  final pctInt = (pct * 100).round();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Text(
                              mins > 0
                                  ? '${mins ~/ 60}h ${mins % 60}m'
                                  : '—',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: mins > 0 ? color : const Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 42,
                              child: Text(
                                '$pctInt%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: mins > 0 ? color : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct.clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _roomTag(String text, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isPrimary ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return CustomBottomNav(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: "Schedule",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: "Inventory",
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
