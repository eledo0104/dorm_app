import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dorm_app/screens/floorleader/floorleader_generate_schedule_screen.dart';

class ScheduleTask {
  final String id;
  final String zone;
  final String title;
  final String category; // 'campus_work' or 'room_cleaning'
  final DateTime scheduledAt;
  final List<Map<String, String>> assignedResidents;
  final List<String> assignedUids;
  final int totalResidents;
  final String? roomNumber; // for room_cleaning schedules only

  ScheduleTask({
    required this.id,
    required this.zone,
    required this.title,
    required this.category,
    required this.scheduledAt,
    required this.assignedResidents,
    required this.assignedUids,
    required this.totalResidents,
    this.roomNumber,
  });

  factory ScheduleTask.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final residents = (d['assignedResidents'] as List<dynamic>? ?? [])
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final url = m['photoUrl'] ?? m['avatarUrl'] ?? '';
          return {
            'uid': m['uid']?.toString() ?? '',
            'name': m['name']?.toString() ?? '',
            'photoUrl': url.toString(),
            'avatarUrl': url.toString(),
          };
        })
        .toList();
    return ScheduleTask(
      id: doc.id,
      zone: d['zone'] ?? '',
      title: d['title'] ?? '',
      category: d['category'] ?? 'campus_work',
      scheduledAt: (d['scheduledAt'] as Timestamp).toDate(),
      assignedResidents: residents,
      assignedUids: List<String>.from(d['assignedUids'] ?? []),
      totalResidents: d['totalResidents'] ?? residents.length,
      roomNumber: d['roomNumber'] as String?,
    );
  }

  String get timeLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    final diff = taskDay.difference(today).inDays;
    final hour = scheduledAt.hour;
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$h:$minute $period';
    if (diff == 0) return 'Today • $timeStr';
    if (diff == 1) return 'Tomorrow • $timeStr';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[scheduledAt.weekday - 1]} • $timeStr';
  }
}


