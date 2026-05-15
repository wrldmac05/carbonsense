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
    if (commute.contains('Analyzing')) return Icons.sync; // Loading icon for the AI
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayName = _userProfile?['display_name'] ?? 'Eco Warrior';
    final location = _userProfile?['location'] ?? 'Location unknown';
    
    final rawBio = _userProfile?['bio'];
    final bool hasBio = rawBio != null && rawBio.toString().trim().isNotEmpty;
    final displayBio = hasBio 
        ? rawBio 
        : 'This patch of soil is currently untilled 🌱.\n\nEdit your profile to plant some seeds and share your eco-journey with the community!';
    
    // 🧠 The "Smart" Fallback Texts
    final dietType = _lifestyleProfile?['diet_type'] ?? 'Analyzing Logs...';
    final commuteType = _lifestyleProfile?['commute_type'] ?? 'Analyzing Logs...';
    final energyType = _lifestyleProfile?['home_energy_source'] ?? 'No Energy Set';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCompleteProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(location, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 24),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(
                      dietType.contains('Analyzing') ? Icons.sync : Icons.restaurant, 
                      dietType
                    ),
                    _buildBadge(_getIconForCommute(commuteType), commuteType),
                    _buildBadge(Icons.electrical_services, energyType),
                  ],
                ),
                const SizedBox(height: 32),

                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bio',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayBio, 
                          style: TextStyle(
                            height: 1.5, 
                            fontSize: 15,
                            color: hasBio ? Colors.black87 : Colors.grey.shade600, 
                            fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
                          )
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final didUpdate = await context.push('/edit-profile');
                      if (didUpdate == true) {
                        _fetchCompleteProfile();
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}