import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dorm_app/models/notification_model.dart';

class ResidentNotificationsScreen extends StatelessWidget {
  const ResidentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("No user logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
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
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)
                            ],
                          ),
                          child: Icon(Icons.notifications_none_outlined, size: 48, color: Colors.blue[300]),
                        ),
                        const SizedBox(height: 24),
                        const Text("No notifications yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const Text("When you get messages, they'll show up here", style: TextStyle(color: Color(0xFF64748B))),
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
                    final notification = NotificationModel.fromMap(data, doc.id);
                    final String timeFormat = DateFormat('h:mm a').format(notification.createdAt);
                    final String dateFormat = DateFormat('MMM dd, yyyy').format(notification.createdAt);
                    
                    IconData icon;
                    Color color;
                    switch (notification.type) {
                      case NotificationType.approval:
                        icon = Icons.check_circle_outline;
                        color = const Color(0xFF10B981);
                        break;
                      case NotificationType.rejection:
                        icon = Icons.cancel_outlined;
                        color = const Color(0xFFEF4444);
                        break;
                      case NotificationType.newSchedule:
                        icon = Icons.calendar_today_outlined;
                        color = const Color(0xFF2563EB);
                        break;
                      default:
                        icon = Icons.info_outline;
                        color = const Color(0xFF64748B);
                    }

                    return GestureDetector(
                      onTap: () async {
                        // Mark as read
                        if (!notification.isRead) {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(notification.id)
                              .update({'isRead': true});
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: notification.isRead ? Colors.white.withOpacity(0.7) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: notification.isRead ? Colors.transparent : color.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                                          fontSize: 14,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        timeFormat,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.message,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dateFormat,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
