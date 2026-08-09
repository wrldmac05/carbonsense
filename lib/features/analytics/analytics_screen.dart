import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_providers.dart';

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
    // 1. Food scanner AI item name
    if (log['food_name'] != null && log['food_name'].toString().trim().isNotEmpty) {
      return log['food_name'].toString();
    }

    // 2. Joined emission factor attributes
    if (factorData != null) {
      final name = factorData['activity_name'] ?? factorData['name'] ?? factorData['title'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    // 3. Top-level log fields
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

  // 📝 Helper to show detailed information when a log is tapped
  void _showLogDetails(Map<String, dynamic> log, Map<String, dynamic>? factorData) {
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      decoration: BoxDecoration(color: _getColorForCategory(category).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: Icon(_getIconForCategory(category), color: _getColorForCategory(category), size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activityName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 16),
                _buildDetailRow('Input Amount', '$inputValue $unit'),
                const SizedBox(height: 16),
                _buildDetailRow('Time Logged', formattedTime),
                const SizedBox(height: 24),
                if (category == 'Transport' && startLocation != null && endLocation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
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
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
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
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
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
                  const Text(
                    'Detected Ingredients',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
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
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              ingredient,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
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
                    color: AppTheme.primaryColor.withOpacity(0.05),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(color: isHighlight ? AppTheme.primaryColor : Colors.black87, fontSize: isHighlight ? 18 : 16, fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Analytics", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.0)),
        const SizedBox(height: 4),
        Text(
          "Review your real-time carbon mitigation insights.",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsStreamProvider);
    final generalAiAsync = ref.watch(generalAiInsightProvider);
    final monthlyAiAsync = ref.watch(monthlyAiInsightProvider(_selectedMonthIndex));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
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
                color: AppTheme.primaryColor.withOpacity(0.04), // Subtle opacity matching theme color
              ),
            ),
          ),

          // Main Content
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
                      Icon(Icons.cloud_off_rounded, color: Colors.grey.shade400, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        "Connection lost",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We couldn't load your analytics right now. Please check your internet connection and try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(activityLogsStreamProvider);
                          ref.invalidate(generalAiInsightProvider);
                          ref.invalidate(monthlyAiInsightProvider);
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        "Welcome to CarbonSense!\n\nLog your first activity today to wake up your personal AI Eco-Coach.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
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
                    await _runSmartSync();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: _buildHeader()),
                        const SizedBox(height: 16),

                        // 1. GENERAL AI INSIGHT
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                          child: generalAiAsync.when(
                            loading: () => Container(
                              height: 120,
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
                              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                            ),
                            error: (err, _) => const SizedBox.shrink(),
                            data: (text) => _buildAiCard("GENERAL ECO-COACH", text, isGeneral: true),
                          ),
                        ),

                        // 2. YEARLY OVERVIEW GRAPH
                        Padding(padding: const EdgeInsets.all(20.0), child: _buildYearlyChartCard(yearlyData, totalYearlyImpact)),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Text("Monthly Deep Dive", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        ),

                        // 3. MONTH SELECTOR
                        _buildMonthSelector(),

                        const SizedBox(height: 16),

                        // 4. MONTHLY SUMMARY & QUICK METRICS
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(children: [_buildMonthSummaryCard(selectedMonthImpact), const SizedBox(height: 16), _buildQuickMetricsGrid(selectedMonthImpact, monthLogs, categoryTotals)]),
                        ),

                        const SizedBox(height: 20),

                        // 5. CATEGORY BREAKDOWN PIE CHART
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: _buildCategoryBreakdownCard(categoryTotals, selectedMonthImpact)),

                        const SizedBox(height: 20),

                        // 6. MONTHLY AI INSIGHT CARD
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: monthlyAiAsync.when(
                            loading: () => Container(
                              height: 120,
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
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

                        const SizedBox(height: 28),

                        // 7. MONTHLY ACTIVITY LOGS LIST
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: _buildMonthlyActivitySection(monthLogs)),

                        const SizedBox(height: 120),
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
  }

  // --- UI COMPONENTS ---

  Widget _buildAiCard(String title, String text, {required bool isGeneral}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGeneral ? Colors.white : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: isGeneral ? AppTheme.primaryColor : Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: isGeneral ? AppTheme.primaryColor : Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 15, height: 1.5, color: isGeneral ? Colors.black87 : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildYearlyChartCard(List<double> data, double total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Year-to-Date Impact",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text("${total.toStringAsFixed(1)} kg CO₂e", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 32),
          _buildYearlyGraph(data),
        ],
      ),
    );
  }

  Widget _buildYearlyGraph(List<double> data) {
    final maxY = data.isEmpty ? 100.0 : (data.reduce((a, b) => a > b ? a : b) * 1.2);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 11,
          maxY: maxY == 0 ? 10 : maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      val.toInt().toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (val, _) {
                  final months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
                  int index = val.toInt();
                  if (index < 0 || index > 11) return const SizedBox.shrink();

                  bool isSelected = index == _selectedMonthIndex;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      months[index],
                      style: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.grey, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) => const Color(0xFF1A1A1A),
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
              color: AppTheme.primaryColor,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.primaryColor.withOpacity(0)]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: 12,
        itemBuilder: (context, index) {
          bool isSelected = index == _selectedMonthIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Center(
                child: Text(
                  months[index],
                  style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSummaryCard(double impact) {
    String monthName = DateFormat('MMMM').format(DateTime(DateTime.now().year, _selectedMonthIndex + 1));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$monthName Total Footprint",
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text("${impact.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  if (impact > 0 && impact < 50) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                      child: const Text(
                        "Great!",
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 32),
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
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(title: "Logs Count", value: "${monthLogs.length}", icon: Icons.assignment_outlined, color: Colors.purple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(title: "Top Source", value: topCategory, icon: _getIconForCategory(topCategory), color: _getColorForCategory(topCategory)),
        ),
      ],
    );
  }

  Widget _buildMetricTile({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(Map<String, double> categoryTotals, double totalImpact) {
    final List<PieChartSectionData> sections = [];

    categoryTotals.forEach((category, amount) {
      if (amount > 0) {
        final percentage = totalImpact > 0 ? (amount / totalImpact * 100) : 0.0;
        sections.add(
          PieChartSectionData(
            color: _getColorForCategory(category),
            value: amount,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 40,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Category Share", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 16),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text("No category data available for this month.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            Row(
              children: [
                SizedBox(height: 130, width: 130, child: PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 28, sections: sections))),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: categoryTotals.entries.map((e) {
                      if (e.value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: _getColorForCategory(e.key), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            Text("${e.value.toStringAsFixed(1)} kg", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Logged Activities", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(
              "${monthLogs.length} items",
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        monthLogs.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20)),
                child: const Center(
                  child: Text("No activities logged for this month.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthLogs.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100, indent: 70),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: _getColorForCategory(category).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                child: Icon(_getIconForCategory(category), color: _getColorForCategory(category), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activityName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$inputValue $unit',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+$totalCo2',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _getColorForCategory(category)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'kg CO₂',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
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
