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
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  // 🌟 UX ENHANCEMENT: Password visibility toggles
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

  // 🌟 CUSTOM SUCCESS/ERROR MESSAGE HELPER
  void _showCustomMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // Uses AppTheme.primaryColor for success messages
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showCustomMessage('Please fill out both password fields.', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showCustomMessage('Passwords do not match.', isError: true);
      return;
    }

    if (!_hasMinLength || !_hasUppercase || !_hasNumber) {
      _showCustomMessage('Password does not meet requirements.', isError: true);
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _showCustomMessage('This reset link has expired or is invalid. Please request a new one.', isError: true);
      context.go('/forgot-password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));

      if (mounted) {
        // 🌟 FIRE CUSTOM SUCCESS MESSAGE
        _showCustomMessage('Password updated successfully! Please login with your new credentials.');

        await Supabase.instance.client.auth.signOut();
        context.go('/login');
      }
    } catch (error) {
      if (mounted) {
        _showCustomMessage('Failed to reset password: ${error.toString()}', isError: true);
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🌟 UX ENHANCEMENT: Animated checklist for requirements
  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isMet ? AppTheme.primaryColor : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: isMet ? AppTheme.primaryColor : Colors.grey.shade400, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.check, size: 12, color: isMet ? Colors.white : Colors.transparent),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: isMet ? AppTheme.primaryColor : Colors.grey.shade600, fontSize: 14, fontWeight: isMet ? FontWeight.w600 : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold background color is handled by AppTheme
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🌟 UX ENHANCEMENT: Header Icon with Theme Background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: AppTheme.secondaryColor, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_reset_rounded, size: 80, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 24),

                // 🌟 UX ENHANCEMENT: Better Typography Hierarchy
                Text(
                  'Secure Your Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enter your new password below.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 40),

                // 🌟 UX ENHANCEMENT: Form wrapped in an elevated card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey[900],
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Requirements Section
                      const Text(
                        'Password Requirements:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 12),
                      _buildRequirement('At least 6 characters', _hasMinLength),
                      _buildRequirement('At least 1 uppercase letter', _hasUppercase),
                      _buildRequirement('At least 1 number', _hasNumber),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save New Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
