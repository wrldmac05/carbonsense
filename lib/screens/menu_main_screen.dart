import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class MenuMainScreen extends StatelessWidget {
  const MenuMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // Top alignment
              crossAxisAlignment: CrossAxisAlignment.stretch, // Full iPad width stretch
              children: [
                const SizedBox(height: 24), // Consistent top breathing room
                Text(
                  'Menu',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildMenuButton(
                  context,
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required IconData icon, required String label, VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor, size: 30),
        title: Text(label, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}