import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dorm_app/services/schedule_generator_service.dart';
import 'package:dorm_app/services/location_seeder_service.dart';

/// Screen that lets the floor leader create the weekly campus duty schedule
/// with a single button tap. Shows a preview of upcoming Friday's details.
class CreateScheduleScreen extends StatefulWidget {
  const CreateScheduleScreen({super.key});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _service = ScheduleGeneratorService();

  bool _creating = false;
  bool _checking = false;
  bool _alreadyExists = false;
  CreationResult? _lastResult;
  String? _errorMsg;

  final DateTime _friday = ScheduleGeneratorService.nextFriday();

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    setState(() => _checking = true);
    try {
      _alreadyExists = await _service.scheduleExistsForFriday(_friday);
    } catch (_) {}
    setState(() => _checking = false);
  }

  Future<void> _create({bool overwrite = false}) async {
    setState(() {
      _creating = true;
      _errorMsg = null;
      _lastResult = null;
    });

    try {
      // Seed locations if this is the first run
      final seeder = LocationSeederService();
      final alreadySeeded = await seeder.isSeeded();
      if (!alreadySeeded) await seeder.seed();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final result = await _service.createWeeklyCampusSchedule(
        overwriteExisting: overwrite,
        createdByUid: uid,
      );
      setState(() {
        _lastResult = result;
        _alreadyExists = true;
        _creating = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _creating = false;
      });
    }
  }

  void _confirmAndCreate() async {
    if (_alreadyExists) {
      final String? action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              SizedBox(height: 12),
              Text('Schedule Active', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'A schedule already exists for this Friday. Would you like to regenerate it completely or go back to manage the current assignments?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'regenerate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Re-create Everything'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'manage'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3D5AFE)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Manage Existing Schedule'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      );

      if (action == 'regenerate') {
        _create(overwrite: true);
      } else if (action == 'manage') {
        if (mounted) Navigator.pop(context);
      }
    } else {
      _create(overwrite: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fridayLabel = _formatDate(_friday);
    final weekNum = ScheduleGeneratorService.isoWeekNumber(_friday);

    return Scaffold(
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
          'Create Work Duty Schedule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Visual ──
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: _alreadyExists 
                        ? Colors.orange.withOpacity(0.12)
                        : const Color(0xFF3D5AFE).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _alreadyExists ? Icons.event_available : Icons.auto_awesome,
                      size: 80,
                      color: _alreadyExists ? Colors.orange : const Color(0xFF3D5AFE),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _alreadyExists ? 'Schedule Active' : 'Create Schedule',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _alreadyExists 
                        ? 'A schedule for $fridayLabel already exists. You can re-create it now or manage it manually.'
                        : 'Automatically assign residents to 20 duty areas for $fridayLabel based on their history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (_checking)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── Result message ──
            if (_lastResult != null) _buildSuccessBanner(_lastResult!),
            if (_errorMsg != null) _buildErrorBanner(_errorMsg!),
            if (_lastResult != null || _errorMsg != null)
              const SizedBox(height: 16),

            // ── Create button ──
            _BuildCreateButton(
              creating: _creating,
              alreadyExists: _alreadyExists,
              onTap: _confirmAndCreate,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(CreationResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                'Schedule Created!',
                style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '✓ ${result.shiftsCreated} duty areas created\n'
            '✓ ${result.residentsAssigned} residents assigned\n'
            '✓ Week #${result.weekNumber} rotation applied\n'
            '✓ Scheduled for ${_formatDate(result.friday)}',
            style: TextStyle(color: Colors.green.shade700, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style:
                      TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ],
      ),
    );
  }
}


// ── Create button ───────────────────────────────────────────────────────────
class _BuildCreateButton extends StatelessWidget {
  final bool creating;
  final bool alreadyExists;
  final VoidCallback onTap;

  const _BuildCreateButton({
    required this.creating,
    required this.alreadyExists,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: creating ? null : onTap,
        icon: creating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Icon(
                alreadyExists ? Icons.refresh : Icons.auto_awesome,
                color: Colors.white,
              ),
        label: Text(
          creating
              ? 'Creating…'
              : alreadyExists
                  ? 'Re-create Schedule'
                  : 'Create This Week\'s Schedule',
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              alreadyExists ? Colors.orange : const Color(0xFF3D5AFE),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────
String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
