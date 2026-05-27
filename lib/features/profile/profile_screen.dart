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

      // THE SMART ONBOARDING CHECK
      if (profileResponse != null) {
        final rawLocation = profileResponse['avatar_url'];
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

  // Functional Bottom Sheet for the Settings Menu
  void _openSettingsMenu(String title, IconData icon, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, 
          ),
          child: SafeArea(
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
                      child: const Text('Cancel', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: _userProfile?['avatar_url'] != null 
                      ? NetworkImage("${_userProfile!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}") 
                      : null,
                  child: _userProfile?['avatar_url'] == null 
                      ? const Icon(Icons.person, size: 40, color: AppTheme.primaryColor)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              
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

              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Lifestyle Profile", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
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

              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Account & Settings", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
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
                    // --- SECURITY: CHANGE PASSWORD ---
                    _buildListTile(Icons.lock_outline, "Change Password", () {
                      // 👇 FIX: Controllers are now safely initialized OUTSIDE the builder
                      final formKey = GlobalKey<FormState>();
                      final currentPasswordController = TextEditingController();
                      final passwordController = TextEditingController();
                      final confirmController = TextEditingController();
                      bool isObscured = true;
                      bool isSaving = false;

                      _openSettingsMenu(
                        "Change Password",
                        Icons.lock_reset,
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setModalState) {
                            return Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Password Requirements:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                        SizedBox(height: 8),
                                        Text("• Minimum of 6 characters", style: TextStyle(fontSize: 13, color: Colors.black54)),
                                        Text("• At least 1 uppercase letter", style: TextStyle(fontSize: 13, color: Colors.black54)),
                                        Text("• No special characters allowed", style: TextStyle(fontSize: 13, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  TextFormField(
                                    controller: currentPasswordController,
                                    obscureText: isObscured,
                                    decoration: InputDecoration(
                                      labelText: "Current Password",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: const Icon(Icons.password),
                                    ),
                                    validator: (value) => (value == null || value.isEmpty) ? 'Please enter your current password' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: isObscured,
                                    decoration: InputDecoration(
                                      labelText: "New Password",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setModalState(() => isObscured = !isObscured), // Safely updates UI now
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.length < 6) return 'Minimum 6 characters required';
                                      if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain at least 1 uppercase letter';
                                      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) return 'No special characters allowed';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: confirmController,
                                    obscureText: isObscured,
                                    decoration: InputDecoration(
                                      labelText: "Confirm New Password",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: const Icon(Icons.check_circle_outline),
                                    ),
                                    validator: (value) {
                                      if (value != passwordController.text) return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isSaving ? null : () async {
                                        if (formKey.currentState!.validate()) {
                                          setModalState(() => isSaving = true);
                                          try {
                                            final user = Supabase.instance.client.auth.currentUser;
                                            
                                            await Supabase.instance.client.auth.signInWithPassword(
                                              email: user!.email!,
                                              password: currentPasswordController.text,
                                            );

                                            await Supabase.instance.client.auth.updateUser(
                                              UserAttributes(password: passwordController.text),
                                            );
                                            
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppTheme.primaryColor),
                                              );
                                            }
                                          } on AuthException catch (e) {
                                            if (context.mounted) {
                                              String errorMsg = e.message;
                                              if (e.message.toLowerCase().contains("invalid login credentials")) {
                                                errorMsg = "Incorrect current password.";
                                              }
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
                                            }
                                          } finally {
                                            setModalState(() => isSaving = false);
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: isSaving 
                                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }),
                    Divider(height: 1, color: Colors.grey.shade100, indent: 60),

                    // --- DANGER ZONE: DELETE ACCOUNT ---
                    _buildListTile(Icons.delete_forever, "Delete Account", isDestructive: true, () {
                      // 👇 FIX: Controller declared outside builder
                      final confirmDeleteController = TextEditingController();
                      bool isDeleting = false;
                      bool isConfirmed = false;

                      _openSettingsMenu(
                        "Delete Account",
                        Icons.warning_amber_rounded,
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setModalState) {
                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: const Text(
                                    "WARNING: This action is permanent and cannot be undone. All of your activity logs, profile data, and AI prescriptions will be permanently erased.",
                                    style: TextStyle(color: Colors.red, height: 1.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // 👇 THE SAFETY LOCK TEXT FIELD 👇
                                TextField(
                                  controller: confirmDeleteController,
                                  decoration: InputDecoration(
                                    labelText: 'Type "DELETE" to confirm',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.red, width: 2),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      isConfirmed = (value == "DELETE");
                                    });
                                  },
                                ),
                                const SizedBox(height: 24),
                                
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    // Button is entirely disabled until 'isConfirmed' is true
                                    onPressed: (!isConfirmed || isDeleting) ? null : () async {
                                      setModalState(() => isDeleting = true);
                                      try {
  // 1. Get the current user's ID
  final myUserId = Supabase.instance.client.auth.currentUser!.id;

  // 🌟 2. Pass it into the RPC function to match your SQL setup
  await Supabase.instance.client.rpc(
    'delete_user_account', 
    params: {'target_user_id': myUserId},
  );
  
  // 3. Sign them out locally
  await Supabase.instance.client.auth.signOut();
  
  if (context.mounted) {
    Navigator.pop(context); // Close sheet
    context.go('/welcome'); // Kick to login
  }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red));
                                        }
                                      } finally {
                                        setModalState(() => isDeleting = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      disabledBackgroundColor: Colors.grey.shade300,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isDeleting 
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(
                                            'I understand, delete my account', 
                                            style: TextStyle(color: isConfirmed ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold)
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
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

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : AppTheme.primaryColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : Colors.black87, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}