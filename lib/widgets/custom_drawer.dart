import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _displayName = 'Eco Warrior';
  String _email = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchQuickProfile();
  }

  Future<void> _fetchQuickProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) setState(() => _email = user.email ?? '');

      try {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('display_name, avatar_url')
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            _displayName = profile['display_name'] ?? 'Eco Warrior';
            _avatarUrl = profile['avatar_url'];
          });
        }
      } catch (e) {
        debugPrint('Drawer profile fetch error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force the drawer to take up exactly 85% of the screen width
    final drawerWidth = MediaQuery.of(context).size.width * 0.85;

    return Drawer(
      width: drawerWidth,
      backgroundColor: const Color(0xFFF9FFF9), // Match the app's clean background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // --- 1. PREMIUM HEADER ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      backgroundImage: _avatarUrl != null ? NetworkImage("$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}") : null,
                      child: _avatarUrl == null ? const Icon(Icons.person, size: 36, color: AppTheme.primaryColor) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  // A small "Alive" badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco, size: 14, color: AppTheme.primaryColor),
                        SizedBox(width: 6),
                        Text('Carbon Tracking Active', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            // --- 2. MODERN MENU LIST ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildDrawerTile(
                    context,
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    subtitle: 'View your lifestyle data',
                    onTap: () {
                      Navigator.pop(context); // Close drawer first
                      context.push('/profile'); // Route to your profile page
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.help_outline,   
                    title: 'Help & Support',
                    subtitle: 'FAQ and contact',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/help-support');// Add support routing later
                    },
                  ),
                ],
              ),
            ),

            // --- 3. FOOTER (LOGOUT) ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: InkWell(
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/welcome');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Log Out', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 The Sleek Menu Tile Widget
  Widget _buildDrawerTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(icon, color: Colors.black87, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}