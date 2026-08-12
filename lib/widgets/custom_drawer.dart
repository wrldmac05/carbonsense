import 'package:carbonsense/main.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  // 1. Static cache: persists across drawer rebuilds/opens
  static String? _cachedDisplayName;
  static String? _cachedEmail;
  static String? _cachedAvatarUrl;
  static bool _hasFetchedOnce = false;

  /// Call this when profile updates or when user logs out to clear cache
  static void clearCache() {
    _cachedDisplayName = null;
    _cachedEmail = null;
    _cachedAvatarUrl = null;
    _hasFetchedOnce = false;
  }

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  // Initialize with cached values if available
  late String _displayName;
  late String _email;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _displayName = CustomDrawer._cachedDisplayName ?? 'Eco Warrior';
    _email = CustomDrawer._cachedEmail ?? '';
    _avatarUrl = CustomDrawer._cachedAvatarUrl;

    // Only fetch from Supabase if we haven't fetched yet
    if (!CustomDrawer._hasFetchedOnce) {
      _fetchQuickProfile();
    }
  }

  Future<void> _fetchQuickProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userEmail = user.email ?? '';
      if (mounted) {
        setState(() => _email = userEmail);
        CustomDrawer._cachedEmail = userEmail;
      }

      try {
        final profile = await Supabase.instance.client.from('user_profiles').select('display_name, avatar_url').eq('user_id', user.id).maybeSingle();

        if (profile != null && mounted) {
          final fetchedName = profile['display_name'] ?? 'Eco Warrior';
          final fetchedAvatar = profile['avatar_url'];

          setState(() {
            _displayName = fetchedName;
            _avatarUrl = fetchedAvatar;
          });

          // Update static cache
          CustomDrawer._cachedDisplayName = fetchedName;
          CustomDrawer._cachedAvatarUrl = fetchedAvatar;
          CustomDrawer._hasFetchedOnce = true;
        }
      } catch (e) {
        debugPrint('Drawer profile fetch error: $e');
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(
            'Log Out?',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      CustomDrawer.clearCache();
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.85;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF9FFF9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // --- 1. HEADER ---
            Container(
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(color: AppTheme.primaryColor),
              child: Stack(
                children: [
                  Positioned(top: -20, right: -30, child: Icon(Icons.fingerprint, size: 160, color: Colors.white.withOpacity(0.06))),
                  Positioned(bottom: -40, left: -10, child: Icon(Icons.blur_on, size: 120, color: Colors.white.withOpacity(0.04))),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                            child: _avatarUrl == null ? const Icon(Icons.person, size: 36, color: Colors.white) : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _displayName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. DRAWER ITEMS ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  // SECTION 1: My Profile & Help Support
                  _buildDrawerTile(
                    context,
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    subtitle: 'View your lifestyle data',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'FAQ and contact',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/help-support');
                    },
                  ),

                  // LINE BREAK 1
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Divider(color: dividerColor, thickness: 1),
                  ),

                  // SECTION 2: Dark Mode
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      final isDarkModeActive = currentMode == ThemeMode.dark || (currentMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

                      return _buildThemeToggleTile(
                        context,
                        isDark: isDarkModeActive,
                        onChanged: (bool value) {
                          themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        },
                      );
                    },
                  ),

                  // LINE BREAK 2
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Divider(color: dividerColor, thickness: 1),
                  ),

                  // SECTION 3: Legal Information (Same style as other tiles)
                  _buildDrawerTile(
                    context,
                    icon: Icons.gavel_outlined,
                    title: 'Legal Information',
                    subtitle: 'Read terms & conditions and Privacy Policy',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/legal');
                    },
                  ),
                ],
              ),
            ),

            // --- 3. FOOTER (LOGOUT) ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: InkWell(
                onTap: () => _showLogoutDialog(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: isDark ? Colors.redAccent : Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(color: isDark ? Colors.redAccent : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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

  // --- STANDARD DRAWER TILE ---
  Widget _buildDrawerTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconBg = isDark ? Colors.grey[850] : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
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

  // --- DARK MODE TOGGLE TILE ---
  Widget _buildThemeToggleTile(BuildContext context, {required bool isDark, required ValueChanged<bool> onChanged}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconBg = isDark ? Colors.grey[850] : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: isDark ? Colors.amber : Colors.orangeAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark ? 'Dark theme enabled' : 'Light theme enabled',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Switch.adaptive(value: isDark, onChanged: onChanged, activeColor: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
