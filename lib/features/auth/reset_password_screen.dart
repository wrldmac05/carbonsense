// lib/features/auth/reset_password_screen.dart

import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // 🌟 ADDED: Confirm Password Controller
  bool _isLoading = false;

  // Reusing your password validation criteria
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 6;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
    });
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim(); // 🌟 ADDED: Get confirm text

    // 🌟 ADDED: Validate that the fields are not empty
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out both password fields.')));
      return;
    }

    // 🌟 ADDED: Validate that both passwords match
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    if (!_hasMinLength || !_hasUppercase || !_hasNumber) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password does not meet requirements.')));
      return;
    }

    // 🌟 THE FIX: Check if Supabase actually established a session from the link
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This reset link has expired or is invalid. Please request a new one.'), backgroundColor: Colors.red));
      // Kick them back to the forgot password screen to try again
      context.go('/forgot-password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Supabase magic: Updates the current user's password using the temporary email session
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password updated successfully! Please login.'), backgroundColor: Colors.green));
        // Wipe current session and force them to login with the new credentials
        await Supabase.instance.client.auth.signOut();
        context.go('/login');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reset password: ${error.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // 🌟 ADDED: Dispose to prevent memory leaks
    super.dispose();
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.radio_button_unchecked, color: isMet ? Colors.green : Colors.grey, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: isMet ? Colors.green : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.lock_reset, size: 80, color: AppTheme.primaryColor)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Enter New Password',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'New Password'),
                ),
                const SizedBox(height: 16), // 🌟 ADDED SPACING
                // 🌟 NEW: Confirm Password Field
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Confirm New Password'),
                ),
                const SizedBox(height: 12),

                _buildRequirement('At least 6 characters', _hasMinLength),
                _buildRequirement('At least 1 uppercase letter', _hasUppercase),
                _buildRequirement('At least 1 number', _hasNumber),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save New Password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
