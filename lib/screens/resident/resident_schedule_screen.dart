import 'package:dorm_app/models/schedule_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dorm_app/services/schedule_generator_service.dart';
import 'package:dorm_app/screens/resident/resident_task_detail_screen.dart';

class FullScheduleScreen extends StatefulWidget {
  const FullScheduleScreen({super.key});

  @override
  State<FullScheduleScreen> createState() => _FullScheduleScreenState();
}

class _FullScheduleScreenState extends State<FullScheduleScreen> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  bool _myDutiesOnly = false;
  bool _isSearching = false;
  String _searchQuery = "";

  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;
  String? _currentUserRoom; // resident's own room number

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekStart = _mondayOf(_selectedDate);
    _loadCurrentUserRoom();
  }

  Future<void> _loadCurrentUserRoom() async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _currentUserRoom = data['roomNumber']?.toString();
        });
      }
    } catch (_) {}
  }

  DateTime _mondayOf(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  // ── Firestore stream filtered by selected date and category ──
  Stream<List<ScheduleShift>> _shiftsStream(String category) {
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));

    Query query = FirebaseFirestore.instance
        .collection('schedules')
        .where('category', isEqualTo: category)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledAt');

    return query.snapshots().map((snap) {
      var shifts =
          snap.docs.map((d) => ScheduleShift.fromFirestore(d)).toList();

      // 🔒 Room cleaning: only show schedules for THIS resident's room
      if (category == 'room_cleaning') {
        final myRoom = _currentUserRoom;
        shifts = shifts.where((s) {
          final scheduleRoom = s.roomNumber; // new field on model
          // If schedule has no roomNumber, fall back to assigned-uid check
          if (scheduleRoom == null || scheduleRoom.isEmpty) {
            return s.assignedUids.contains(_currentUid);
          }
          return scheduleRoom == myRoom;
        }).toList();
      }

      if (_myDutiesOnly && _currentUid != null) {
        shifts = shifts
            .where((s) => s.assignedUids.contains(_currentUid))
            .toList();
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        shifts = shifts.where((s) =>
          s.shiftLabel.toLowerCase().contains(q) ||
          s.location.toLowerCase().contains(q) ||
          s.zoneType.toLowerCase().contains(q)
        ).toList();
      }

      return shifts;
    });
  }

  // ── Week days for the header calendar ──
  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  // ── Day label ──
  String _dayLabel(int weekday) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[weekday - 1];
  }

  // ── Month label ──
  String _monthLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[d.month - 1];
  }

  // ── Full day header e.g. "Tuesday, Sep 12" ──
  String _fullDayLabel(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${_monthLabel(d)} ${d.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildPersonalAssignmentBanner(),
              _buildCalendarStrip(),
              _buildMyDutiesToggle(),
              const TabBar(
                indicatorColor: Color(0xFF2196F3),
                labelColor: Color(0xFF2196F3),
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(icon: Icon(Icons.school_outlined, size: 20), text: "Work Duty"),
                  Tab(icon: Icon(Icons.cleaning_services_outlined, size: 20), text: "Room Cleaning"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildShiftListView('campus_work'),
                    _buildShiftListView('room_cleaning'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftListView(String category) {
    return StreamBuilder<List<ScheduleShift>>(
      stream: _shiftsStream(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final shifts = snapshot.data ?? [];
        if (shifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  "No shifts found in this category",
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildDayHeader(),
            const SizedBox(height: 12),
            ...shifts.map((s) => _buildShiftCard(s)),
          ],
        );
      },
    );
  }

  // ── App Bar ──
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: _isSearching
          ? Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by shift, location, zone...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 26),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                ),
              ],
            )
          : Row(
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 28),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                const Expanded(
                  child: Text(
                    "Work Duty Schedule",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, size: 26),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
              ],
            ),
    );
  }

  // ── Horizontal calendar strip ──
  Widget _buildCalendarStrip() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _weekDays.length,
        itemBuilder: (context, i) {
          final day = _weekDays[i];
          final isSelected = _isSameDay(day, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = day),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF2196F3) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayLabel(day.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── My Duties toggle card ──
  Widget _buildMyDutiesToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.grey.withOpacity(0.08),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_alt_outlined,
              size: 20,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Duties",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Show only shifts assigned to me",
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          Switch(
            value: _myDutiesOnly,
            activeColor: const Color(0xFF2196F3),
            onChanged:
                (val) => setState(() {
                  _myDutiesOnly = val;
                }),
          ),
        ],
      ),
    );
  }

  // ── Day header e.g. "📅 Tuesday, Sep 12" ──
  Widget _buildDayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF2196F3), size: 22),
          const SizedBox(width: 8),
          Text(
            _fullDayLabel(_selectedDate),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shift card ──
  Widget _buildShiftCard(ScheduleShift shift) {
    final isAssignedToMe =
        _currentUid != null && shift.assignedUids.contains(_currentUid);
    final zoneColor = _zoneColor(shift.zoneType);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.grey.withOpacity(0.10),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image banner ──
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                // Background image
                Image.asset(
                  _zoneImage(shift.zoneType),
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        height: 130,
                        color: const Color(0xFF455A64),
                      ),
                ),
                // Dark overlay
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
                // Top badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: _zoneBadge(shift.zone, zoneColor),
                ),
                if (isAssignedToMe)
                  Positioned(top: 12, right: 12, child: _assignedBadge()),
                // Bottom info
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.shiftLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              shift.location,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _timeBadge('${shift.timeStart} - ${shift.timeEnd}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Residents section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              "ASSIGNED RESIDENTS (${shift.assignedResidents.length})",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _buildResidentAvatars(shift.assignedResidents),
          ),

          // ── View My Tasks button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResidentTaskDetailScreen(shift: shift),
                    ),
                  );
                },
                icon: const Icon(Icons.tune, size: 18),
                label: const Text(
                  "View Task Details",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Resident avatar row ──
  Widget _buildResidentAvatars(List<Map<String, String>> residents) {
    const maxVisible = 4;
    final visible = residents.take(maxVisible).toList();
    final extra = residents.length - maxVisible;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visible.map((r) => _residentChip(r)),
        if (extra > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "+$extra",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _residentChip(Map<String, String> resident) {
    final name = resident['name'] ?? '';
    final avatarUrl = resident['avatarUrl'] ?? '';
    final isMe = resident['isMe'] == 'true';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey.shade300,
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child:
                avatarUrl.isEmpty
                    ? Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 6),
          Text(
            isMe ? '$name (You)' : name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isMe ? Colors.blue.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge helpers ──
  Widget _zoneBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _assignedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "ASSIGNED TO YOU",
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _timeBadge(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        time,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Personal assignment banner ──
  Widget _buildPersonalAssignmentBanner() {
    if (_currentUid == null) return const SizedBox.shrink();
    final friday = ScheduleGeneratorService.nextFriday();
    final start = DateTime(friday.year, friday.month, friday.day);
    final end = start.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('category', isEqualTo: 'campus_work')
          .where('assignedUids', arrayContains: _currentUid)
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final doc = snap.data!.docs.first;
        final d = doc.data() as Map<String, dynamic>;
        final zone = d['zone'] as String? ?? '';
        final location = d['location'] as String? ?? '';
        final timeStart = d['timeStart'] as String? ?? '07:00 AM';
        final timeEnd = d['timeEnd'] as String? ?? '09:00 AM';
        final total = (d['totalResidents'] as num?)?.toInt() ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResidentTaskDetailScreen(
                  shift: ScheduleShift.fromFirestore(doc),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B4EE6), Color(0xFF3D5AFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3D5AFE).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cleaning_services,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Duty This Friday',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        zone,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$location  •  $timeStart – $timeEnd  •  $total people',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Zone helpers ──
  Color _zoneColor(String zoneType) {
    final z = zoneType.toUpperCase();
    if (z.contains('KITCHEN') || z.contains('CAFETERIA') || z.contains('FOOD')) {
      return const Color(0xFFFF7043);
    }
    if (z.contains('GARDEN') || z.contains('OUTDOOR') || z.contains('COURT') ||
        z.contains('ROOFTOP') || z.contains('PATH') || z.contains('GATE')) {
      return const Color(0xFF66BB6A);
    }
    if (z.contains('RESTROOM') || z.contains('TRASH') || z.contains('LAUNDRY')) {
      return const Color(0xFFAB47BC);
    }
    if (z.contains('STAIRCASE') || z.contains('FIRE') || z.contains('EXIT')) {
      return const Color(0xFFEF5350);
    }
    return const Color(0xFF78909C);
  }

  String _zoneImage(String zoneType) {
    final z = zoneType.toUpperCase();
    if (z.contains('FOOD') || z.contains('KITCHEN')) {
      return 'assets/images/kitchen.jpg';
    }
    if (z.contains('CAFETERIA')) {
      return 'assets/images/cafetaria.jpg';
    }
    if (z.contains('COMMUNAL') || z.contains('LOUNGE')) {
      return 'assets/images/lounge.jpg';
    }
    if (z.contains('LOBBY')) {
      return 'assets/images/lobbythomashall.jpg';
    }
    if (z.contains('STUDY')) {
      return 'assets/images/studyroom.jpg';
    }
    if (z.contains('LAUNDRY')) {
      return 'assets/images/dormlaundry.jpg';
    }
    if (z.contains('OUTDOOR') || z.contains('GARDEN')) {
      return 'assets/images/outdoor.jpg';
    }
    if (z.contains('ROOM')) {
      return 'assets/images/dorm4.jpg';
    }
    return 'assets/images/campus.jpg';
  }
}
