import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dorm_app/models/duty_proof_model.dart';

class ResidentActivityHistoryScreen extends StatelessWidget {
  const ResidentActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("No user logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('duty_proofs')
                  .where('submittedBy', isEqualTo: user.uid)
                  .orderBy('submittedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("No activity found yet", style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final proof = DutyProofModel.fromMap(data, doc.id);
                    final String category = data['category'] ?? 'Cleaning Duty';
                    final String formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(proof.submittedAt);
                    
                    Color statusColor = Colors.orange;
                    if (proof.status == DutyProofStatus.approved) {
                      statusColor = const Color(0xFF10B981);
                    } else if (proof.status == DutyProofStatus.rejected) {
                      statusColor = const Color(0xFFEF4444);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            proof.status == DutyProofStatus.approved 
                              ? Icons.check_circle_outline 
                              : proof.status == DutyProofStatus.rejected 
                                ? Icons.cancel_outlined 
                                : Icons.hourglass_top_outlined,
                            color: statusColor,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          category.replaceAll('_', ' ').split(' ').map((str) => str[0].toUpperCase() + str.substring(1)).join(' '),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(formattedDate, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                proof.status.name.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFFE2E8F0)),
                        onTap: () {
                          // Could navigate to details if needed
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
