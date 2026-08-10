import 'dart:math';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/widgets/quick_start_guide_dialog.dart';
import 'package:carbonsense/features/activity/mission_camera_screen.dart';
import 'package:go_router/go_router.dart'; // 👈 Add this import!
import 'package:carbonsense/services/notification_service.dart';
import 'package:carbonsense/features/utils/global_provider.dart';
import 'package:carbonsense/features/utils/formatters.dart'; // 🌟 Using global precision formatters
import 'dart:async';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  bool _isLoading = true;
  double _netFootprint = 0.0;

  // 🌟 Live-tracking properties for the weekly timer
  Timer? _weeklyCountdownTimer;
  String _timeLeftString = 'Loading timer...';

  // 🌟 Active lifestyle preference filter preset
  String _selectedPreset = 'All';
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _startWeeklyResetTimer();
    if (Supabase.instance.client.auth.currentUser != null) {
      _userId = Supabase.instance.client.auth.currentUser!.id;

      // Initialize notifications immediately on login/app open
      NotificationService().initNotifications();

      _initializeDashboard(showLoader: true);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _weeklyCountdownTimer?.cancel();
    super.dispose();
  }

  // ⏰ THE WEEKLY LIVE TIMER MOTOR
  void _startWeeklyResetTimer() {
    _updateCountdownString();

    _weeklyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCountdownString();
      }
    });
  }

  void _updateCountdownString() {
    final now = DateTime.now();

    int daysUntilMonday = DateTime.monday - now.weekday;
    if (daysUntilMonday <= 0) {
      daysUntilMonday += 7;
    }

    final nextResetDate = DateTime(now.year, now.month, now.day + daysUntilMonday, 0, 0, 0);
    final difference = nextResetDate.difference(now);

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    setState(() {
      _timeLeftString = '${days}d ${hours}h ${minutes}m left';
    });
  }

  // 🌅 Dynamic Time of Day Watermark Icon Helper
  IconData _getTimeOfDayWatermarkIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return Icons.wb_twilight; // Morning
    } else if (hour < 17) {
      return Icons.wb_sunny_rounded; // Afternoon
    } else {
      return Icons.nights_stay_rounded; // Evening
    }
  }

  Future<void> _initializeDashboard({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await Future.wait([_fetchOrGenerateTasks(), _calculateNetFootprint(), _validateAutomatedOnboardingSteps()]);
    } catch (e) {
      debugPrint('Error initializing dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _validateAutomatedOnboardingSteps() async {
    try {
      final profileRes = await Supabase.instance.client.from('user_profiles').select('avatar_url, ob_profile, ob_first_log').eq('user_id', _userId).maybeSingle();

      if (profileRes != null) {
        final String? avatarUrl = profileRes['avatar_url'];
        final bool currentObProfile = profileRes['ob_profile'] ?? false;
        final bool currentObFirstLog = profileRes['ob_first_log'] ?? false;

        if (avatarUrl != null && avatarUrl.isNotEmpty && !currentObProfile) {
          await _updateOnboardingTask('ob_profile', currentObProfile);
        }

        if (!currentObFirstLog) {
          final logsCount = await Supabase.instance.client.from('activity_logs').select('logged_at').eq('user_id', _userId).limit(1);

          if (logsCount.isNotEmpty) {
            await _updateOnboardingTask('ob_first_log', currentObFirstLog);
          }
        }
      }
    } catch (e) {
      debugPrint('Error running automated onboarding validation: $e');
    }
  }

  Future<void> _fetchOrGenerateTasks() async {
    final now = DateTime.now();

    int daysSinceMonday = now.weekday - DateTime.monday;
    if (daysSinceMonday < 0) daysSinceMonday += 7;
    final startOfThisWeek = DateTime(now.year, now.month, now.day - daysSinceMonday, 0, 0, 0);

    var response = await Supabase.instance.client.from('user_tasks').select('*, tasks_dictionary(*)').eq('user_id', _userId);

    bool needsRegeneration = false;

    if (response.isEmpty) {
      final user = Supabase.instance.client.auth.currentUser;

      int accountAgeDays = 0;
      if (user?.createdAt != null) {
        final createdAt = DateTime.parse(user!.createdAt);
        accountAgeDays = DateTime.now().toUtc().difference(createdAt).inDays;
      }

      int logCount = 0;
      try {
        final logs = await Supabase.instance.client.from('activity_logs').select('logged_at').eq('user_id', _userId);
        logCount = logs.length;
      } catch (e) {
        debugPrint('Activity logs fetch notice: $e');
      }

      final int requiredLogs = 10;

      if (accountAgeDays >= 7 || logCount >= requiredLogs) {
        needsRegeneration = true;
      } else {
        debugPrint('⏳ User not yet eligible for missions. Age: $accountAgeDays days, Logs: $logCount/$requiredLogs');
      }
    } else {
      final firstTaskTimestamp = response.first['created_at'];
      if (firstTaskTimestamp != null) {
        final taskCreationDate = DateTime.parse(firstTaskTimestamp).toLocal();

        if (taskCreationDate.isBefore(startOfThisWeek)) {
          needsRegeneration = true;
          debugPrint("📆 Stale weekly tasks detected. Clearing old records...");
          await Supabase.instance.client.from('user_tasks').delete().eq('user_id', _userId);
        }
      }
    }

    if (needsRegeneration) {
      debugPrint("⚡ Running generate_smart_tasks RPC for the new week...");
      await Supabase.instance.client.rpc('generate_smart_tasks', params: {'current_user_id': _userId});
    }

    debugPrint("✅ Weekly task validation complete.");
  }

  Future<void> _calculateNetFootprint() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final emissionsResponse = await Supabase.instance.client
        .from('activity_logs')
        .select('total_co2e')
        .eq('user_id', _userId)
        .gte('logged_at', startOfMonth.toIso8601String())
        .lte('logged_at', endOfMonth.toIso8601String());

    final totalEmissions = emissionsResponse.fold<double>(0.0, (sum, item) => sum + (item['total_co2e'] ?? 0.0));

    final savedResponse = await Supabase.instance.client
        .from('user_tasks')
        .select('tasks_dictionary(co2_saved_estimate)')
        .eq('user_id', _userId)
        .eq('is_completed', true)
        .gte('completed_at', startOfMonth.toIso8601String())
        .lte('completed_at', endOfMonth.toIso8601String());

    final totalSaved = savedResponse.fold<double>(0.0, (sum, item) {
      final taskData = item['tasks_dictionary'];
      if (taskData != null) {
        return sum + double.parse(taskData['co2_saved_estimate'].toString());
      }
      return sum;
    });

    if (mounted) {
      setState(() {
        // 🌟 Allow negative numbers so saved CO2 > logged CO2 displays properly
        _netFootprint = totalEmissions - totalSaved;
      });
    }
  }

  Future<Map<String, List<dynamic>>> _fetchMonthlyBreakdownData() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

    final logsResponse = await Supabase.instance.client
        .from('activity_logs')
        .select('*, emission_factors(category, activity_name)')
        .eq('user_id', _userId)
        .gte('logged_at', startOfMonth)
        .lte('logged_at', endOfMonth)
        .order('logged_at', ascending: false);

    final tasksResponse = await Supabase.instance.client
        .from('user_tasks')
        .select('*, tasks_dictionary(*)')
        .eq('user_id', _userId)
        .eq('is_completed', true)
        .gte('completed_at', startOfMonth)
        .lte('completed_at', endOfMonth)
        .order('completed_at', ascending: false);

    return {'logs': logsResponse, 'tasks': tasksResponse};
  }

  IconData _getIconForActivity(String category, String activityName) {
    final lowerName = activityName.toLowerCase();

    if (category == 'Transport') {
      if (lowerName.contains('motorcycle') || lowerName.contains('tricycle')) {
        return Icons.two_wheeler;
      }
      if (lowerName.contains('jeepney') || lowerName.contains('bus')) {
        return Icons.directions_bus;
      }
      if (lowerName.contains('lrt') || lowerName.contains('mrt') || lowerName.contains('train')) {
        return Icons.train;
      }
      if (lowerName.contains('bicycle') || lowerName.contains('walk')) {
        return Icons.directions_walk;
      }
      return Icons.directions_car;
    } else if (category == 'Energy') {
      if (lowerName.contains('water')) return Icons.water_drop;
      if (lowerName.contains('lpg') || lowerName.contains('gas')) {
        return Icons.local_fire_department;
      }
      return Icons.electric_bolt;
    } else if (category == 'Diet') {
      return Icons.restaurant;
    } else if (category == 'Lifestyle') {
      if (lowerName.contains('waste') || lowerName.contains('landfill')) {
        return Icons.delete_outline;
      }
      return Icons.eco;
    }

    return Icons.cloud_upload;
  }

  void _openMonthlyBreakdownSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Monthly Footprint Breakdown", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(
                "Your emissions vs. savings for this month.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<Map<String, List<dynamic>>>(
                  future: _fetchMonthlyBreakdownData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("Failed to load breakdown.", style: TextStyle(color: Colors.red)),
                      );
                    }

                    final logs = snapshot.data!['logs']!;
                    final tasks = snapshot.data!['tasks']!;

                    if (logs.isEmpty && tasks.isEmpty) {
                      return const Center(
                        child: Text(
                          "No activity logged this month yet.",
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.trending_up, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Emissions Logged (${logs.length})",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (logs.isEmpty)
                              const Text(
                                "No emissions logged.",
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ...logs.map((log) {
                              final factorData = log['emission_factors'] ?? {};
                              final activityName = factorData['activity_name'] ?? 'Custom Logged Activity';
                              final category = factorData['category'] ?? 'General';

                              // 🌟 Updated to use global precision formatter
                              final co2e = formatFootprint(log['total_co2e'] as num?);
                              final dateStr = log['logged_at'] != null ? log['logged_at'].toString().split('T').first : '';
                              final dynamicIcon = _getIconForActivity(category, activityName);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade50,
                                  child: Icon(dynamicIcon, color: Colors.redAccent, size: 18),
                                ),
                                title: Text(
                                  activityName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('$category • $dateStr', style: const TextStyle(fontSize: 12)),
                                trailing: Text(
                                  "+$co2e kg",
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent),
                                ),
                              );
                            }),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                const Icon(Icons.trending_down, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Completed Tasks (${tasks.length})",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (tasks.isEmpty)
                              const Text(
                                "No tasks completed.",
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ...tasks.map((task) {
                              final details = task['tasks_dictionary'] ?? {};
                              final desc = details['description'] ?? 'Unnamed Task';

                              // 🌟 Updated to use global precision formatter
                              final co2Saved = formatFootprint(details['co2_saved_estimate'] as num?);
                              final dateStr = task['completed_at'] != null ? task['completed_at'].toString().split('T').first : '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade50,
                                  child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                ),
                                title: Text(
                                  desc,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                                trailing: Text(
                                  "-$co2Saved kg",
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateOnboardingTask(String column, bool currentValue) async {
    final newValue = !currentValue;
    try {
      await Supabase.instance.client.from('user_profiles').update({column: newValue}).eq('user_id', _userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save progress.')));
      }
    }
  }

  void _openLifestyleCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 24),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Lifestyle Presets', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your mission queue to match your daily routine.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  _buildPresetTile(sheetContext, 'All', Icons.public, 'Balanced Eco', 'Display every available global environmental mission.'),
                  _buildPresetTile(sheetContext, 'Energy', Icons.bolt, 'Energy Saver', 'Prioritize tasks that lower home grid electricity draw.'),
                  _buildPresetTile(sheetContext, 'Commute', Icons.directions_bus, 'Eco Commuter', 'Focus on low-emission transit and sharing rides.'),
                  _buildPresetTile(sheetContext, 'Diet', Icons.restaurant, 'Green Foodie', 'Focus on plant-based goals and zero food waste.'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetTile(BuildContext sheetCtx, String presetKey, IconData icon, String title, String subtitle) {
    final bool isCurrent = _selectedPreset == presetKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.primaryColor.withOpacity(0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? AppTheme.primaryColor.withOpacity(0.3) : Colors.transparent),
      ),
      child: ListTile(
        onTap: () {
          setState(() => _selectedPreset = presetKey);
          Navigator.pop(sheetCtx);
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: isCurrent ? AppTheme.primaryColor : Colors.grey.shade100, shape: BoxShape.circle),
          child: Icon(icon, color: isCurrent ? Colors.white : Colors.grey.shade600, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: isCurrent ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileStreamProvider);

    // 🌟 Check for errors or manual loading state first to prevent crashes
    if (profileAsync.hasError || _isLoading) {
      if (_isLoading) {
        return const Scaffold(
          backgroundColor: Color(0xFFF9FFF9),
          body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        );
      }

      // Modern offline error screen
      return Scaffold(
        backgroundColor: const Color(0xFFF9FFF9),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.grey.shade400, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    "Connection lost",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We couldn't connect to the server. Please check your internet connection and try again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(userProfileStreamProvider);
                      _initializeDashboard(showLoader: true);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Try Again"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 🌟 Main Dashboard UI
    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF9FFF9),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      ),
      error: (err, stack) => const SizedBox.shrink(), // Handled safely above by profileAsync.hasError
      data: (profile) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 🌟 Subtle Dynamic Background Watermark based on Time of Day
              Positioned(
                top: -30,
                right: -40,
                child: IgnorePointer(
                  child: Icon(
                    _getTimeOfDayWatermarkIcon(),
                    size: 260,
                    color: AppTheme.primaryColor.withOpacity(0.04), // Keeping original theme color with subtle opacity
                  ),
                ),
              ),

              // Main Content
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () => _initializeDashboard(showLoader: false),
                  child: SingleChildScrollView(
                    // 🌟 Kept BouncingScrollPhysics but wrapped in AlwaysScrollable to ensure pull-to-refresh works even on short screens
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildOnboardingCard(),
                          _buildImpactHeroCard(),
                          const SizedBox(height: 32),
                          const Text(
                            "Quick Log",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          _buildActionStrip(),
                          const SizedBox(height: 32),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Weekly Missions",
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.hourglass_top_rounded, size: 13, color: Colors.amber.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          _timeLeftString,
                                          style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Focus: $_selectedPreset Layout',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  TextButton.icon(
                                    onPressed: _openLifestyleCustomizationSheet,
                                    icon: const Icon(Icons.tune, size: 16, color: AppTheme.primaryColor),
                                    label: Text(
                                      _selectedPreset == 'All' ? 'Customize' : _selectedPreset,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildModernTasksList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = "GOOD MORNING";
    } else if (hour < 17) {
      greeting = "GOOD AFTERNOON";
    } else {
      greeting = "GOOD EVENING";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2.0),
        ),
        const SizedBox(height: 6),
        Text(
          "Let's make an impact today",
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Colors.grey.shade900),
        ),
        const SizedBox(height: 4),
        Text(
          "Here is your environmental status checkpoint.",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildOnboardingCard() {
    final profile = ref.watch(userProfileStreamProvider).value;
    final obProfile = profile?['ob_profile'] ?? false;
    final obGuide = profile?['ob_guide'] ?? false;
    final obFirstLog = profile?['ob_first_log'] ?? false;

    final showOnboarding = !(obProfile && obGuide && obFirstLog);

    if (!showOnboarding) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rocket_launch, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                "GETTING STARTED",
                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOnboardingTile(
            "Complete your profile (Upload a picture)",
            obProfile,
            () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to your Profile settings screen to upload a picture!'))),
          ),
          _buildOnboardingTile(
            "Read the Quick Start Guide",
            obGuide,
            () => showQuickStartGuideDialog(
              context,
              isOnboarding: !obGuide,
              onComplete: () async {
                if (!obGuide) {
                  await _updateOnboardingTask('ob_guide', obGuide);
                }
              },
            ),
          ),
          _buildOnboardingTile(
            "Log your first activity",
            obFirstLog,
            () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use the Quick Log strips or Activity screens to input telemetry.'))),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingTile(String title, bool isDone, VoidCallback onTap) {
    return InkWell(
      onTap: isDone ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? AppTheme.primaryColor : Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                  color: isDone ? Colors.black87 : Colors.black54,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 Hero card with support for negative net footprints
  Widget _buildImpactHeroCard() {
    final profile = ref.watch(userProfileStreamProvider).value;
    final targetRaw = profile?['monthly_co2_target'];
    final monthlyTarget = (targetRaw != null && targetRaw > 0) ? (targetRaw as num).toDouble() : 1.0;

    // 🌟 States: Exceeded target vs Net Negative (Carbon Positive status)
    final bool isExceeded = _netFootprint > monthlyTarget;
    final bool isNegative = _netFootprint < 0;
    final double excessAmount = _netFootprint - monthlyTarget;

    // Clamp progress between 0.0 and 1.0 safely
    final progress = isNegative ? 0.0 : min(1.0, max(0.0, _netFootprint / monthlyTarget));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openMonthlyBreakdownSheet,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Net Footprint",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Icon(Icons.eco, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatFootprint(_netFootprint), // 🌟 Formats positive (+2.500) or negative (-5.000) correctly
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "kg CO₂e",
                    style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Monthly Target: ${monthlyTarget.toStringAsFixed(0)} kg", style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Text(
                    "${(_netFootprint / monthlyTarget * 100).toStringAsFixed(0)}%",
                    style: TextStyle(color: isExceeded ? Colors.redAccent.shade100 : (isNegative ? Colors.greenAccent.shade100 : Colors.white), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(isExceeded ? Colors.redAccent : Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    // 🌟 1. Dynamic Exceeded Warning Message
                    if (isExceeded) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "Target exceeded by ${excessAmount.toStringAsFixed(1)} kg",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 🌟 2. Dynamic Net Carbon Negative Badge
                    if (isNegative) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "Net Negative! You've offset ${formatFootprint(_netFootprint.abs())} kg",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Existing tap action chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: Colors.white70, size: 14),
                          SizedBox(width: 6),
                          Text(
                            "Tap to view breakdown",
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionStrip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildModernActionButton(Icons.lightbulb_outline, 'Energy', 'Energy'),
        _buildModernActionButton(Icons.commute, 'Transport', 'Transport'),
        _buildModernActionButton(Icons.restaurant, 'Diet', 'Diet'),
      ],
    );
  }

  // home_dashboard.dart

  Widget _buildModernActionButton(IconData icon, String label, String categoryKey) {
    return GestureDetector(
      onTap: () {
        if (categoryKey == 'Diet') {
          context.pushNamed('food-scanner').then((_) {
            _initializeDashboard(showLoader: false);
          });
        } else if (categoryKey == 'Energy') {
          context.pushNamed('bill-scanner').then((_) {
            _initializeDashboard(showLoader: false);
          });
        } else {
          // 🌟 Replaced Navigator.push with context.pushNamed
          context.pushNamed('log-activity', extra: categoryKey).then((_) {
            _initializeDashboard(showLoader: false);
          });
        }
      },
      child: Column(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 6))],
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTasksList() {
    final tasksAsync = ref.watch(userTasksStreamProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.grey.shade400, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Connection lost",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "We couldn't load your tasks right now. Please check your internet connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Establishing your activity baseline. Log some activities or wait 7 days to unlock your personalized weekly missions!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13, height: 1.4),
              ),
            ),
          );
        }

        final filteredTasks = tasks.where((task) {
          final taskDetails = task['tasks_dictionary'] as Map<String, dynamic>? ?? {};
          final tag = taskDetails['target_lifestyle_tag'] ?? 'General';

          if (_selectedPreset == 'All') return true;
          if (_selectedPreset == 'Energy' && tag == 'Energy') return true;
          if (_selectedPreset == 'Commute' && tag == 'Commute') return true;
          if (_selectedPreset == 'Diet' && tag == 'Diet') return true;

          return tag == 'General';
        }).toList();

        if (filteredTasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No ongoing tasks under the "$_selectedPreset" focus.',
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredTasks.length,
          itemBuilder: (context, index) {
            final task = filteredTasks[index];
            final taskDetails = task['tasks_dictionary'] as Map<String, dynamic>? ?? {};
            final userTaskId = task['user_task_id'] as String;
            final isCompleted = task['is_completed'] as bool? ?? false;
            final description = taskDetails['description'] ?? 'Unnamed Task';
            final tier = taskDetails['tier']?.toString() ?? 'Standard';
            final visionCriteria = taskDetails['vision_criteria'] ?? '';

            final tag = taskDetails['target_lifestyle_tag']?.toString() ?? 'General';

            // 🌟 2. Determine Tier Colors and Nature Elements
            Color tierMainColor;
            Color tierLightColor;
            IconData natureWatermark;

            switch (tier.toLowerCase()) {
              case 'gold':
                tierMainColor = Colors.amber.shade600;
                tierLightColor = Colors.amber.shade50;
                natureWatermark = Icons.wb_sunny_rounded; // Sun representing high tier
                break;
              case 'silver':
                tierMainColor = Colors.blueGrey.shade400;
                tierLightColor = Colors.blueGrey.shade50;
                natureWatermark = Icons.water_drop_rounded; // Water element
                break;
              case 'bronze':
                tierMainColor = const Color(0xFFCD7F32); // Bronze/Earth color
                tierLightColor = const Color(0xFFFAF0E6);
                natureWatermark = Icons.eco_rounded; // Leaf/Earth element
                break;
              default:
                tierMainColor = AppTheme.primaryColor;
                tierLightColor = AppTheme.primaryColor.withOpacity(0.1);
                natureWatermark = Icons.local_florist_rounded;
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                // Add a subtle gradient depending on the tier if not completed
                gradient: isCompleted ? null : LinearGradient(colors: [Colors.white, tierLightColor.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                color: isCompleted ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isCompleted ? Colors.transparent : tierMainColor.withOpacity(0.3), width: 1.5),
                boxShadow: isCompleted ? [] : [BoxShadow(color: tierMainColor.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // 🌟 3. Beautiful Nature Watermark injected into the background
                    if (!isCompleted)
                      Positioned(
                        right: -15,
                        bottom: -15,
                        child: Icon(
                          natureWatermark,
                          size: 90,
                          color: tierMainColor.withOpacity(0.06), // Very subtle watermark
                        ),
                      ),

                    // 🌟 4. The actual list tile on top
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.only(left: 12, right: 20, top: 8, bottom: 8),
                      title: Text(
                        description,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isCompleted ? Colors.grey : Colors.black87, decoration: isCompleted ? TextDecoration.lineThrough : null),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.grey.shade200 : tierMainColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isCompleted ? Colors.transparent : tierMainColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(natureWatermark, size: 10, color: isCompleted ? Colors.grey.shade500 : tierMainColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    tier.toUpperCase(),
                                    style: TextStyle(color: isCompleted ? Colors.grey.shade600 : tierMainColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      value: isCompleted,
                      activeColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onChanged: (bool? value) async {
                        if (!isCompleted) {
                          final validationMethod = taskDetails['validation_method']?.toString() ?? 'telemetry';

                          if (validationMethod == 'vision') {
                            // 👇 Add 'rootNavigator: true' here
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (context) => MissionCameraScreen(taskDescription: description, visionCriteria: visionCriteria, userTaskId: userTaskId),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Log an activity under "$tag" to complete this mission!'), backgroundColor: AppTheme.primaryColor));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
