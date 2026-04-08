import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DutyReportsScreen extends StatelessWidget {
  const DutyReportsScreen({super.key});

  Stream<QuerySnapshot> _proofsStream() {
    return FirebaseFirestore.instance
        .collection('duty_proofs')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _schedulesStream() {
    return FirebaseFirestore.instance
        .collection('schedules')
        .orderBy('scheduledAt', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3D5AFE),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Duty Reports',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Proof Submissions'),
              Tab(text: 'Schedules'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProofReport(),
            _buildScheduleReport(),
          ],
        ),
      ),
    );
  }

  Widget _buildProofReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: _proofsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _emptyState('No proof submissions yet', Icons.task_outlined);
        }

        final total = docs.length;
        final approved = docs
            .where((d) => (d.data() as Map)['status'] == 'approved')
            .length;
        final pending = docs
            .where((d) => (d.data() as Map)['status'] == 'pending')
            .length;
        final rejected = docs
            .where((d) => (d.data() as Map)['status'] == 'rejected')
            .length;

        return Column(
          children: [
            // Summary bar
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3D5AFE), Color(0xFF2B4EE6)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _statPill('Total', total, Colors.white, Colors.white24),
                  const SizedBox(width: 8),
                  _statPill('Approved', approved, Colors.greenAccent, Colors.white24),
                  const SizedBox(width: 8),
                  _statPill('Pending', pending, Colors.orangeAccent, Colors.white24),
                  const SizedBox(width: 8),
                  _statPill('Rejected', rejected, Colors.redAccent, Colors.white24),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final status = d['status'] ?? 'pending';
                  final name = d['submittedByName'] ?? 'Unknown';
                  final desc = d['description'] ?? '';
                  final submittedAt = (d['submittedAt'] as Timestamp?)?.toDate();
                  Color statusColor = Colors.orange;
                  if (status == 'approved') statusColor = Colors.green;
                  if (status == 'rejected') statusColor = Colors.red;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
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
                          radius: 20,
                          backgroundColor: statusColor.withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              if (desc.isNotEmpty)
                                Text(desc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black45)),
                              if (submittedAt != null)
                                Text(
                                  _formatDate(submittedAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black38),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: _schedulesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _emptyState('No schedules created yet', Icons.calendar_month_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final title = d['title'] ?? d['zone'] ?? 'Unnamed';
            final location = d['location'] ?? d['zone'] ?? '';
            final shiftLabel = d['shiftLabel'] ?? '';
            final category = d['category'] ?? 'campus_work';
            final scheduledAt = (d['scheduledAt'] as Timestamp?)?.toDate();
            final assignedCount = (d['assignedUids'] as List?)?.length ?? 0;

            final isCampus = category == 'campus_work';
            final categoryColor = isCampus
                ? const Color(0xFF3D5AFE)
                : Colors.green.shade600;
            final categoryLabel = isCampus ? 'Work Duty' : 'Room Cleaning';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCampus
                          ? Icons.school_outlined
                          : Icons.cleaning_services_outlined,
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        if (location.isNotEmpty)
                          Text(location,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black45)),
                        if (shiftLabel.isNotEmpty)
                          Text(shiftLabel,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38)),
                        if (scheduledAt != null)
                          Text(_formatDate(scheduledAt),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(categoryLabel,
                            style: TextStyle(
                                fontSize: 10,
                                color: categoryColor,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Text('$assignedCount assigned',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statPill(String label, int value, Color textColor, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            Text(label,
                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $h:$min $period';
  }
}
