import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_providers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// 🌟 Riverpod Provider to fetch Lifestyle Profile directly from Supabase
final lifestyleProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  final response = await Supabase.instance.client.from('lifestyle_profiles').select().eq('user_id', userId).maybeSingle();

  return response;
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedMonthIndex = DateTime.now().month - 1; // Defaults to current month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSmartSync();
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

  Future<void> _runSmartSync() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.functions.invoke('eco_coach', body: {'user_id': userId});
    } catch (e) {
      debugPrint("Silent Sync Error: $e");
    }
  }

  // 🌟 HELPER 1: Normalize category strings across casing & variations
  String _normalizeCategory(String? rawCategory) {
    if (rawCategory == null || rawCategory.trim().isEmpty) return 'General';
    final cat = rawCategory.trim().toLowerCase();

    if (cat.contains('transport') || cat.contains('commute') || cat.contains('travel') || cat.contains('car') || cat.contains('vehicle')) {
      return 'Transport';
    } else if (cat.contains('diet') || cat.contains('food') || cat.contains('meal') || cat.contains('eat')) {
      return 'Diet';
    } else if (cat.contains('energy') || cat.contains('electricity') || cat.contains('power') || cat.contains('utility')) {
      return 'Energy';
    }
    return 'General';
  }

  // 🌟 HELPER 2: Robust resolution for activity names with multiple fallbacks
  String _extractActivityName(Map<String, dynamic> log, Map<String, dynamic>? factorData) {
    if (log['food_name'] != null && log['food_name'].toString().trim().isNotEmpty) {
      return log['food_name'].toString();
    }
    if (factorData != null) {
      final name = factorData['activity_name'] ?? factorData['name'] ?? factorData['title'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }
    if (log['activity_name'] != null && log['activity_name'].toString().trim().isNotEmpty) {
      return log['activity_name'].toString();
    }
    if (log['title'] != null && log['title'].toString().trim().isNotEmpty) {
      return log['title'].toString();
    }
    return 'Activity Log';
  }

  List<double> _getYearlyData(List<Map<String, dynamic>> logs) {
    List<double> yearlyData = List.filled(12, 0.0);
    final currentYear = DateTime.now().year;

    for (var log in logs) {
      if (log['logged_at'] == null) continue;
      DateTime date = DateTime.parse(log['logged_at']);
      if (date.year == currentYear) {
        yearlyData[date.month - 1] += (log['total_co2e'] as num? ?? 0).toDouble();
      }
    }
    return yearlyData;
  }

  List<Map<String, dynamic>> _getMonthlyLogs(List<Map<String, dynamic>> logs) {
    final currentYear = DateTime.now().year;
    return logs.where((log) {
      if (log['logged_at'] == null) return false;
      DateTime date = DateTime.parse(log['logged_at']);
      return date.year == currentYear && date.month - 1 == _selectedMonthIndex;
    }).toList()..sort((a, b) => b['logged_at'].compareTo(a['logged_at']));
  }

  Map<String, double> _getCategoryTotals(List<Map<String, dynamic>> monthLogs) {
    final Map<String, double> categoryTotals = {'Transport': 0.0, 'Diet': 0.0, 'Energy': 0.0, 'General': 0.0};

    for (var log in monthLogs) {
      final factorData = log['emission_factors'] as Map<String, dynamic>?;
      final rawCategory = factorData?['category'] ?? log['category'];
      final category = _normalizeCategory(rawCategory?.toString());
      final co2 = (log['total_co2e'] as num? ?? 0).toDouble();

      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + co2;
    }

    return categoryTotals;
  }

  IconData _getIconForCategory(String? rawCategory) {
    final category = _normalizeCategory(rawCategory);
    if (category == 'Transport') return Icons.directions_car;
    if (category == 'Diet') return Icons.restaurant;
    if (category == 'Energy') return Icons.bolt;
    return Icons.eco;
  }

  Color _getColorForCategory(String? rawCategory) {
    final category = _normalizeCategory(rawCategory);
    switch (category) {
      case 'Transport':
        return Colors.blue.shade600;
      case 'Diet':
        return Colors.red.shade600;
      case 'Energy':
        return Colors.amber.shade700;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getCommuteIcon(String commute) {
    if (commute.contains('Transit')) return Icons.directions_transit;
    if (commute.contains('Cycling') || commute.contains('Walking')) return Icons.directions_bike;
    if (commute.contains('Motorcycle')) return Icons.two_wheeler;
    if (commute.contains('Analyzing')) return Icons.sync;
    return Icons.directions_car;
  }

  IconData _getDietIcon(String diet) {
    if (diet.contains('Plant') || diet.contains('Vegan')) return Icons.eco;
    if (diet.contains('Pescatarian')) return Icons.set_meal;
    if (diet.contains('Beef') || diet.contains('Meat')) return Icons.kebab_dining;
    if (diet.contains('Analyzing')) return Icons.sync;
    return Icons.restaurant;
  }

  // 📝 Helper to show detailed information when a log is tapped
  void _showLogDetails(Map<String, dynamic> log, Map<String, dynamic>? factorData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;

    final activityName = _extractActivityName(log, factorData);
    final rawCategory = factorData?['category'] ?? log['category'];
    final category = _normalizeCategory(rawCategory?.toString());
    final unit = factorData?['unit'] ?? log['unit'] ?? '';
    final inputValue = log['input_value']?.toString() ?? '0';

    String formatCo2(num? rawCo2) {
      if (rawCo2 == null || rawCo2 == 0) return '0.00';
      final double value = rawCo2.toDouble();
      if (value.abs() < 0.1) {
        return value.toStringAsFixed(4).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
      }
      return value.toStringAsFixed(2);
    }

    final totalCo2 = formatCo2(log['total_co2e'] as num?);
    final String? startLocation = log['start_location'];
    final String? endLocation = log['end_location'];
    final loggedAt = DateTime.parse(log['logged_at']).toLocal();
    final formattedTime = DateFormat('h:mm a, MMMM d, yyyy').format(loggedAt);
    final List<dynamic>? rawIngredients = log['ingredients'];
    final List<String> ingredients = rawIngredients?.map((e) => e.toString()).toList() ?? [];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _getColorForCategory(category).withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                      child: Icon(_getIconForCategory(category), color: _getColorForCategory(category), size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activityName,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                const SizedBox(height: 16),
                _buildDetailRow('Input Amount', '$inputValue $unit'),
                const SizedBox(height: 16),
                _buildDetailRow('Time Logged', formattedTime),
                const SizedBox(height: 24),
                if (category == 'Transport' && startLocation != null && endLocation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withOpacity(0.12) : Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRIP ROUTE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.trip_origin, size: 16, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                startLocation,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 7.0),
                          child: Container(height: 16, width: 2, color: Colors.blue.shade300),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.place, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                endLocation,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (ingredients.isNotEmpty) ...[
                  Text(
                    'Detected Ingredients',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ingredients
                        .map(
                          (ingredient) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade200),
                            ),
                            child: Text(
                              ingredient,
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[200] : Colors.grey.shade800, fontWeight: FontWeight.w500),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: _buildDetailRow('Carbon Footprint', '$totalCo2 kg CO₂', isHighlight: true),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.grey[400]! : Colors.grey.shade600;
    final valueColor = isHighlight ? (isDark ? Colors.white : AppTheme.primaryColor) : (isDark ? Colors.white : Colors.black87);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: isHighlight ? 18 : 16, fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Analytics",
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          "Review your real-time carbon mitigation insights.",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: subtitleColor),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);

    final logsAsync = ref.watch(activityLogsStreamProvider);
    final generalAiAsync = ref.watch(generalAiInsightProvider);
    final monthlyAiAsync = ref.watch(monthlyAiInsightProvider(_selectedMonthIndex));
    final lifestyleAsync = ref.watch(lifestyleProfileProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          Positioned(
            top: -30,
            right: -40,
            child: IgnorePointer(child: Icon(_getTimeOfDayWatermarkIcon(), size: 260, color: isDark ? Colors.white.withOpacity(0.03) : AppTheme.primaryColor.withOpacity(0.04))),
          ),
          SafeArea(
            bottom: false,
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, color: isDark ? Colors.grey[600] : Colors.grey.shade400, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        "Connection lost",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We couldn't load your analytics right now. Please check your internet connection and try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey.shade600, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(activityLogsStreamProvider);
                          ref.invalidate(generalAiInsightProvider);
                          ref.invalidate(monthlyAiInsightProvider);
                          ref.invalidate(lifestyleProfileProvider);
                          _runSmartSync();
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
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "Welcome to CarbonSense!\n\nLog your first activity today to wake up your personal AI Eco-Coach.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey, height: 1.5),
                      ),
                    ),
                  );
                }

                final yearlyData = _getYearlyData(logs);
                final totalYearlyImpact = yearlyData.fold(0.0, (sum, item) => sum + item);
                final selectedMonthImpact = yearlyData[_selectedMonthIndex];
                final monthLogs = _getMonthlyLogs(logs);
                final categoryTotals = _getCategoryTotals(monthLogs);

                return RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () async {
                    ref.invalidate(activityLogsStreamProvider);
                    ref.invalidate(generalAiInsightProvider);
                    ref.invalidate(monthlyAiInsightProvider);
                    ref.invalidate(lifestyleProfileProvider);
                    await _runSmartSync();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: Center(
                      // 🌟 RESPONSIVE WRAPPER: Constrains maximum width for web/tablets
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0), child: _buildHeader()),
                            const SizedBox(height: 12),

                            // 1. GENERAL AI INSIGHT
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                              child: generalAiAsync.when(
                                loading: () => Container(
                                  height: 120,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
                                  child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                                ),
                                error: (err, _) => const SizedBox.shrink(),
                                data: (text) => _buildAiCard("GENERAL ECO-COACH", text, isGeneral: true),
                              ),
                            ),

                            // 2. DETAILED LIFESTYLE PROFILE & IMPACT SECTION
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                              child: lifestyleAsync.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (lifestyle) => _buildDetailedLifestyleSection(lifestyle),
                              ),
                            ),

                            // 3. YEARLY OVERVIEW GRAPH
                            Padding(padding: const EdgeInsets.all(16.0), child: _buildYearlyChartCard(yearlyData, totalYearlyImpact)),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: Text(
                                "Monthly Deep Dive",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87),
                              ),
                            ),

                            // 4. MONTH SELECTOR
                            _buildMonthSelector(),

                            const SizedBox(height: 16),

                            // 5. MONTHLY SUMMARY & QUICK METRICS
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                children: [_buildMonthSummaryCard(selectedMonthImpact), const SizedBox(height: 12), _buildQuickMetricsGrid(selectedMonthImpact, monthLogs, categoryTotals)],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 6. CATEGORY BREAKDOWN PIE CHART
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildCategoryBreakdownCard(categoryTotals, selectedMonthImpact)),

                            const SizedBox(height: 16),

                            // 7. MONTHLY AI INSIGHT CARD
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: monthlyAiAsync.when(
                                loading: () => Container(
                                  height: 120,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
                                  child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                                ),
                                error: (err, _) => const SizedBox.shrink(),
                                data: (text) {
                                  if (_selectedMonthIndex == DateTime.now().month - 1) {
                                    text = "Activity tracking in progress... Your full AI summary will be generated on the 1st of next month!";
                                  }

                                  return _buildAiCard("${DateFormat('MMMM').format(DateTime(DateTime.now().year, _selectedMonthIndex + 1)).toUpperCase()} INSIGHT", text, isGeneral: false);
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 8. MONTHLY ACTIVITY LOGS LIST
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildMonthlyActivitySection(monthLogs)),

                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 🌟 RESPONSIVE LIFESTYLE PROFILE CARD (FIXES OVERFLOW ON IPHONE 12 MINI) ---

  Widget _buildDetailedLifestyleSection(Map<String, dynamic>? lifestyle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey.shade600;

    final dietType = lifestyle?['diet_type'] ?? 'Analyzing...';
    final commuteType = lifestyle?['commute_type'] ?? 'Analyzing...';

    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding slightly for small screens
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.psychology, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Lifestyle & Habit Profile",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 🌟 RESPONSIVE BADGE ROW (ADAPTS ON ULTRA-COMPACT SCREENS)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 340;
              if (isSmall) {
                return Column(
                  children: [
                    _buildHabitBadge("Diet Habit", dietType, _getDietIcon(dietType), Colors.red.shade600),
                    const SizedBox(height: 8),
                    _buildHabitBadge("Commute Habit", commuteType, _getCommuteIcon(commuteType), Colors.blue.shade600),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildHabitBadge("Diet Habit", dietType, _getDietIcon(dietType), Colors.red.shade600)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildHabitBadge("Commute Habit", commuteType, _getCommuteIcon(commuteType), Colors.blue.shade600)),
                ],
              );
            },
          ),

          const SizedBox(height: 14),
          Divider(color: isDark ? Colors.grey[800] : Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: subtitleColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "How this works: Your profile dynamically adapts based on smart analysis of your recent activity patterns. As your daily habits shift, your lifestyle tags update automatically.",
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: subtitleColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitBadge(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              // 🌟 FLEXIBLE TEXT PREVENTS RIGHT OVERFLOW
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- 🌟 ANIMATED AI COACH CARD ---

  Widget _buildAiCard(String title, String text, {required bool isGeneral}) {
    return AnimatedAiCard(title: title, text: text, isGeneral: isGeneral);
  }

  Widget _buildYearlyChartCard(List<double> data, double total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08), blurRadius: 25, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Year-to-Date Impact",
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${total.toStringAsFixed(1)} kg CO₂e",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1, color: textColor),
            ),
          ),
          const SizedBox(height: 24),
          _buildYearlyGraph(data),
        ],
      ),
    );
  }

  Widget _buildYearlyGraph(List<double> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = data.isEmpty ? 100.0 : (data.reduce((a, b) => a > b ? a : b) * 1.2);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 11,
          maxY: maxY == 0 ? 10 : maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: isDark ? Colors.grey[800]! : Colors.grey.withOpacity(0.1), strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (val, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Text(
                      val.toInt().toString(),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (val, _) {
                  final months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
                  int index = val.toInt();
                  if (index < 0 || index > 11) return const SizedBox.shrink();

                  bool isSelected = index == _selectedMonthIndex;
                  final selectedColor = isDark ? Colors.white : AppTheme.primaryColor;

                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      months[index],
                      style: TextStyle(color: isSelected ? selectedColor : (isDark ? Colors.grey[600] : Colors.grey), fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) => isDark ? Colors.grey[900]! : const Color(0xFF1A1A1A),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  return LineTooltipItem('${touchedSpot.y.toStringAsFixed(1)} kg\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                }).toList();
              },
            ),
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              if (event is FlTapUpEvent && touchResponse?.lineBarSpots != null) {
                final index = touchResponse!.lineBarSpots!.first.x.toInt();
                if (index >= 0 && index <= 11) {
                  setState(() => _selectedMonthIndex = index);
                }
              }
            },
            handleBuiltInTouches: true,
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: isDark ? Colors.white : AppTheme.primaryColor,
              barWidth: 3.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [(isDark ? Colors.white : AppTheme.primaryColor).withOpacity(0.2), (isDark ? Colors.white : AppTheme.primaryColor).withOpacity(0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: 12,
        itemBuilder: (context, index) {
          bool isSelected = index == _selectedMonthIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.grey[850] : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
              ),
              child: Center(
                child: Text(
                  months[index],
                  style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 13, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey.shade600)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSummaryCard(double impact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String monthName = DateFormat('MMMM').format(DateTime(DateTime.now().year, _selectedMonthIndex + 1));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$monthName Total Footprint",
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      "${impact.toStringAsFixed(1)} kg",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    if (impact > 0 && impact < 50)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                        child: const Text(
                          "Great!",
                          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.calendar_month, color: isDark ? Colors.white : AppTheme.primaryColor, size: 28),
        ],
      ),
    );
  }

  Widget _buildQuickMetricsGrid(double monthImpact, List<Map<String, dynamic>> monthLogs, Map<String, double> categoryTotals) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, _selectedMonthIndex + 1, 0).day;
    final daysToDivide = (_selectedMonthIndex == now.month - 1) ? now.day : daysInMonth;
    final dailyAvg = monthImpact / (daysToDivide == 0 ? 1 : daysToDivide);

    String topCategory = "None";
    double topCo2 = 0;
    categoryTotals.forEach((cat, co2) {
      if (co2 > topCo2) {
        topCo2 = co2;
        topCategory = cat;
      }
    });

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(title: "Daily Avg", value: "${dailyAvg.toStringAsFixed(1)} kg", icon: Icons.speed, color: Colors.blue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(title: "Logs Count", value: "${monthLogs.length}", icon: Icons.assignment_outlined, color: Colors.purple),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(title: "Top Source", value: topCategory, icon: _getIconForCategory(topCategory), color: _getColorForCategory(topCategory)),
        ),
      ],
    );
  }

  Widget _buildMetricTile({required String title, required String value, required IconData icon, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(Map<String, double> categoryTotals, double totalImpact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final List<PieChartSectionData> sections = [];

    categoryTotals.forEach((category, amount) {
      if (amount > 0) {
        final percentage = totalImpact > 0 ? (amount / totalImpact * 100) : 0.0;
        sections.add(
          PieChartSectionData(
            color: _getColorForCategory(category),
            value: amount,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 36,
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Category Share",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor),
          ),
          const SizedBox(height: 14),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text("No category data available for this month.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12)),
              ),
            )
          else
            Row(
              children: [
                SizedBox(height: 110, width: 110, child: PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 24, sections: sections))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: categoryTotals.entries.map((e) {
                      if (e.value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: _getColorForCategory(e.key), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.key,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "${e.value.toStringAsFixed(1)} kg",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyActivitySection(List<Map<String, dynamic>> monthLogs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Logged Activities",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: textColor),
            ),
            Text(
              "${monthLogs.length} items",
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        monthLogs.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.grey.shade50, borderRadius: BorderRadius.circular(18)),
                child: Center(
                  child: Text("No activities logged for this month.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12)),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthLogs.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade100, indent: 64),
                  itemBuilder: (context, index) {
                    final log = monthLogs[index];
                    final factorData = log['emission_factors'] as Map<String, dynamic>?;

                    final activityName = _extractActivityName(log, factorData);
                    final rawCategory = factorData?['category'] ?? log['category'];
                    final category = _normalizeCategory(rawCategory?.toString());
                    final unit = factorData?['unit'] ?? log['unit'] ?? '';
                    final inputValue = log['input_value']?.toString() ?? '0';
                    final totalCo2 = (log['total_co2e'] as num?)?.toStringAsFixed(2) ?? '0.00';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showLogDetails(log, factorData),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: _getColorForCategory(category).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                child: Icon(_getIconForCategory(category), color: _getColorForCategory(category), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activityName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$inputValue $unit',
                                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+$totalCo2',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _getColorForCategory(category)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'kg CO₂',
                                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey.shade500, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}

// 🌟 ANIMATED STATEFUL AI CARD WIDGET
class AnimatedAiCard extends StatefulWidget {
  final String title;
  final String text;
  final bool isGeneral;

  const AnimatedAiCard({super.key, required this.title, required this.text, required this.isGeneral});

  @override
  State<AnimatedAiCard> createState() => _AnimatedAiCardState();
}

class _AnimatedAiCardState extends State<AnimatedAiCard> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = widget.isGeneral ? (isDark ? Colors.grey[850]! : Colors.white) : const Color(0xFF1A1A1A);
    final cardTextColor = widget.isGeneral ? (isDark ? Colors.white : Colors.black87) : Colors.white;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Icon(Icons.auto_awesome, color: widget.isGeneral ? (isDark ? Colors.white : AppTheme.primaryColor) : Colors.greenAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: TextStyle(color: widget.isGeneral ? (isDark ? Colors.white : AppTheme.primaryColor) : Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: MarkdownBody(
                  key: ValueKey<String>(widget.text),
                  data: widget.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 13.5, height: 1.45, color: cardTextColor),
                    strong: TextStyle(fontWeight: FontWeight.w900, color: cardTextColor),
                    blockSpacing: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
