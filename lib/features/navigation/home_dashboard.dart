import 'dart:math';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/widgets/custom_drawer.dart';
import 'package:carbonsense/widgets/quick_start_guide_dialog.dart';
import 'package:carbonsense/features/activity/log_activity_screen.dart'; // 👈 Add your log form import
import 'package:carbonsense/features/activity/food_camera_screen.dart';
import 'dart:async'; // 👈 CRITICAL: Add this at the top for the live ticking timer!

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  double _netFootprint = 0.0;
  double _monthlyTarget = 1.0;
  double _progress = 0.0;
  bool _obProfile = false;
  bool _obGuide = false;
  bool _obFirstLog = false;
  String _username = 'Eco Warrior';
  // 🌟 NEW: Live-tracking properties for the weekly timer
  Timer? _weeklyCountdownTimer;
  String _timeLeftString = 'Loading timer...';
  // 🌟 NEW: Active lifestyle preference filter preset
  String _selectedPreset = 'All';

  bool get _showOnboarding => !(_obProfile && _obGuide && _obFirstLog);
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _loadUserGreetingName();
    _startWeeklyResetTimer();
    if (Supabase.instance.client.auth.currentUser != null) {
      _userId = Supabase.instance.client.auth.currentUser!.id;
      _initializeDashboard();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _weeklyCountdownTimer
        ?.cancel(); // ✂️ Stop the background clock when page closes
    super.dispose();
  }

  // ⏰ THE WEEKLY LIVE TIMER MOTOR
  void _startWeeklyResetTimer() {
    _updateCountdownString(); // Run once immediately on load

    // Refresh the string every single second
    _weeklyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCountdownString();
      }
    });
  }

  void _updateCountdownString() {
    final now = DateTime.now();

    // Find how many days until the upcoming Monday
    int daysUntilMonday = DateTime.monday - now.weekday;
    if (daysUntilMonday <= 0) {
      daysUntilMonday +=
          7; // If it's Monday today, the next reset is exactly 7 days away
    }

    // Pinpoint next Monday at exactly 12:00 AM Midnight
    final nextResetDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilMonday,
      0,
      0,
      0,
    );
    final difference = nextResetDate.difference(now);

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    setState(() {
      _timeLeftString = '${days}d ${hours}h ${minutes}m left';
    });
  }

  Future<void> _loadUserGreetingName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('user_profiles')
            .select('display_name')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null && response['display_name'] != null && mounted) {
          setState(() {
            _username = response['display_name'];
          });
        }
      }
    } catch (e) {
      debugPrint('Silent error grabbing dashboard profile name: $e');
    }
  }

  Future<void> _initializeDashboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _fetchUserProfile();
      await _fetchOrGenerateTasks();
      await _calculateNetFootprint();

      // 🌟 NEW: Validate onboarding data criteria automatically
      await _validateAutomatedOnboardingSteps();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validateAutomatedOnboardingSteps() async {
    try {
      final profileRes = await Supabase.instance.client
          .from('user_profiles')
          .select('avatar_url, ob_profile, ob_first_log')
          .eq('user_id', _userId)
          .maybeSingle();

      if (profileRes != null) {
        final String? avatarUrl = profileRes['avatar_url'];
        final bool currentObProfile = profileRes['ob_profile'] ?? false;
        final bool currentObFirstLog = profileRes['ob_first_log'] ?? false;

        // 1. Check Profile Picture Validation
        if (avatarUrl != null && avatarUrl.isNotEmpty && !currentObProfile) {
          await _updateOnboardingTask('ob_profile', false);
        }

        // 2. 🌟 FIXED: Check First Activity Log Validation directly
        if (!currentObFirstLog) {
          // Look inside the activity_logs table to see if they have at least 1 entry
          final logsCount = await Supabase.instance.client
              .from('activity_logs')
              .select('logged_at')
              .eq('user_id', _userId)
              .limit(1);

          if (logsCount.isNotEmpty) {
            // It found a log! Mark the onboarding step as completed.
            await _updateOnboardingTask('ob_first_log', false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error running automated onboarding validation: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    final response = await Supabase.instance.client
        .from('user_profiles')
        .select('monthly_co2_target, ob_profile, ob_guide, ob_first_log')
        .eq('user_id', _userId)
        .maybeSingle();

    if (mounted && response != null) {
      final target = (response['monthly_co2_target'] as num?)?.toDouble();
      _monthlyTarget = (target != null && target > 0) ? target : 1.0;
      _obProfile = response['ob_profile'] as bool? ?? false;
      _obGuide = response['ob_guide'] as bool? ?? false;
      _obFirstLog = response['ob_first_log'] as bool? ?? false;
    }
  }

  Future<void> _fetchOrGenerateTasks() async {
    final now = DateTime.now();

    // 1. Find the exact start of the current week (Most recent Monday at 12:00 AM)
    int daysSinceMonday = now.weekday - DateTime.monday;
    if (daysSinceMonday < 0) daysSinceMonday += 7;
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day - daysSinceMonday,
      0,
      0,
      0,
    );

    // 2. Fetch the user's tasks from the database
    var response = await Supabase.instance.client
        .from('user_tasks')
        .select('*, tasks_dictionary(*)')
        .eq('user_id', _userId);

    bool needsRegeneration = false;

    if (response.isEmpty) {
      // User is brand new and has no tasks at all
      needsRegeneration = true;
    } else {
      // Check the first task's timestamp to see if it belongs to an old week
      final firstTaskTimestamp =
          response.first['created_at']; // or 'assigned_at'
      if (firstTaskTimestamp != null) {
        final taskCreationDate = DateTime.parse(firstTaskTimestamp).toLocal();

        if (taskCreationDate.isBefore(startOfThisWeek)) {
          // 🚨 THE WEEK HAS TRIPPED! These tasks are stale.
          needsRegeneration = true;

          debugPrint("📆 Stale weekly tasks detected. Clearing old records...");
          // Clean out the old week's tasks so they don't pile up in the DB
          await Supabase.instance.client
              .from('user_tasks')
              .delete()
              .eq('user_id', _userId);
        }
      }
    }

    // 3. Trigger the generator if the user is new OR the week has rolled over
    if (needsRegeneration) {
      debugPrint("⚡ Running generate_smart_tasks RPC for the new week...");
      await Supabase.instance.client.rpc(
        'generate_smart_tasks',
        params: {'current_user_id': _userId},
      );

      // Re-fetch the freshly minted weekly tasks
      response = await Supabase.instance.client
          .from('user_tasks')
          .select('*, tasks_dictionary(*)')
          .eq('user_id', _userId);
    }

    if (mounted) {
      setState(() => _tasks = List<Map<String, dynamic>>.from(response));
    }
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

    final totalEmissions = emissionsResponse.fold<double>(
      0.0,
      (sum, item) => sum + (item['total_co2e'] ?? 0.0),
    );

    final savedResponse = await Supabase.instance.client
        .from('user_tasks')
        .select('tasks_dictionary(co2_saved_estimate)')
        .eq('user_id', _userId)
        .eq('is_completed', true)
        .gte('completed_at', startOfMonth.toIso8601String())
        .lte('completed_at', endOfMonth.toIso8601String());

    final totalSaved = savedResponse.fold<double>(0.0, (sum, item) {
      final taskData = item['tasks_dictionary'];
      if (taskData != null)
        return sum + double.parse(taskData['co2_saved_estimate'].toString());
      return sum;
    });

    if (mounted) {
      setState(() {
        _netFootprint = max(0, totalEmissions - totalSaved);
        _progress = min(1.0, max(0.0, _netFootprint / _monthlyTarget));
      });
    }
  }

  // 📊 FETCH RAW MONTHLY DATA FOR THE MODAL (Upgraded with relational join)
  Future<Map<String, List<dynamic>>> _fetchMonthlyBreakdownData() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      0,
      23,
      59,
      59,
    ).toIso8601String();

    // 🌟 THE FIX: We use a relational join to pull the category and name from emission_factors!
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

  // 🎨 DYNAMIC ICON MATCHER FOR ACTIVITIES
  IconData _getIconForActivity(String category, String activityName) {
    final lowerName = activityName.toLowerCase();

    if (category == 'Transport') {
      if (lowerName.contains('motorcycle') || lowerName.contains('tricycle'))
        return Icons.two_wheeler;
      if (lowerName.contains('jeepney') || lowerName.contains('bus'))
        return Icons.directions_bus;
      if (lowerName.contains('lrt') ||
          lowerName.contains('mrt') ||
          lowerName.contains('train'))
        return Icons.train;
      if (lowerName.contains('bicycle') || lowerName.contains('walk'))
        return Icons.directions_walk;
      return Icons.directions_car; // Default for cars
    } else if (category == 'Energy') {
      if (lowerName.contains('water')) return Icons.water_drop;
      if (lowerName.contains('lpg') || lowerName.contains('gas'))
        return Icons.local_fire_department;
      return Icons.electric_bolt; // Default for grid electricity
    } else if (category == 'Diet') {
      return Icons.restaurant; // Default for all meals
    } else if (category == 'Lifestyle') {
      if (lowerName.contains('waste') || lowerName.contains('landfill'))
        return Icons.delete_outline;
      return Icons.eco;
    }

    return Icons.cloud_upload; // Fallback
  }

  // 🚀 SHOW THE MODAL (Upgraded parsing logic)
  void _openMonthlyBreakdownSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Monthly Footprint Breakdown",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Your emissions vs. savings for this month.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: FutureBuilder<Map<String, List<dynamic>>>(
                  future: _fetchMonthlyBreakdownData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          "Failed to load breakdown.",
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final logs = snapshot.data!['logs']!;
                    final tasks = snapshot.data!['tasks']!;

                    if (logs.isEmpty && tasks.isEmpty) {
                      return const Center(
                        child: Text(
                          "No activity logged this month yet.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- EMISSIONS SECTION ---
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Emissions Logged (${logs.length})",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (logs.isEmpty)
                              const Text(
                                "No emissions logged.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ...logs.map((log) {
                              // 🌟 THE FIX: Dig into the joined emission_factors object!
                              final factorData = log['emission_factors'] ?? {};
                              final activityName =
                                  factorData['activity_name'] ??
                                  'Custom Logged Activity';
                              final category =
                                  factorData['category'] ?? 'General';

                              final co2e = (log['total_co2e'] as num)
                                  .toStringAsFixed(1);
                              final dateStr = log['logged_at'] != null
                                  ? log['logged_at'].toString().split('T').first
                                  : '';
                              // 👇 Call our new helper function here!
                              final dynamicIcon = _getIconForActivity(
                                category,
                                activityName,
                              );

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade50,
                                  child: Icon(
                                    dynamicIcon,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                ), // 👈 Placed here
                                title: Text(
                                  activityName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '$category • $dateStr',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  "+$co2e kg",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 32),

                            // --- SAVINGS SECTION ---
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_down,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Completed Tasks (${tasks.length})",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (tasks.isEmpty)
                              const Text(
                                "No tasks completed.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ...tasks.map((task) {
                              final details = task['tasks_dictionary'] ?? {};
                              final desc =
                                  details['description'] ?? 'Unnamed Task';
                              final co2Saved =
                                  (details['co2_saved_estimate'] as num?)
                                      ?.toStringAsFixed(1) ??
                                  '0.0';
                              final dateStr = task['completed_at'] != null
                                  ? task['completed_at']
                                        .toString()
                                        .split('T')
                                        .first
                                  : '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade50,
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  desc,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  "-$co2Saved kg",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green,
                                  ),
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

  Future<void> _updateTaskStatus(String userTaskId, bool isCompleted) async {
    try {
      final taskIndex = _tasks.indexWhere(
        (t) => t['user_task_id'] == userTaskId,
      );
      if (taskIndex == -1) return;

      setState(() => _tasks[taskIndex]['is_completed'] = isCompleted);

      await Supabase.instance.client
          .from('user_tasks')
          .update({
            'is_completed': isCompleted,
            'completed_at': isCompleted
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('user_task_id', userTaskId);

      await _calculateNetFootprint();
    } catch (error) {
      final taskIndex = _tasks.indexWhere(
        (t) => t['user_task_id'] == userTaskId,
      );
      if (taskIndex != -1)
        setState(() => _tasks[taskIndex]['is_completed'] = !isCompleted);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $error')));
    }
  }

  Future<void> _updateOnboardingTask(String column, bool currentValue) async {
    final newValue = !currentValue;
    setState(() {
      if (column == 'ob_profile') _obProfile = newValue;
      if (column == 'ob_guide') _obGuide = newValue;
      if (column == 'ob_first_log') _obFirstLog = newValue;
    });

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({column: newValue})
          .eq('user_id', _userId);
    } catch (e) {
      setState(() {
        if (column == 'ob_profile') _obProfile = currentValue;
        if (column == 'ob_guide') _obGuide = currentValue;
        if (column == 'ob_first_log') _obFirstLog = currentValue;
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save progress.')));
    }
  }

  // 🚀 LIFESTYLE SELECTION SHEET (FIXED FOR OVERFLOW)
  void _openLifestyleCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // 👈 1. Allows the sheet to expand dynamically beyond default limits
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: SafeArea(
            child: SingleChildScrollView(
              // 👈 2. Makes the layout scrollable on smaller mobile displays
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Lifestyle Presets',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your mission queue to match your daily routine.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildPresetTile(
                    sheetContext,
                    'All',
                    Icons.public,
                    'Balanced Eco',
                    'Display every available global environmental mission.',
                  ),
                  _buildPresetTile(
                    sheetContext,
                    'Energy',
                    Icons.bolt,
                    'Energy Saver',
                    'Prioritize tasks that lower home grid electricity draw.',
                  ),
                  _buildPresetTile(
                    sheetContext,
                    'Commute',
                    Icons.directions_bus,
                    'Eco Commuter',
                    'Focus on low-emission transit and sharing rides.',
                  ),
                  _buildPresetTile(
                    sheetContext,
                    'Diet',
                    Icons.restaurant,
                    'Green Foodie',
                    'Focus on plant-based goals and zero food waste.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetTile(
    BuildContext sheetCtx,
    String presetKey,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final bool isCurrent = _selectedPreset == presetKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppTheme.primaryColor.withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() => _selectedPreset = presetKey);
          Navigator.pop(sheetCtx);
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrent ? AppTheme.primaryColor : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isCurrent ? Colors.white : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: isCurrent
            ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      drawer: const CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              'CarbonSense',
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        // 🌟 NEW: Permanent help button in the top right corner!
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.primaryColor),
            tooltip: 'Quick Start Guide',
            onPressed: () => showQuickStartGuideDialog(
              context,
            ), // 🔓 Opens instantly as reference tool!
          ),
          const SizedBox(width: 12), // Elegant spacing padding
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _initializeDashboard,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),

                                // ⏳ THE MODERN COUNTDOWN BADGE
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hourglass_top_rounded,
                                        size: 13,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _timeLeftString,
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // FILTER CHIP SELECTION ACCESSBAR
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Focus: $_selectedPreset Layout',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _openLifestyleCustomizationSheet,
                                  icon: const Icon(
                                    Icons.tune,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  label: Text(
                                    _selectedPreset == 'All'
                                        ? 'Customize'
                                        : _selectedPreset,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    backgroundColor: AppTheme.primaryColor
                                        .withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "WELCOME BACK",
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Hello, $_username 👋",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Here is your environmental status checkpoint.",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingCard() {
    if (!_showOnboarding) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
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
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 👤 STEP 1: Complete Profile (Guides them to wherever they upload an avatar)
          _buildOnboardingTile(
            "Complete your profile (Upload a picture)",
            _obProfile,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Navigate to your Profile settings screen to upload a picture!',
                ),
              ),
            ),
          ),

          // 📖 STEP 2: Open the Quick Start Guide Modal Popup
          _buildOnboardingTile(
            "Read the Quick Start Guide",
            _obGuide,
            () => showQuickStartGuideDialog(
              context,
              isOnboarding: !_obGuide, // 🔒 Lock it if onboarding is incomplete
              onComplete: () async {
                if (!_obGuide) {
                  await _updateOnboardingTask('ob_guide', _obGuide);
                }
              },
            ),
          ),

          // 🚗 STEP 3: Log First Activity Shortcut
          _buildOnboardingTile(
            "Log your first activity",
            _obFirstLog,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Use the Quick Log strips or Activity screens to input telemetry.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingTile(String title, bool isDone, VoidCallback onTap) {
    return InkWell(
      onTap: isDone
          ? null
          : onTap, // If it's already completed, make it static and unclickable
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.circle_outlined,
              color: isDone ? AppTheme.primaryColor : Colors.grey.shade400,
            ),
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

  Widget _buildImpactHeroCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openMonthlyBreakdownSheet, // 👈 Triggers the new modal!
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Net Footprint",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
                    _netFootprint.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "kg CO₂e",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Monthly Target: ${_monthlyTarget.toStringAsFixed(0)} kg",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    "${(_progress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),

              // 👇 NEW: Small indicator to let the user know they can interact with the card
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text(
                        "Tap to view breakdown",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
        // 💡 CRITICAL: Ensure 'Energy', 'Transportation', and 'Diet' match the exact
        // spelling and casing of the 'category' column values inside your Supabase table!
        _buildModernActionButton(Icons.lightbulb_outline, 'Energy', 'Energy'),
        _buildModernActionButton(Icons.commute, 'Transport', 'Transport'),
        _buildModernActionButton(Icons.restaurant, 'Diet', 'Diet'),
      ],
    );
  }

  Widget _buildModernActionButton(
    IconData icon,
    String label,
    String categoryKey,
  ) {
    return GestureDetector(
      onTap: () {
        if (categoryKey == 'Diet') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FoodCameraScreen()),
          ).then((_) {
            _initializeDashboard();
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogActivityScreen(category: categoryKey),
            ),
          ).then((_) {
            _initializeDashboard();
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
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 UPGRADED DYNAMIC RE-FILTERING TASKS ENGINE
  Widget _buildModernTasksList() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "All tasks completed or none generated! Tap refresh.",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    // 🔥 SMART FILTER PIPELINE: Filters database models cleanly based on active layout presets
    final filteredTasks = _tasks.where((task) {
      final taskDetails =
          task['tasks_dictionary'] as Map<String, dynamic>? ?? {};
      final tag = taskDetails['target_lifestyle_tag'] ?? 'General';

      if (_selectedPreset == 'All') return true;
      if (_selectedPreset == 'Energy' && tag == 'Energy') return true;
      if (_selectedPreset == 'Commute' && tag == 'Commute') return true;
      if (_selectedPreset == 'Diet' && tag == 'Diet') return true;

      // Always include 'General' tier checklist prompts as global foundations!
      return tag == 'General';
    }).toList();

    if (filteredTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No ongoing tasks under the "$_selectedPreset" focus.',
            style: const TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
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
        final taskDetails =
            task['tasks_dictionary'] as Map<String, dynamic>? ?? {};
        final userTaskId = task['user_task_id'] as String;
        final isCompleted = task['is_completed'] as bool? ?? false;
        final description = taskDetails['description'] ?? 'Unnamed Task';
        final tier = taskDetails['tier'] ?? 'Standard';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppTheme.primaryColor.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCompleted
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Colors.transparent,
            ),
            boxShadow: isCompleted
                ? []
                : [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            title: Text(
              description,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isCompleted ? Colors.grey : Colors.black87,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'TIER: ${tier.toUpperCase()}',
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            value: isCompleted,
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onChanged: (bool? value) {
              if (value != null) _updateTaskStatus(userTaskId, value);
            },
          ),
        );
      },
    );
  }
}
