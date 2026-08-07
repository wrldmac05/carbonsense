import 'package:carbonsense/features/activity/log_activity_screen.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:carbonsense/features/utils/global_provider.dart'; // 🌟 Import your global providers file

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  DateTime _selectedDate = DateTime.now();

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // 📝 Helper to show detailed information when a log is tapped
  void _showLogDetails(Map<String, dynamic> log, Map<String, dynamic>? factorData) {
    final activityName = factorData?['activity_name'] ?? 'Unknown Activity';
    final category = factorData?['category'] ?? 'General';
    final unit = factorData?['unit'] ?? '';
    final inputValue = log['input_value']?.toString() ?? '0';

    // 🌟 Dynamic precision helper: preserves up to 4 decimal places without trailing zeros
    String formatCo2(num? rawCo2) {
      if (rawCo2 == null || rawCo2 == 0) return '0.00';
      final double value = rawCo2.toDouble();

      // For small decimals, keep up to 4 decimal places and remove extra trailing zeros
      if (value.abs() < 0.1) {
        return value.toStringAsFixed(4).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
      }

      // For standard values, display 2 decimal places
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
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: Icon(_getIconForCategory(category), color: AppTheme.primaryColor, size: 32),
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
                  const SizedBox(height: 8),
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
                const SizedBox(height: 32),
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

  void _openCategory(String categoryName) async {
    if (categoryName == 'Diet') {
      await context.pushNamed('food-scanner');
    } else if (categoryName == 'Energy') {
      await context.pushNamed('bill-scanner');
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => LogActivityScreen(category: categoryName)));
    }
  }

  IconData _getIconForCategory(String? category) {
    if (category == 'Transport') return Icons.directions_car;
    if (category == 'Diet') return Icons.restaurant;
    if (category == 'Energy') return Icons.bolt;
    return Icons.eco;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      body: SafeArea(
        bottom: false,
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),

          // 🌟 REPLACED: Modern full-page offline/error UI
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
                    "We couldn't load your activity logs right now. Please check your internet connection and try again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // 🌟 Refresh the stream when pressed
                      ref.invalidate(activityLogsStreamProvider);
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

          // 🌟 KEPT: Your exact original data handling and layout logic
          data: (allLogs) {
            // 🌟 1. Filter logs for the currently selected calendar day timeline
            final selectedDayLogs = allLogs.where((log) {
              if (log['logged_at'] == null) return false;
              final logDate = DateTime.parse(log['logged_at']).toLocal();
              return logDate.year == _selectedDate.year && logDate.month == _selectedDate.month && logDate.day == _selectedDate.day;
            }).toList()..sort((a, b) => b['logged_at'].compareTo(a['logged_at']));

            // 🌟 2. Extract active days for the calendar overview dots
            final Set<int> daysWithData = {};
            final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
            final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);

            for (var log in allLogs) {
              if (log['logged_at'] == null) continue;
              final logDate = DateTime.parse(log['logged_at']).toLocal();
              if (logDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && logDate.isBefore(endOfMonth.add(const Duration(seconds: 1)))) {
                daysWithData.add(logDate.day);
              }
            }

            // 🌟 CRITICAL FIX: Make sure to explicitly return the widget tree here!
            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                ref.invalidate(activityLogsStreamProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Track Activity',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 4),
                                Text('What did you do today?', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(child: _buildModernCategoryCard(Icons.directions_car, 'Transport', Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildModernCategoryCard(Icons.restaurant, 'Diet', Colors.orange)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildModernCategoryCard(Icons.bolt, 'Energy', Colors.amber)),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Daily Timeline',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDateSelector(daysWithData),
                        const SizedBox(height: 24),
                        selectedDayLogs.isEmpty
                            ? _buildEmptyState()
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
                                  padding: EdgeInsets.zero,
                                  itemCount: selectedDayLogs.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100, indent: 70),
                                  itemBuilder: (context, index) {
                                    final log = selectedDayLogs[index];
                                    final factorData = log['emission_factors'] as Map<String, dynamic>?;

                                    final activityName = factorData?['activity_name'] ?? 'Unknown';
                                    final category = factorData?['category'] ?? 'General';
                                    final unit = factorData?['unit'] ?? '';
                                    final inputValue = log['input_value']?.toString() ?? '0';
                                    final totalCo2 = (log['total_co2e'] as num?)?.toStringAsFixed(2) ?? '0.00';

                                    return _buildModernListTile(
                                      title: activityName,
                                      category: category,
                                      subtitle: '$inputValue $unit',
                                      co2Value: totalCo2,
                                      onTap: () => _showLogDetails(log, factorData),
                                    );
                                  },
                                ),
                              ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateSelector(Set<int> daysWithData) {
    final int daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.grey.shade700),
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                });
              },
            ),
            Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: Colors.grey.shade700),
              onPressed: (_focusedMonth.month == now.month && _focusedMonth.year == now.year)
                  ? null
                  : () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final int dayNumber = index + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, index + 1);

              final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;

              final isFuture = date.isAfter(now);
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

              final hasData = daysWithData.contains(dayNumber);
              String dayLabel = isToday ? "Today" : DateFormat('EEE').format(date);

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        setState(() => _selectedDate = date);
                      },
                child: Opacity(
                  opacity: isFuture ? 0.3 : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200),
                      boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white70 : Colors.grey.shade500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date.day.toString(),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(color: hasData ? (isSelected ? Colors.white : AppTheme.primaryColor) : Colors.transparent, shape: BoxShape.circle),
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

  Widget _buildModernCategoryCard(IconData icon, String title, MaterialColor themeColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCategory(title),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: themeColor.shade50, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: themeColor.shade600),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernListTile({required String title, required String category, required String subtitle, required String co2Value, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(_getIconForCategory(category), color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+$co2Value',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'kg CO₂',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 48, color: AppTheme.primaryColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No activities yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Log your first commute or meal to start tracking your footprint.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
