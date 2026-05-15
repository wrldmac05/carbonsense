import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuMainScreen extends StatelessWidget {
  const MenuMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0, // Makes them perfect squares
            children: [
              _buildMenuBox(
                context,
                icon: Icons.person,
                label: 'Profile',
                color: AppTheme.primaryColor,
                onTap: () => context.push('/menu/profile'),
              ),
              _buildMenuBox(
                context,
                icon: Icons.settings,
                label: 'Settings',
                color: Colors.blueGrey,
                onTap: () => context.push('/menu/settings'),
              ),
              _buildMenuBox(
                context,
                icon: Icons.logout,
                label: 'Log Out',
                color: Colors.red,
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/welcome');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuBox(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withAlpha(26),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}