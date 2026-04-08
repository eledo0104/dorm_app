import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminWeeklyReportsScreen extends StatefulWidget {
  const AdminWeeklyReportsScreen({super.key});

  @override
  State<AdminWeeklyReportsScreen> createState() => _AdminWeeklyReportsScreenState();
}

class _AdminWeeklyReportsScreenState extends State<AdminWeeklyReportsScreen> {
  late DateTime _weekStart;
  late DateTime _weekEnd;

  @override
  void initState() {
    super.initState();
    _setCurrentWeek();
  }

  void _setCurrentWeek() {
    final now = DateTime.now();
    // Monday as start of week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(monday.year, monday.month, monday.day);
    _weekEnd = _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  void _previousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _weekEnd = _weekEnd.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _weekEnd = _weekEnd.add(const Duration(days: 7));
    });
  }

  String _formatWeekRange() {
    final startStr = DateFormat('MMM d').format(_weekStart);
    final endStr = DateFormat('MMM d, yyyy').format(_weekEnd);
    return '$startStr - $endStr';
  }

  Stream<QuerySnapshot> _schedulesForWeek() {
    return FirebaseFirestore.instance
        .collection('schedules')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_weekStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_weekEnd))
        .snapshots();
  }

  Stream<QuerySnapshot> _proofsForWeek() {
    return FirebaseFirestore.instance
        .collection('duty_proofs')
        .where('submittedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_weekStart))
        .where('submittedAt', isLessThanOrEqualTo: Timestamp.fromDate(_weekEnd))
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Weekly Reports'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week navigation
            _buildWeekNavigator(),
            const SizedBox(height: 24),

            // Summary Cards
            _buildSummarySection(),
            const SizedBox(height: 24),

            // Daily breakdown
            _buildDailyBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.grey.withOpacity(0.07),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: const Icon(Icons.chevron_left, color: Color(0xFF3D5AFE)),
          ),
          Column(
            children: [
              const Text(
                'WEEK OF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatWeekRange(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right, color: Color(0xFF3D5AFE)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _schedulesForWeek(),
      builder: (context, scheduleSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _proofsForWeek(),
          builder: (context, proofSnap) {
            int totalSchedules = 0;
            int workDuties = 0;
            int roomCleaning = 0;
            int approved = 0;
            int pending = 0;
            int rejected = 0;

            if (scheduleSnap.hasData) {
              totalSchedules = scheduleSnap.data!.docs.length;
              for (var doc in scheduleSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['zoneType'] == 'room') {
                  roomCleaning++;
                } else {
                  workDuties++;
                }
              }
            }

            if (proofSnap.hasData) {
              for (var doc in proofSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                if (status == 'approved') {
                  approved++;
                } else if (status == 'rejected') {
                  rejected++;
                } else {
                  pending++;
                }
              }
            }

            final completionRate = totalSchedules == 0 
              ? 0.0 
              : approved / totalSchedules;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                
                // Top completion card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Completion Rate',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${(completionRate * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3D5AFE),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: completionRate,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3D5AFE)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Stats grid
                Row(
                  children: [
                    Expanded(child: _summaryCard('Total\nSchedules', '$totalSchedules', Icons.calendar_month_outlined, const Color(0xFF3D5AFE))),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryCard('Work\nDuties', '$workDuties', Icons.school_outlined, const Color(0xFF0EA5E9))),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryCard('Room\nCleaning', '$roomCleaning', Icons.cleaning_services_outlined, const Color(0xFF8B5CF6))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _summaryCard('Approved', '$approved', Icons.check_circle_outline, Colors.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryCard('Pending', '$pending', Icons.hourglass_empty, Colors.orange)),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryCard('Rejected', '$rejected', Icons.cancel_outlined, Colors.red)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _schedulesForWeek(),
      builder: (context, snapshot) {
        // Group schedules by day
        Map<String, List<Map<String, dynamic>>> dailySchedules = {};
        final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

        // Initialize all days
        for (int i = 0; i < 7; i++) {
          final day = _weekStart.add(Duration(days: i));
          final key = DateFormat('yyyy-MM-dd').format(day);
          dailySchedules[key] = [];
        }

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp?)?.toDate();
            if (date != null) {
              final key = DateFormat('yyyy-MM-dd').format(date);
              if (dailySchedules.containsKey(key)) {
                dailySchedules[key]!.add({...data, 'id': doc.id});
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(7, (i) {
              final day = _weekStart.add(Duration(days: i));
              final key = DateFormat('yyyy-MM-dd').format(day);
              final schedules = dailySchedules[key] ?? [];
              final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == key;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isToday 
                    ? Border.all(color: const Color(0xFF3D5AFE), width: 1.5) 
                    : null,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.grey.withOpacity(0.06),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isToday 
                          ? const Color(0xFF3D5AFE).withOpacity(0.12) 
                          : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isToday ? const Color(0xFF3D5AFE) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          dayNames[i],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isToday ? const Color(0xFF3D5AFE) : const Color(0xFF1E293B),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3D5AFE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${schedules.length} schedule${schedules.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    children: schedules.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No schedules for this day',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ),
                        ]
                      : schedules.map((s) {
                          final zone = s['zone'] ?? 'Unknown';
                          final zoneType = s['zoneType'] ?? 'work';
                          final assignedNames = (s['assignedResidentNames'] as List<dynamic>?)?.join(', ') ?? 'Unassigned';
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: zoneType == 'room' 
                                      ? const Color(0xFF8B5CF6).withOpacity(0.12)
                                      : const Color(0xFF0EA5E9).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    zoneType == 'room' ? Icons.cleaning_services_outlined : Icons.school_outlined,
                                    color: zoneType == 'room' ? const Color(0xFF8B5CF6) : const Color(0xFF0EA5E9),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        zone,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        assignedNames,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
