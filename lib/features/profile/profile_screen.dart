import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _lifestyleProfile;

  @override
  void initState() {
    super.initState();
    _fetchCompleteProfile();
  }

  Future<void> _fetchCompleteProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // 👇 ADD THIS LINE HERE to trigger permissions and save the token
      NotificationService().initNotifications();

      final profileResponse = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final lifestyleResponse = await Supabase.instance.client
          .from('lifestyle_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // THE SMART ONBOARDING CHECK (Checks Location)
      if (profileResponse != null) {
        final rawLocation = profileResponse['location'];
        final bool hasLocation = rawLocation != null && rawLocation.toString().trim().isNotEmpty;
        final bool isObProfileDone = profileResponse['ob_profile'] == true;

        if (hasLocation && !isObProfileDone) {
          await Supabase.instance.client
              .from('user_profiles')
              .update({'ob_profile': true})
              .eq('user_id', userId);
          profileResponse['ob_profile'] = true;
        }
      }

      if (mounted) {
        setState(() {
          _userProfile = profileResponse;
          _lifestyleProfile = lifestyleResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconForCommute(String commute) {
    if (commute.contains('Transit')) return Icons.directions_transit;
    if (commute.contains('Cycling')) return Icons.directions_bike;
    if (commute.contains('Walking')) return Icons.directions_walk;
    if (commute.contains('Motorcycle')) return Icons.two_wheeler;
    if (commute.contains('Analyzing')) return Icons.sync;
    return Icons.directions_car;
  }

  // 👇 Functional Bottom Sheet for the Settings Menu
  void _openSettingsMenu(String title, IconData icon, Widget content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 24),
                content,
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FFF9),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
      );
    }

    final displayName = _userProfile?['display_name'] ?? 'Eco Warrior';
    final location = _userProfile?['location'] ?? 'Location not set';
    
    final dietType = _lifestyleProfile?['diet_type'] ?? 'Analyzing...';
    final commuteType = _lifestyleProfile?['commute_type'] ?? 'Analyzing...';
    final energyType = _lifestyleProfile?['home_energy_source'] ?? 'Not Set';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _fetchCompleteProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. CLEAN, SUBTLE AVATAR
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  // 👇 Pulls the image from the database if they uploaded one!
                  backgroundImage: _userProfile?['avatar_url'] != null 
                      ? NetworkImage(// 👇 Adding this unique string forces the image to reload from the server
          "${_userProfile!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}") 
                      : null,
                  child: _userProfile?['avatar_url'] == null 
                      ? const Icon(Icons.person, size: 40, color: AppTheme.primaryColor)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              
              // 2. IDENTITY
              Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(location, style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 20),

              // 3. EDIT PROFILE BUTTON (Moved here for maximum UX)
              SizedBox(
                width: 160,
                child: FilledButton.tonal(
                  onPressed: () async {
                    final didUpdate = await context.push('/edit-profile');
                    if (didUpdate == true) _fetchCompleteProfile();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 40),

              // 4. LIFESTYLE PROFILE GRID
              Align(
                alignment: Alignment.centerLeft,
                child: const Text("Lifestyle Profile", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildGridCard("Diet", dietType, dietType.contains('Analyzing') ? Icons.sync : Icons.restaurant)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGridCard("Commute", commuteType, _getIconForCommute(commuteType))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGridCard(
                      "Home Energy", 
                      energyType, 
                      Icons.electrical_services
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 5. SETTINGS LIST (Cleaned up and Functional)
              Align(
                alignment: Alignment.centerLeft,
                child: const Text("Account & Settings", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
              ),
              const SizedBox(height: 16),
             Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // --- 1. NOTIFICATIONS ---
                    // --- 1. NOTIFICATIONS ---
_buildListTile(Icons.notifications_none, "Notifications", () {
  _openSettingsMenu(
    "Notifications",
    Icons.notifications_active,
    StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        // Read current state from our fetched profile, default to true/false if null
        bool isPushEnabled = _userProfile?['push_enabled'] ?? true; 
        bool isEmailEnabled = _userProfile?['email_enabled'] ?? false;
        bool isSaving = false; // To prevent spamming the database

        return Column(
          children: [
            SwitchListTile(
              title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Daily reminders and AI insight alerts"),
              value: isPushEnabled,
              activeColor: AppTheme.primaryColor,
              onChanged: isSaving ? null : (bool value) async {
                // 1. Update UI instantly for good UX
                setModalState(() => isPushEnabled = value);
                setState(() => _userProfile?['push_enabled'] = value); // Update parent state
                
                // 2. Save to Supabase
                setModalState(() => isSaving = true);
                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  await Supabase.instance.client
                      .from('user_profiles')
                      .update({'push_enabled': value})
                      .eq('user_id', userId!);
                } catch (e) {
                  debugPrint("Error updating push settings: $e");
                  // Revert UI if it fails
                  setModalState(() => isPushEnabled = !value);
                } finally {
                  setModalState(() => isSaving = false);
                }
              },
            ),
            SwitchListTile(
              title: const Text("Email Updates", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Weekly carbon footprint summaries"),
              value: isEmailEnabled,
              activeColor: AppTheme.primaryColor,
              onChanged: isSaving ? null : (bool value) async {
                setModalState(() => isEmailEnabled = value);
                setState(() => _userProfile?['email_enabled'] = value);

                setModalState(() => isSaving = true);
                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  await Supabase.instance.client
                      .from('user_profiles')
                      .update({'email_enabled': value})
                      .eq('user_id', userId!);
                } catch (e) {
                  debugPrint("Error updating email settings: $e");
                  setModalState(() => isEmailEnabled = !value);
                } finally {
                  setModalState(() => isSaving = false);
                }
              },
            ),
          ],
                            );
                          },
                        ),
                      );
                    }),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60),

                    // --- 2. DATA & PRIVACY ---
                    _buildListTile(Icons.security, "Data & Privacy", () {
                      _openSettingsMenu(
                        "Data & Privacy",
                        Icons.security,
                        Column(
                          children: [
                            const Text(
                              "Your carbon footprint data is encrypted. We never sell your data to third parties.",
                              style: TextStyle(color: Colors.black54, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: Icon(Icons.download, color: AppTheme.primaryColor),
                              title: const Text("Export My Data", style: TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: Add CSV export logic later
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Data export will be sent to your email.')),
                                );
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                              title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              onTap: () {
                                // TODO: Add Supabase delete user logic
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60),

                    // --- 3. HELP & SUPPORT ---
                    _buildListTile(Icons.help_outline, "Help & Support", () {
                      _openSettingsMenu(
                        "Help & Support",
                        Icons.help,
                        Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.email, color: AppTheme.primaryColor),
                              title: const Text("Email Support", style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text("support@carbonsense.com"),
                              onTap: () async {
                                // Make sure you import 'package:url_launcher/url_launcher.dart'; at the top of your file
                                // final Uri emailUri = Uri(scheme: 'mailto', path: 'support@carbonsense.com');
                                // if (await canLaunchUrl(emailUri)) {
                                //   await launchUrl(emailUri);
                                // }
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.public, color: AppTheme.primaryColor),
                              title: const Text("Visit FAQ Page", style: TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.open_in_new, size: 16),
                              onTap: () {
                                // Add your website link here
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI WIDGET COMPONENTS ---

  Widget _buildGridCard(String title, String value, IconData icon, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(isHighlight ? 0 : 0.15)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isHighlight ? Colors.white : AppTheme.primaryColor, size: 28),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: isHighlight ? Colors.white70 : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: isHighlight ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}