class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String get _weekLabel {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[monday.month - 1]} ${monday.day} – ${months[sunday.month - 1]} ${sunday.day}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<ScheduleTask>> _tasksStream(String category) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    return FirebaseFirestore.instance
        .collection('schedules')
        .where('category', isEqualTo: category)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ScheduleTask.fromFirestore(d)).toList());
  }

  // ── One-click auto-create up to 20 campus work schedules ──
  Future<void> _autoCreateCampusSchedules() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Create Schedules',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Create schedules for the next 4 weeks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D5AFE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Fetch floor residents to auto-assign
    final uid = FirebaseAuth.instance.currentUser?.uid;
    List<Map<String, String>> residents = [];
    List<String> residentUids = [];

    if (uid != null) {
      final leaderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final leaderData = leaderDoc.data() as Map<String, dynamic>?;
      final floorVal = leaderData?['floor'];

      if (floorVal != null) {
        final resSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'resident')
            .where('floor', isEqualTo: floorVal)
            .get();
        for (final doc in resSnap.docs) {
          final d = doc.data();
          residents.add({'name': d['name'] ?? '', 'uid': doc.id, 'avatarUrl': ''});
          residentUids.add(doc.id);
        }
      }
    }

    final zones = [
      'Food Prep Zone',
      'Communal Zone',
      'Outdoor Zone',
      'Lobby',
      'Staircase',
    ];
    final shifts = [
      {'label': 'Morning Shift', 'start': '08:00 AM', 'end': '09:30 AM', 'hour': 8},
      {'label': 'Afternoon Shift', 'start': '01:00 PM', 'end': '02:30 PM', 'hour': 13},
      {'label': 'Evening Shift', 'start': '05:00 PM', 'end': '06:30 PM', 'hour': 17},
    ];

    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();
    int createdCount = 0;

    for (int week = 0; week < 4 && createdCount < 20; week++) {
      for (int day = 0; day < 5 && createdCount < 20; day++) {
        // Mon–Fri, skip past days in first week
        final date = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
            .add(Duration(days: week * 7 + day));
        if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) continue;

        final shift = shifts[createdCount % shifts.length];
        final zone = zones[createdCount % zones.length];
        final shiftHour = shift['hour'] as int;
        final scheduledAt = DateTime(date.year, date.month, date.day, shiftHour, 0);

        final ref = FirebaseFirestore.instance.collection('schedules').doc();
        batch.set(ref, {
          'category': 'campus_work',
          'zone': zone,
          'zoneType': zone.toUpperCase(),
          'title': '${shift['label']} – $zone',
          'shiftLabel': shift['label'],
          'location': zone,
          'timeStart': shift['start'],
          'timeEnd': shift['end'],
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
          'assignedResidents': residents,
          'assignedUids': residentUids,
          'totalResidents': residents.length,
          'createdAt': FieldValue.serverTimestamp(),
        });
        createdCount++;
      }
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Created $createdCount work duty schedules!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onAddTask(String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF3D5AFE),
              labelColor: const Color(0xFF3D5AFE),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(
                  icon: Icon(Icons.school_outlined),
                  text: 'Work Duty',
                ),
                Tab(
                  icon: Icon(Icons.cleaning_services_outlined),
                  text: 'Room Cleaning',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoryTab('campus_work'),
                  _buildCategoryTab('room_cleaning'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28, color: Colors.black87),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              "Duty Schedules",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String category) {
    final isCampus = category == 'campus_work';
    final color = isCampus ? const Color(0xFF3D5AFE) : Colors.green.shade600;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Auto-create card — only for campus_work
          if (isCampus)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateScheduleScreen(),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B4EE6), Color(0xFF3D5AFE)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Work Duty Schedules',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),

          if (isCampus) const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCampus ? 'Work Duties' : 'Room Cleaning Duties',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _weekLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              // Add button
              GestureDetector(
                onTap: () => _onAddTask(category),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTaskList(category),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTaskList(String category) {
    return StreamBuilder<List<ScheduleTask>>(
      stream: _tasksStream(category),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                   const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                   const SizedBox(height: 12),
                   Text(
                     "Error loading schedules:\n${snapshot.error}",
                     textAlign: TextAlign.center,
                     style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                   ),
                   const SizedBox(height: 12),
                   const Text(
                     "This might be due to a missing Firestore index.",
                     style: TextStyle(color: Colors.grey, fontSize: 12),
                   ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    "No schedules this week.\nTap + or Auto-Create.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "(The view is currently filtered to this week only)",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: tasks
              .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildTaskCard(t),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildTaskCard(ScheduleTask task) {
    final isCampus = task.category == 'campus_work';
    final color = isCampus ? const Color(0xFF3D5AFE) : Colors.green.shade600;
    const maxAvatars = 4;
    final visible = task.assignedResidents.take(maxAvatars).toList();
    final extra = task.totalResidents - maxAvatars;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.zone.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _onEditTask(task),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_outlined, size: 16, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(task.timeLabel,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 36,
                width: visible.length * 26.0 + (extra > 0 ? 36 : 0),
                child: Stack(
                  children: [
                    ...visible.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      final photoUrl = r['photoUrl'] ?? '';
                      final name = r['name'] ?? '';
                      return Positioned(
                        left: i * 26.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                    if (extra > 0)
                      Positioned(
                        left: visible.length * 26.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFE8EEF9),
                            child: Text(
                              '+$extra',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${task.totalResidents} Residents",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onEditTask(ScheduleTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTaskSheet(task: task),
    );
  }
}

// ─────────────────────────────────────────────
//  Add Task Bottom Sheet
// ─────────────────────────────────────────────
class _AddTaskSheet extends StatefulWidget {
  final String category;
  const _AddTaskSheet({required this.category});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  final _zoneController = TextEditingController();
  final _roomController = TextEditingController(); // room number for room_cleaning
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _loading = false;
  List<Map<String, String>> _selectedResidents = [];

  @override
  void dispose() {
    _titleController.dispose();
    _zoneController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _showResidentPicker() async {
    setState(() => _loading = true);
    
    try {
      final resSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .get();

      final allResidents = resSnap.docs.map((doc) {
        final d = doc.data();
        final url = d['photoUrl'] ?? d['avatarUrl'] ?? '';
        return {
          'uid': doc.id,
          'name': d['name']?.toString() ?? 'Unknown',
          'photoUrl': url.toString(),
          'avatarUrl': url.toString(),
          'floor': d['floor']?.toString() ?? '?',
        };
      }).toList();

      if (!mounted) return;
      setState(() => _loading = false);

      await showDialog(
        context: context,
        builder: (ctx) {
          String searchQuery = "";
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final filtered = allResidents.where((r) => 
                r['name']!.toLowerCase().contains(searchQuery.toLowerCase())
              ).toList();

              return AlertDialog(
                title: const Text("Select Residents", style: TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: "Search resident...",
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) {
                          setDialogState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: filtered.isEmpty 
                          ? const Padding(padding: EdgeInsets.all(20), child: Text("No residents found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final r = filtered[i];
                                final isSelected = _selectedResidents.any((sel) => sel['uid'] == r['uid']);
                                final photoUrl = r['photoUrl']!;
                                
                                return CheckboxListTile(
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                    child: photoUrl.isEmpty ? Text(r['name']![0].toUpperCase(), style: const TextStyle(fontSize: 12)) : null,
                                  ),
                                  title: Text(r['name']!),
                                  subtitle: Text("Floor ${r['floor']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      final Map<String, String> clean = {
                                        'uid': r['uid']!.toString(),
                                        'name': r['name']!.toString(),
                                        'photoUrl': r['photoUrl']!.toString(),
                                        'avatarUrl': r['avatarUrl']!.toString(),
                                      };
                                      if (val == true) {
                                        _selectedResidents.add(clean);
                                      } else {
                                        _selectedResidents.removeWhere((sel) => sel['uid'] == r['uid']);
                                      }
                                    });
                                    setState(() {}); // Update the main sheet UI
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done")),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching residents: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    final isRoomCleaning = widget.category == 'room_cleaning';
    // Room number is required for room cleaning
    if (isRoomCleaning && _roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the room number.')),
      );
      return;
    }
    setState(() => _loading = true);
    final scheduledAt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );
    await FirebaseFirestore.instance.collection('schedules').add({
      'category': widget.category,
      'zone': _zoneController.text.trim(),
      'zoneType': isRoomCleaning ? 'ROOM CLEANING' : 'WORK DUTY',
      'title': _titleController.text.trim(),
      'shiftLabel': isRoomCleaning ? 'Cleaning Task' : 'Work Duty',
      'location': _zoneController.text.trim(),
      if (isRoomCleaning) 'roomNumber': _roomController.text.trim(),
      'timeStart': _selectedTime.format(context),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'date': Timestamp.fromDate(DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day)),
      'assignedResidents': _selectedResidents,
      'assignedUids': _selectedResidents.map((r) => r['uid']).toList(),
      'totalResidents': _selectedResidents.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _sheetWrapper(
      title: widget.category == 'campus_work'
          ? "Add Work Duty Schedule"
          : "Add Room Cleaning Schedule",
      context: context,
      child: Column(
        children: [
          _inputField("Task Title", _titleController, Icons.task_outlined),
          const SizedBox(height: 14),
          _inputField("Zone / Location", _zoneController, Icons.location_on_outlined),
          const SizedBox(height: 14),
          // Room number field — only for room_cleaning
          if (widget.category == 'room_cleaning') ...
            [
              _inputField(
                "Room Number (e.g. 301)",
                _roomController,
                Icons.door_front_door_outlined,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 14),
            ],

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: _dateTimeBox(
                    icon: Icons.calendar_today_outlined,
                    label: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: _dateTimeBox(
                    icon: Icons.access_time_outlined,
                    label: _selectedTime.format(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Residents Selection Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Assign Residents (${_selectedResidents.length})",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _showResidentPicker,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text("Add"),
              ),
            ],
          ),

          if (_selectedResidents.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedResidents.map((r) => Chip(
                  label: Text(r['name']!, style: const TextStyle(fontSize: 12)),
                  onDeleted: () {
                    setState(() {
                      _selectedResidents.removeWhere((sel) => sel['uid'] == r['uid']);
                    });
                  },
                  deleteIcon: const Icon(Icons.close, size: 14),
                  padding: const EdgeInsets.all(4),
                  backgroundColor: Colors.blue.shade50,
                )).toList(),
              ),
            ),

          const SizedBox(height: 24),
          _submitButton(label: "Add Schedule", loading: _loading, onTap: _save),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Edit Task Bottom Sheet — full resident management
// ─────────────────────────────────────────────
class _EditTaskSheet extends StatefulWidget {
  final ScheduleTask task;
  const _EditTaskSheet({required this.task});

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  bool _loading = false;
  String? _actionMsg;
  late TextEditingController _titleController;
  late TextEditingController _zoneController;
  late TextEditingController _roomController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _zoneController = TextEditingController(text: widget.task.zone);
    _roomController = TextEditingController(text: widget.task.roomNumber ?? '');
    _selectedDate = widget.task.scheduledAt;
    _selectedTime = TimeOfDay.fromDateTime(widget.task.scheduledAt);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _zoneController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _updateDetails() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final scheduledAt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );
    try {
      await FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.task.id)
          .update({
        'title': _titleController.text.trim(),
        'zone': _zoneController.text.trim(),
        'location': _zoneController.text.trim(),
        if (widget.task.category == 'room_cleaning')
          'roomNumber': _roomController.text.trim(),
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'date': Timestamp.fromDate(DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day)),
        'timeStart': _selectedTime.format(context),
        'isManuallyEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _actionMsg = '✓ Schedule details updated';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionMsg = 'Error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _removeResident(Map<String, String> resident) async {
    setState(() => _loading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('schedules').doc(widget.task.id);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      List<dynamic> residents = List.from(data['assignedResidents'] ?? []);
      List<dynamic> uids = List.from(data['assignedUids'] ?? []);

      residents.removeWhere((r) => r['uid'] == resident['uid']);
      uids.removeWhere((id) => id == resident['uid']);

      await docRef.update({
        'assignedResidents': residents,
        'assignedUids': uids,
        'totalResidents': residents.length,
        'isManuallyEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _actionMsg = '✓ ${resident['name']} removed';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _actionMsg = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _moveResident(
      Map<String, String> resident, String targetScheduleId, String targetZone) async {
    setState(() => _loading = true);
    try {
      final fromRef = FirebaseFirestore.instance.collection('schedules').doc(widget.task.id);
      final toRef = FirebaseFirestore.instance.collection('schedules').doc(targetScheduleId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final fromDoc = await transaction.get(fromRef);
        final toDoc = await transaction.get(toRef);

        if (!fromDoc.exists || !toDoc.exists) return;

        final fromData = fromDoc.data() as Map<String, dynamic>;
        final toData = toDoc.data() as Map<String, dynamic>;

        List<dynamic> fromResidents = List.from(fromData['assignedResidents'] ?? []);
        List<dynamic> fromUids = List.from(fromData['assignedUids'] ?? []);
        List<dynamic> toResidents = List.from(toData['assignedResidents'] ?? []);
        List<dynamic> toUids = List.from(toData['assignedUids'] ?? []);

        // Remove from source
        fromResidents.removeWhere((r) => r['uid'] == resident['uid']);
        fromUids.removeWhere((id) => id == resident['uid']);

        // Add to target if not already there
        if (!toUids.contains(resident['uid'])) {
          toResidents.add(resident);
          toUids.add(resident['uid']);
        }

        transaction.update(fromRef, {
          'assignedResidents': fromResidents,
          'assignedUids': fromUids,
          'totalResidents': fromResidents.length,
          'isManuallyEdited': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(toRef, {
          'assignedResidents': toResidents,
          'assignedUids': toUids,
          'totalResidents': toResidents.length,
          'isManuallyEdited': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      setState(() {
        _actionMsg = '✓ ${resident['name']} moved to $targetZone';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _actionMsg = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addResident() async {
    setState(() => _loading = true);
    
    try {
      final resSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .get();

      final allResidents = resSnap.docs.map((doc) {
        final d = doc.data();
        final url = d['photoUrl'] ?? d['avatarUrl'] ?? '';
        return {
          'uid': doc.id,
          'name': d['name']?.toString() ?? 'Unknown',
          'photoUrl': url.toString(),
          'avatarUrl': url.toString(),
          'floor': d['floor']?.toString() ?? '?',
        };
      }).toList();

      if (!mounted) return;
      setState(() => _loading = false);

      final currentUids = widget.task.assignedUids.toSet();

      await showDialog(
        context: context,
        builder: (ctx) {
          String searchQuery = "";
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final filtered = allResidents.where((r) => 
                r['name']!.toLowerCase().contains(searchQuery.toLowerCase())
              ).toList();

              return AlertDialog(
                title: const Text("Add Resident", style: TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: "Search resident...",
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) {
                          setDialogState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: filtered.isEmpty 
                          ? const Padding(padding: EdgeInsets.all(20), child: Text("No residents found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final r = filtered[i];
                                final alreadyAssigned = currentUids.contains(r['uid']);
                                final photoUrl = r['photoUrl']!;

                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                    child: photoUrl.isEmpty ? Text(r['name']![0].toUpperCase(), style: const TextStyle(fontSize: 12)) : null,
                                  ),
                                  title: Text(r['name']!),
                                  subtitle: alreadyAssigned 
                                    ? const Text("Already assigned", style: TextStyle(fontSize: 10, color: Colors.blue))
                                    : Text("Floor ${r['floor']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  trailing: alreadyAssigned 
                                    ? const Icon(Icons.check_circle, color: Colors.blue)
                                    : const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  onTap: alreadyAssigned ? null : () async {
                                    Navigator.pop(ctx);
                                    final Map<String, String> clean = {
                                      'uid': r['uid']!.toString(),
                                      'name': r['name']!.toString(),
                                      'photoUrl': r['photoUrl']!.toString(),
                                      'avatarUrl': r['avatarUrl']!.toString(),
                                    };
                                    await _peristAddition(clean);
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching residents: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _peristAddition(Map<String, String> resident) async {
    setState(() => _loading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('schedules').doc(widget.task.id);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      List<dynamic> residents = List.from(data['assignedResidents'] ?? []);
      List<dynamic> uids = List.from(data['assignedUids'] ?? []);

      if (!uids.contains(resident['uid'])) {
        residents.add(resident);
        uids.add(resident['uid']);
      }

      await docRef.update({
        'assignedResidents': residents,
        'assignedUids': uids,
        'totalResidents': residents.length,
        'isManuallyEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _actionMsg = '✓ ${resident['name']} added';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _actionMsg = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _showMoveDialog(Map<String, String> resident) async {
    // Fetch all schedules for the same Friday
    final taskDate = DateTime(
      widget.task.scheduledAt.year,
      widget.task.scheduledAt.month,
      widget.task.scheduledAt.day,
    );
    final start = taskDate;
    final end = taskDate.add(const Duration(days: 1));

    final snap = await FirebaseFirestore.instance
        .collection('schedules')
        .where('category', isEqualTo: 'campus_work')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .get();

    if (!mounted) return;

    final targets = snap.docs
        .where((d) => d.id != widget.task.id)
        .map((d) => {'id': d.id, 'zone': (d.data()['zone'] ?? '') as String})
        .toList();

    final chosen = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Move ${resident['name']} to…',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        children: [
          if (targets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No other schedules on this date.'),
            )
          else
            ...targets.map((t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF3D5AFE)),
                        const SizedBox(width: 10),
                        Text(t['zone']!,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );

    if (chosen != null) {
      await _moveResident(resident, chosen['id']!, chosen['zone']!);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Schedule?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Delete the schedule for "${widget.task.zone}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.task.id)
          .delete();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.task.category == 'campus_work'
        ? const Color(0xFF3D5AFE)
        : Colors.green.shade600;
    return _sheetWrapper(
      title: 'Edit: ${widget.task.zone}',
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manually edited badge
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('schedules')
                .doc(widget.task.id)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final d = snap.data!.data() as Map<String, dynamic>? ?? {};
              final edited = d['isManuallyEdited'] as bool? ?? false;
              final residents = (d['assignedResidents'] as List<dynamic>? ?? [])
                  .map((e) => Map<String, String>.from(e as Map))
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (edited)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text('Manually edited',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                  // Section: Edit details
                  _inputField("Task Title", _titleController, Icons.task_outlined),
                  const SizedBox(height: 14),
                  _inputField("Zone / Location", _zoneController, Icons.location_on_outlined),
                  const SizedBox(height: 14),
                  // Room Number — only for room_cleaning
                  if (widget.task.category == 'room_cleaning') ...[
                    _inputField(
                      "Room Number (e.g. 301)",
                      _roomController,
                      Icons.door_front_door_outlined,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: _dateTimeBox(
                            icon: Icons.calendar_today_outlined,
                            label: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTime,
                          child: _dateTimeBox(
                            icon: Icons.access_time_outlined,
                            label: _selectedTime.format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _submitButton(label: "Update Schedule Details", loading: _loading, onTap: _updateDetails),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Section: Assigned residents
                  Row(
                    children: [
                      Text(
                        'Assigned Residents (${residents.length})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _loading ? null : _addResident,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_add_alt_1_outlined, size: 16),
                            const SizedBox(width: 4),
                            Text("Add", style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  if (_actionMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_actionMsg!,
                          style: TextStyle(
                              fontSize: 12,
                              color: _actionMsg!.startsWith('✓')
                                  ? Colors.green.shade600
                                  : Colors.red)),
                    ),
                  const SizedBox(height: 10),

                  if (residents.isEmpty)
                    const Text('No residents assigned.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ...residents.map((r) => _residentRow(r, color)),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Delete schedule button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('Delete This Schedule',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _residentRow(Map<String, String> r, Color color) {
    final name = r['name'] ?? '';
    final avatarUrl = r['avatarUrl'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
          ),
          // Move button
          GestureDetector(
            onTap: _loading ? null : () => _showMoveDialog(r),
            child: Container(
              padding: const EdgeInsets.all(7),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.swap_horiz, size: 16, color: color),
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: _loading ? null : () => _removeResident(r),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.close, size: 16, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared helpers
// ─────────────────────────────────────────────
Widget _sheetWrapper({
  required String title,
  required BuildContext context,
  required Widget child,
}) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}

Widget _inputField(
  String hint,
  TextEditingController controller,
  IconData icon, {
  TextInputType keyboardType = TextInputType.text,
}) {
  return Container(
    decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(14)),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      ),
    ),
  );
}

Widget _dateTimeBox({required IconData icon, required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ],
    ),
  );
}

Widget _submitButton({
  required String label,
  required bool loading,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );
}
