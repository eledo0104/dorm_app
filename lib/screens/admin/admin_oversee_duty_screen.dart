import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOverseeDutyScreen extends StatefulWidget {
  const AdminOverseeDutyScreen({super.key});

  @override
  State<AdminOverseeDutyScreen> createState() => _AdminOverseeDutyScreenState();
}

class _AdminOverseeDutyScreenState extends State<AdminOverseeDutyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  Stream<List<QueryDocumentSnapshot>> _schedulesStream() {
    return FirebaseFirestore.instance
        .collection('schedules')
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs);
  }

  Stream<List<QueryDocumentSnapshot>> _proofsStream() {
    return FirebaseFirestore.instance
        .collection('duty_proofs')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Oversee Duty'),
        backgroundColor: const Color(0xFF1A4FD6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Schedules'),
            Tab(icon: Icon(Icons.task_alt_outlined), text: 'Proof Submissions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSchedulesList(),
          _buildProofsList(),
        ],
      ),
    );
  }

  Widget _buildSchedulesList() {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _schedulesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;
        if (docs.isEmpty) {
          return _emptyState('No schedules found', Icons.calendar_today_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
            final isOverseen = data['overseen'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
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
                border: isOverseen
                    ? Border.all(color: Colors.green.shade200)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month, color: Color(0xFF1A4FD6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? data['zone'] ?? 'Untitled Schedule',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scheduledAt != null
                              ? _formatDateTime(scheduledAt)
                              : 'No date set',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (data['zone'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Zone: ${data['zone']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isOverseen)
                    const Icon(Icons.check_circle, color: Colors.green, size: 24)
                  else
                    TextButton(
                      onPressed: () => _markOverseen(id),
                      child: const Text('Mark Overseen', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProofsList() {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _proofsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;
        if (docs.isEmpty) {
          return _emptyState('No proof submissions yet', Icons.task_alt_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

            final statusColor = status == 'approved'
                ? Colors.green
                : status == 'rejected'
                    ? Colors.red
                    : Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
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
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(
                      status == 'approved'
                          ? Icons.check
                          : status == 'rejected'
                              ? Icons.close
                              : Icons.hourglass_empty,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['submittedByName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['description'] ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submittedAt != null ? _formatDateTime(submittedAt) : '',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markOverseen(String scheduleId) async {
    await FirebaseFirestore.instance.collection('schedules').doc(scheduleId).update({
      'overseen': true,
      'overseenAt': Timestamp.now(),
    });
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$min $period';
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }
}
