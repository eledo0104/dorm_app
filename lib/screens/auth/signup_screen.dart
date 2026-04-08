import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final studentIdController = TextEditingController();
  final roomController = TextEditingController();

  String selectedRole = 'resident'; // 'resident' or 'floor_leader'
  String selectedGender = '';
  String? selectedFloor;
  bool obscurePassword = true;

  final List<String> floors = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account', style: theme.textTheme.titleLarge),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Register for the dormitory system',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // 🔹 ROLE SELECTION
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildRoleTab('Resident', 'resident', theme),
                    _buildRoleTab('Floor Leader', 'floor_leader', theme),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🔹 NAME
              _buildLabel('FULL NAME', theme),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 STUDENT ID
              _buildLabel('STUDENT ID', theme),
              TextField(
                controller: studentIdController,
                decoration: const InputDecoration(
                  hintText: 'Enter student ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 EMAIL
              _buildLabel('UNIVERSITY EMAIL', theme),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'name@jiu.ac',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 GENDER
              _buildLabel('GENDER', theme),
              Row(
                children: [
                  Expanded(child: _buildGenderButton('Male', theme)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGenderButton('Female', theme)),
                ],
              ),
              const SizedBox(height: 20),

              // 🔹 FLOOR & ROOM
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('FLOOR', theme),
                        DropdownButtonFormField<String>(
                          value: selectedFloor,
                          hint: const Text('Select'),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.layers_outlined),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: floors
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text('Floor $f'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => selectedFloor = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('ROOM', theme),
                        TextField(
                          controller: roomController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 101',
                            prefixIcon: Icon(Icons.door_front_door_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🔹 PASSWORD
              _buildLabel('PASSWORD', theme),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Min. 8 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 🔹 REGISTER BUTTON
              auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty ||
                            studentIdController.text.trim().isEmpty ||
                            emailController.text.trim().isEmpty ||
                            passwordController.text.trim().isEmpty ||
                            selectedGender.isEmpty ||
                            selectedFloor == null) {
                          _showError(context, 'Please fill in all required fields');
                          return;
                        }

                        try {
                          await auth.signup(
                            email: emailController.text.trim(),
                            studentId: studentIdController.text.trim(),
                            password: passwordController.text.trim(),
                            name: nameController.text.trim(),
                            role: selectedRole,
                            gender: selectedGender,
                            floor: int.tryParse(selectedFloor!),
                            room: roomController.text.isNotEmpty
                                ? int.tryParse(roomController.text)
                                : null,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Account created successfully!')),
                            );
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        } catch (e) {
                          if (mounted) {
                            _showError(context, e.toString());
                          }
                        }
                      },
                      child: const Text('Create Account'),
                    ),

              const SizedBox(height: 24),

              // 🔹 FOOTER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ", style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Log In',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary.withOpacity(0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRoleTab(String label, String value, ThemeData theme) {
    final isSelected = selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderButton(String gender, ThemeData theme) {
    final isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.05) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          gender,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
