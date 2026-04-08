import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/auth_services.dart';

class AdminManageResidentsScreen extends StatefulWidget {
  const AdminManageResidentsScreen({super.key});

  @override
  State<AdminManageResidentsScreen> createState() =>
      _AdminManageResidentsScreenState();
}

class _AdminManageResidentsScreenState
    extends State<AdminManageResidentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  String _searchQuery = '';
  String _sortBy = 'name';
  String _filterRole = 'all';

  Stream<List<UserModel>> _usersStream() {
    Query query = FirebaseFirestore.instance.collection('users');
    if (_filterRole != 'all') {
      query = query.where('role', isEqualTo: _filterRole);
    }
    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList(),
    );
  }

  Future<void> _addResident({
    required String name,
    required String email,
    required String password,
    String? room,
    String? phone,
    String? studentId,
    String role = 'resident',
  }) async {
    await _authService.createUserAccount(
      email: email,
      password: password,
      name: name,
      studentId: studentId ?? '',
      role: role,
      room: room,
      phone: phone,
    );
  }

  Future<void> _updateResident(
    UserModel user, {
    required String name,
    String? room,
    String? phone,
    String? studentId,
    String? floor,
    String? gender,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': name,
      'roomNumber': room?.isEmpty ?? true ? null : room,
      'phoneNumber': phone?.isEmpty ?? true ? null : phone,
      'studentId': studentId?.isEmpty ?? true ? null : studentId,
      'floorId': floor?.isEmpty ?? true ? null : floor,
      'gender': gender?.isEmpty ?? true ? null : gender,
    });
  }

  Future<void> _deleteResident(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Resident"),
        content: const Text("Are you sure you want to delete this resident? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resident deleted")),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Residents"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by role',
            onSelected: (val) => setState(() => _filterRole = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('All Users')),
              PopupMenuItem(value: 'resident', child: Text('Residents Only')),
              PopupMenuItem(value: 'floor_leader', child: Text('Floor Leaders Only')),
              PopupMenuItem(value: 'admin', child: Text('Admins Only')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'name', child: Text("Sort by Name")),
              const PopupMenuItem(value: 'phoneNumber', child: Text("Sort by Phone")),
              const PopupMenuItem(value: 'studentId', child: Text("Sort by Student ID")),
              const PopupMenuItem(value: 'floorId', child: Text("Sort by Floor")),
              const PopupMenuItem(value: 'roomNumber', child: Text("Sort by Room")),
              const PopupMenuItem(value: 'gender', child: Text("Sort by Gender")),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged:
                  (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: const InputDecoration(
                hintText: "Search resident...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          // Role filter chip
          if (_filterRole != 'all')
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Wrap(
                children: [
                  Chip(
                    label: Text('Showing: $_filterRole'),
                    onDeleted: () => setState(() => _filterRole = 'all'),
                    backgroundColor: const Color(0xFFE8EEF9),
                    labelStyle: const TextStyle(color: Color(0xFF1A4FD6), fontSize: 12),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _usersStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final residents =
                    snapshot.data!
                        .where(
                          (u) =>
                              u.name.toLowerCase().contains(_searchQuery) ||
                              (u.roomNumber ?? '').toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              u.email.toLowerCase().contains(_searchQuery) ||
                              (u.studentId ?? '').toLowerCase().contains(_searchQuery),
                        )
                        .toList();

                residents.sort((a, b) {
                  switch (_sortBy) {
                    case 'phoneNumber':
                      return (a.phoneNumber ?? '').compareTo(b.phoneNumber ?? '');
                    case 'studentId':
                      return (a.studentId ?? '').compareTo(b.studentId ?? '');
                    case 'floorId':
                      return (a.floorId ?? '').compareTo(b.floorId ?? '');
                    case 'roomNumber':
                      return (a.roomNumber ?? '').compareTo(b.roomNumber ?? '');
                    case 'gender':
                      return (a.gender ?? '').compareTo(b.gender ?? '');
                    default:
                      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  }
                });

                if (residents.isEmpty) {
                  return const Center(child: Text("No residents found"));
                }

                return ListView.builder(
                  itemCount: residents.length,
                  itemBuilder: (context, index) {
                    final user = residents[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.name.isNotEmpty ? user.name[0] : "?"),
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                        user.roomNumber != null
                            ? "Room ${user.roomNumber}"
                            : "No room assigned",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.role != UserRole.admin) ...[
                            _roleChip(user.role.label, 
                              user.isFloorLeader ? Colors.indigo : Colors.blue),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteResident(user.uid),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ================= DIALOG ADD =================

  void _showAddDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final roomController = TextEditingController();
    final phoneController = TextEditingController();
    final studentIdController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'resident';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState2) => AlertDialog(
          title: const Text("Add User"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'resident', child: Text('Resident')),
                    DropdownMenuItem(value: 'floor_leader', child: Text('Floor Leader')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState2(() => role = v!),
                ),
                const SizedBox(height: 12),
                _input(nameController, "Name"),
                _input(emailController, "Email"),
                _input(studentIdController, "Student ID"),
                _input(passwordController, "Password (default: Student ID)"),
                _input(roomController, "Room (optional)"),
                _input(phoneController, "Phone (optional)"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: isLoading ? null : () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final studentId = studentIdController.text.trim();
                // Default password = student ID if not specified
                final password = passwordController.text.trim().isEmpty
                    ? studentId
                    : passwordController.text.trim();

                if (name.isEmpty || email.isEmpty || studentId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name, Email, and Student ID are required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters (Student ID is used as default)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState2(() => isLoading = true);
                try {
                  await _addResident(
                    name: name,
                    email: email,
                    password: password,
                    room: roomController.text.trim(),
                    phone: phoneController.text.trim(),
                    studentId: studentId,
                    role: role,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('User added! Default password: $password'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setState2(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  // ================= DIALOG EDIT =================

  void _showEditDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final roomController = TextEditingController(text: user.roomNumber);
    final phoneController = TextEditingController(text: user.phoneNumber);
    final studentIdController = TextEditingController(text: user.studentId);
    final floorController = TextEditingController(text: user.floorId);
    final genderController = TextEditingController(text: user.gender);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Edit Resident"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  _input(nameController, "Name"),
                  _input(roomController, "Room"),
                  _input(phoneController, "Phone"),
                  _input(studentIdController, "Student ID"),
                  _input(floorController, "Floor"),
                  _input(genderController, "Gender"),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  await _updateResident(
                    user,
                    name: nameController.text.trim(),
                    room: roomController.text.trim(),
                    phone: phoneController.text.trim(),
                    studentId: studentIdController.text.trim(),
                    floor: floorController.text.trim(),
                    gender: genderController.text.trim(),
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  Widget _input(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
