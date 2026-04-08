import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dorm_app/models/schedule_model.dart';
import 'package:intl/intl.dart';
import 'package:dorm_app/models/duty_proof_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:dorm_app/services/storage_service.dart';

class ResidentTaskDetailScreen extends StatefulWidget {
  final ScheduleShift shift;
  const ResidentTaskDetailScreen({super.key, required this.shift});

  @override
  State<ResidentTaskDetailScreen> createState() => _ResidentTaskDetailScreenState();
}

class _ResidentTaskDetailScreenState extends State<ResidentTaskDetailScreen> {
  final _noteController = TextEditingController();
  XFile? _imageFile;
  bool _isSubmitting = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _submitReport() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please take a photo as proof of duty.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Upload image to Firebase Storage
      final bytes = await _imageFile!.readAsBytes();
      final imageUrl = await StorageService.uploadDutyProof(
        imageBytes: bytes,
        scheduleId: widget.shift.id,
        userId: user.uid,
      );

      // 2. Get User Info
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown Resident';
      final floorId = userDoc.data()?['floor']?.toString();

      // 3. Save to duty_proofs collection
      await FirebaseFirestore.instance.collection('duty_proofs').add({
        'scheduleId': widget.shift.id,
        'submittedBy': user.uid,
        'submittedByName': userName,
        'description': _noteController.text.trim(),
        'imageUrl': imageUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'floorId': floorId,
        'zone': widget.shift.zone,
        'location': widget.shift.location,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting report: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(widget.shift.date);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Task Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Task Overview Card ──
            _buildInfoCard(dateStr),
            const SizedBox(height: 24),

            // ── Team Members ──
            const Text(
              "DORM MATES ON DUTY",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),
            _buildTeamList(),
            const SizedBox(height: 32),

            // ── Submission Section ──
            const Text(
              "DUTY REPORT STATUS",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 1.1),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('duty_proofs')
                  .where('scheduleId', isEqualTo: widget.shift.id)
                  .where('submittedBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _buildSubmissionForm();
                }

                final proof = DutyProofModel.fromMap(docs.first.data() as Map<String, dynamic>, docs.first.id);
                
                if (proof.status == DutyProofStatus.rejected) {
                  return Column(
                    children: [
                      _buildProofStatusCard(proof),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      const Text(
                        "RE-SUBMIT DUTY REPORT",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFEF4444), letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 16),
                      _buildSubmissionForm(),
                    ],
                  );
                }
                
                return _buildProofStatusCard(proof);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String dateStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.shift.zone,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Icon(Icons.info_outline, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            widget.shift.location,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                "${widget.shift.timeStart} - ${widget.shift.timeEnd}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Text(
            dateStr,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.shift.assignedResidents.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
        itemBuilder: (context, index) {
          final res = widget.shift.assignedResidents[index];
          final name = res['name'] ?? 'Unknown';
          final avatar = res['avatarUrl'] ?? '';
          final isMe = FirebaseAuth.instance.currentUser?.uid == res['uid'];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? Text(name[0], style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold)) : null,
            ),
            title: Text(
              isMe ? "$name (You)" : name,
              style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w500, fontSize: 14),
            ),
            subtitle: Text(isMe ? "Active Task" : "Dorm Mate", style: const TextStyle(fontSize: 12)),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Complete your assigned task and take a clear photo of the area as proof.",
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        // ── Photo Picker ──
        GestureDetector(
          onTap: _isSubmitting ? null : _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.shade100, width: 2, style: BorderStyle.solid),
              image: _imageFile != null 
                  ? DecorationImage(
                      image: kIsWeb ? NetworkImage(_imageFile!.path) : FileImage(File(_imageFile!.path)) as ImageProvider, 
                      fit: BoxFit.cover
                    ) 
                  : null,
            ),
            child: _imageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.blue.shade400),
                      const SizedBox(height: 12),
                      Text("Take photo of finished task", style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text("Required for verification", style: TextStyle(color: Colors.black38, fontSize: 12)),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        right: 12,
                        top: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Notes Input ──
        TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "Add any notes or report details...",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 24),

        // ── Submit Button ──
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 12),
                      Text("Submit Duty Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofStatusCard(DutyProofModel proof) {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_empty;
    if (proof.status == DutyProofStatus.approved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (proof.status == DutyProofStatus.rejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Submission ${proof.status.name.toUpperCase()}",
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    "Submitted on ${DateFormat('MMM d, h:mm a').format(proof.submittedAt)}",
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ],
          ),
          if (proof.imageUrl != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: proof.imageUrl!.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(proof.imageUrl!.split(',').last),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                          height: 150,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image_outlined)),
                    )
                  : Image.network(
                      proof.imageUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                          height: 150,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image_outlined)),
                    ),
            ),
          ],
          if (proof.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("Your Notes:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(proof.description,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
          if (proof.status == DutyProofStatus.pending) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your floor leader will review this soon.",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
