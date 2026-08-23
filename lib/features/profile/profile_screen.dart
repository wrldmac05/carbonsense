import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      final profileResponse = await Supabase.instance.client.from('user_profiles').select().eq('user_id', userId).maybeSingle();
      final lifestyleResponse = await Supabase.instance.client.from('lifestyle_profiles').select().eq('user_id', userId).maybeSingle();

      if (profileResponse != null) {
        final rawLocation = profileResponse['location'];
        final bool hasLocation = rawLocation != null && rawLocation.toString().trim().isNotEmpty;
        final bool isObProfileDone = profileResponse['ob_profile'] == true;

        if (hasLocation && !isObProfileDone) {
          await Supabase.instance.client.from('user_profiles').update({'ob_profile': true}).eq('user_id', userId);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: isDark ? Colors.white : AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
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
                        side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black54, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey;

    if (_isLoading) {
      return const ProfileSkeletonView();
    }

    final displayName = _userProfile?['display_name'] ?? 'Eco Warrior';
    final location = _userProfile?['location'] ?? 'Location not set';

    // Extract the Adaptive Target Goal
    final targetRaw = _userProfile?['monthly_co2_target'];
    final String monthlyTarget = targetRaw != null ? '${(targetRaw as num).toStringAsFixed(0)} kg CO₂e' : 'Not Set';

    final dietType = _lifestyleProfile?['diet_type'] ?? 'Analyzing...';
    final commuteType = _lifestyleProfile?['commute_type'] ?? 'Analyzing...';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _fetchCompleteProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
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
                  backgroundColor: isDark ? Colors.grey[800] : AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: _userProfile?['avatar_url'] != null ? NetworkImage("${_userProfile!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}") : null,
                  child: _userProfile?['avatar_url'] == null ? Icon(Icons.person, size: 40, color: isDark ? Colors.white : AppTheme.primaryColor) : null,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                displayName,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: textColor),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 16, color: subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    location,
                    style: TextStyle(fontSize: 15, color: subtitleColor, fontWeight: FontWeight.w500),
                  ),
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
                    backgroundColor: isDark ? Colors.white.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                    foregroundColor: isDark ? Colors.white : AppTheme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 40),

              // Full-Width Adaptive Goal Hero Card
              _buildHeroTargetCard(monthlyTarget),

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Lifestyle Profile",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
                ),
              ),
              const SizedBox(height: 16),

              // 2-Item Row below the Hero Card
              Row(
                children: [
                  Expanded(child: _buildGridCard("Diet", dietType, dietType.contains('Analyzing') ? Icons.sync : Icons.restaurant)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGridCard("Commute", commuteType, _getIconForCommute(commuteType))),
                ],
              ),
              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Account & Settings",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.grey[800]! : AppTheme.primaryColor.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // --- SECURITY: CHANGE PASSWORD ---
                    _buildListTile(Icons.lock_outline, "Change Password", () {
                      final formKey = GlobalKey<FormState>();
                      final currentPasswordController = TextEditingController();
                      final passwordController = TextEditingController();
                      final confirmController = TextEditingController();
                      bool isObscured = true;
                      bool isSaving = false;

                      String? currentPasswordApiError;

                      bool hasMinLength = false;
                      bool hasUppercase = false;
                      bool noSpecialChars = false;

                      Widget buildRequirement(String text, bool isMet) {
                        final reqTextColor = isMet ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.grey[400] : Colors.black54);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              Icon(isMet ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: isMet ? AppTheme.primaryColor : (isDark ? Colors.grey[600] : Colors.grey.shade400)),
                              const SizedBox(width: 8),
                              Text(
                                text,
                                style: TextStyle(fontSize: 13, fontWeight: isMet ? FontWeight.w600 : FontWeight.normal, color: reqTextColor),
                              ),
                            ],
                          ),
                        );
                      }

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
                                      color: isDark ? Colors.grey[850] : AppTheme.primaryColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Password Requirements:",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                        ),
                                        const SizedBox(height: 12),
                                        buildRequirement("Minimum of 6 characters", hasMinLength),
                                        buildRequirement("At least 1 uppercase letter", hasUppercase),
                                        buildRequirement("No special characters allowed", noSpecialChars),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  TextFormField(
                                    controller: currentPasswordController,
                                    obscureText: isObscured,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: "Current Password",
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[900] : Colors.transparent,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: const Icon(Icons.password),
                                    ),
                                    onChanged: (value) {
                                      if (currentPasswordApiError != null) {
                                        setModalState(() => currentPasswordApiError = null);
                                        formKey.currentState?.validate();
                                      }
                                    },
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter your current password';
                                      }
                                      if (currentPasswordApiError != null) {
                                        return currentPasswordApiError;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: isObscured,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: "New Password",
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[900] : Colors.transparent,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setModalState(() => isObscured = !isObscured)),
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        hasMinLength = value.length >= 6;
                                        hasUppercase = value.contains(RegExp(r'[A-Z]'));
                                        noSpecialChars = value.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value);
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a new password';
                                      }
                                      if (!hasMinLength) return 'Minimum 6 characters required';
                                      if (!hasUppercase) return 'Must contain at least 1 uppercase letter';
                                      if (!noSpecialChars) return 'No special characters allowed';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: confirmController,
                                    obscureText: isObscured,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: "Confirm New Password",
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[900] : Colors.transparent,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: const Icon(Icons.check_circle_outline),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please confirm your new password';
                                      }
                                      if (value != passwordController.text) {
                                        return 'New passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isSaving
                                          ? null
                                          : () async {
                                              if (formKey.currentState!.validate()) {
                                                setModalState(() => isSaving = true);
                                                try {
                                                  final user = Supabase.instance.client.auth.currentUser;

                                                  await Supabase.instance.client.auth.signInWithPassword(email: user!.email!, password: currentPasswordController.text);

                                                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: passwordController.text));

                                                  if (context.mounted) {
                                                    Navigator.pop(context);

                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => Dialog(
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(24.0),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.all(16),
                                                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                                                child: const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 64),
                                                              ),
                                                              const SizedBox(height: 24),
                                                              Text(
                                                                "Password Updated",
                                                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              Text(
                                                                "Your account password has been successfully changed. You can now use it on your next login.",
                                                                textAlign: TextAlign.center,
                                                                style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.5),
                                                              ),
                                                              const SizedBox(height: 32),
                                                              SizedBox(
                                                                width: double.infinity,
                                                                child: ElevatedButton(
                                                                  onPressed: () => Navigator.pop(context),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: AppTheme.primaryColor,
                                                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                  ),
                                                                  child: const Text(
                                                                    'Done',
                                                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } on AuthException catch (e) {
                                                  if (context.mounted) {
                                                    if (e.message.toLowerCase().contains("invalid login credentials")) {
                                                      setModalState(() {
                                                        currentPasswordApiError = "Incorrect current password.";
                                                      });
                                                      formKey.currentState!.validate();
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
                                                    }
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
                                          : const Text(
                                              'Update Password',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade100, indent: 60),

                    // --- DANGER ZONE: DELETE ACCOUNT ---
                    _buildListTile(Icons.delete_forever, "Delete Account", isDestructive: true, () {
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
                                    color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade200),
                                  ),
                                  child: const Text(
                                    "WARNING: This action is permanent and cannot be undone. All of your activity logs, profile data, and AI prescriptions will be permanently erased.",
                                    style: TextStyle(color: Colors.red, height: 1.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                TextField(
                                  controller: confirmDeleteController,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Type "DELETE" to confirm',
                                    labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
                                    filled: true,
                                    fillColor: isDark ? Colors.grey[900] : Colors.transparent,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      borderSide: BorderSide(color: Colors.red, width: 2),
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
                                    onPressed: (!isConfirmed || isDeleting)
                                        ? null
                                        : () async {
                                            setModalState(() => isDeleting = true);
                                            try {
                                              final myUserId = Supabase.instance.client.auth.currentUser!.id;

                                              await Supabase.instance.client.rpc('delete_user_account', params: {'target_user_id': myUserId});

                                              await Supabase.instance.client.auth.signOut();

                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                context.go('/welcome');
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
                                      disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey.shade300,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isDeleting
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(
                                            'I understand, delete my account',
                                            style: TextStyle(color: isConfirmed ? Colors.white : (isDark ? Colors.grey[600] : Colors.grey.shade500), fontWeight: FontWeight.bold),
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

  Widget _buildHeroTargetCard(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.track_changes, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                "Adaptive Carbon Goal",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          const Text("Target auto-adjusts monthly based on your telemetry.", style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildGridCard(String title, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.grey[800]! : AppTheme.primaryColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.06), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87);
    final iconBgColor = isDestructive ? Colors.red.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1));
    final iconColor = isDestructive ? Colors.red : (isDark ? Colors.white : AppTheme.primaryColor);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// 🌟 SKELETON LOADER WIDGETS

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({super.key, this.width, required this.height, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade300;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(borderRadius)),
    );
  }
}

class ProfileSkeletonView extends StatelessWidget {
  const ProfileSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final cardBg = isDark ? Colors.grey[850] : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(title: const SkeletonBox(width: 80, height: 20, borderRadius: 6), centerTitle: false, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
        child: ShimmerLoading(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Placeholder
              const SkeletonBox(width: 96, height: 96, borderRadius: 48),
              const SizedBox(height: 16),

              // Display Name
              const SkeletonBox(width: 150, height: 24, borderRadius: 6),
              const SizedBox(height: 8),

              // Location
              const SkeletonBox(width: 120, height: 16, borderRadius: 4),
              const SizedBox(height: 20),

              // Edit Profile Button
              const SkeletonBox(width: 160, height: 44, borderRadius: 12),
              const SizedBox(height: 40),

              // Adaptive Goal Hero Card
              const SkeletonBox(width: double.infinity, height: 160, borderRadius: 24),
              const SizedBox(height: 24),

              // Lifestyle Profile Header
              const Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 140, height: 18, borderRadius: 4)),
              const SizedBox(height: 16),

              // 2 Grid Cards
              Row(
                children: const [
                  Expanded(child: SkeletonBox(height: 110, borderRadius: 24)),
                  SizedBox(width: 16),
                  Expanded(child: SkeletonBox(height: 110, borderRadius: 24)),
                ],
              ),
              const SizedBox(height: 40),

              // Account & Settings Header
              const Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 160, height: 18, borderRadius: 4)),
              const SizedBox(height: 16),

              // Settings Container with 2 Tile Placeholders
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(children: const [SkeletonBox(width: 40, height: 40, borderRadius: 12), SizedBox(width: 16), SkeletonBox(width: 130, height: 16, borderRadius: 4)]),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade100),
                    const SizedBox(height: 16),
                    Row(children: const [SkeletonBox(width: 40, height: 40, borderRadius: 12), SizedBox(width: 16), SkeletonBox(width: 110, height: 16, borderRadius: 4)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
