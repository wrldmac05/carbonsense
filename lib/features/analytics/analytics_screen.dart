// lib/features/analytics/analytics_screen.dart

import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 👈 Added Riverpod
import 'package:intl/intl.dart';
import 'analytics_providers.dart'; // 👈 Import your new providers!

enum ViewLevel { year, month, week }

// 👇 Changed to ConsumerStatefulWidget
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  ViewLevel _viewLevel = ViewLevel.year;
  DateTime _selectedDate = DateTime.now();
  final List<DateTime> _dateHistory = [];

  // Data processing logic modified to take the stream list directly
  List<double> _processChartData(List<Map<String, dynamic>> logs) {
    List<double> newData = [];

    if (_viewLevel == ViewLevel.year) {
      newData = List.filled(12, 0.0);
      for (var log in logs) {
        DateTime date = DateTime.parse(log['logged_at']);
        if (date.year == _selectedDate.year) {
          newData[date.month - 1] += (log['total_co2e'] as num).toDouble();
        }
      }
    } else if (_viewLevel == ViewLevel.month) {
      final weeks = _getWeeksInMonth(_selectedDate);
      newData = List.filled(weeks.length, 0.0);
      for (var log in logs) {
        DateTime date = DateTime.parse(log['logged_at']);
        if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
          for (int i = 0; i < weeks.length; i++) {
            if (date.isAfter(weeks[i]['start']!.subtract(const Duration(days: 1))) && 
                date.isBefore(weeks[i]['end']!.add(const Duration(days: 1)))) {
              newData[i] += (log['total_co2e'] as num).toDouble();
              break;
            }
          }
        }
      }
    } else {
      // Week View
      newData = List.filled(7, 0.0);
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      for (var log in logs) {
        DateTime date = DateTime.parse(log['logged_at']);
        if (date.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
            date.isBefore(startOfWeek.add(const Duration(days: 7)))) {
          newData[date.weekday - 1] += (log['total_co2e'] as num).toDouble();
        }
      }
    }
    return newData;
  }

  void _onTimeframeSelected(DateTime newDate, ViewLevel nextView) {
    setState(() {
      _dateHistory.add(_selectedDate);
      _selectedDate = newDate;
      _viewLevel = nextView;
    });
  }

  void _navigateBack() {
    if (_dateHistory.isEmpty) return;
    setState(() {
      _selectedDate = _dateHistory.removeLast();
      if (_viewLevel == ViewLevel.week) {
        _viewLevel = ViewLevel.month;
      } else if (_viewLevel == ViewLevel.month) {
        _viewLevel = ViewLevel.year;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Watch the streams!
    final logsAsync = ref.watch(activityLogsStreamProvider);
    final aiInsightAsync = ref.watch(aiInsightStreamProvider);

    return Scaffold(
      body: SafeArea(
        // Riverpod's .when() handles the loading/error/data states beautifully
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          error: (err, stack) => Center(child: Text('Error loading data: $err')),
          data: (logs) {
            final chartData = _processChartData(logs);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (_viewLevel != ViewLevel.week) _buildTimeframeSelectorGrid(),
                  const SizedBox(height: 24),
                  _buildChart(chartData), // Pass the processed data down
                  const SizedBox(height: 24),
                  
                  // Handle the AI Insight loading state independently
                  aiInsightAsync.when(
                    loading: () => const Center(child: LinearProgressIndicator(color: AppTheme.primaryColor)),
                    error: (err, stack) => _buildAiInsightCard("Couldn't connect to the AI Eco-Coach right now."),
                    data: (insightText) => _buildAiInsightCard(insightText),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- UI HELPER METHODS BELOW (Mostly unchanged, just removed setState ties) ---

  Widget _buildHeader() {
    String title;
    switch (_viewLevel) {
      case ViewLevel.year:
        title = DateFormat('yyyy').format(_selectedDate);
        break;
      case ViewLevel.month:
        title = DateFormat('MMMM yyyy').format(_selectedDate);
        break;
      case ViewLevel.week:
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        title = '${DateFormat.MMMd().format(startOfWeek)} - ${DateFormat.MMMd().format(endOfWeek)}';
        break;
    }

    return Row(
      children: [
        if (_viewLevel != ViewLevel.year)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.primaryColor),
            onPressed: _navigateBack,
          ),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Widget _buildTimeframeSelectorGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _viewLevel == ViewLevel.year ? 4 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: _viewLevel == ViewLevel.year ? 1.5 : 2.0,
      ),
      itemCount: _viewLevel == ViewLevel.year ? 12 :_getWeeksInMonth(_selectedDate).length,
      itemBuilder: (context, index) {
        String label;
        DateTime newDate;
        ViewLevel nextView;

        if (_viewLevel == ViewLevel.year) {
          label = DateFormat('MMM').format(DateTime(_selectedDate.year, index + 1));
          newDate = DateTime(_selectedDate.year, index + 1);
          nextView = ViewLevel.month;
        } else {
          final weeks = _getWeeksInMonth(_selectedDate);
          final week = weeks[index];
          final start = week['start']!;
          final end = week['end']!;
          label = '${start.day}-${end.day}';
          newDate = start;
          nextView = ViewLevel.week;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTimeframeSelected(newDate, nextView),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
          ),
        );
      },
    );
  }
  
  List<Map<String, DateTime>> _getWeeksInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final weeks = <Map<String, DateTime>>[];

    DateTime weekStart = firstDay;
    while (weekStart.isBefore(lastDay)) {
        DateTime weekEnd = weekStart.add(const Duration(days: 6));
        if (weekEnd.month != weekStart.month) {
            weekEnd = DateTime(weekStart.year, weekStart.month, lastDay.day);
        }
        weeks.add({'start': weekStart, 'end': weekEnd});
        weekStart = weekEnd.add(const Duration(days: 1));
    }
    return weeks;
  }

  // 👇 Modified to accept chartData as a parameter
  Widget _buildChart(List<double> chartData) {
    if (chartData.isEmpty || chartData.every((val) => val == 0)) {
       return const SizedBox(
         height: 250, 
         child: Center(child: Text("No data for this period", style: TextStyle(color: Colors.grey)))
       );
    }
    
    final maxY = chartData.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxY > 0 ? maxY * 1.2 : 10.0; 

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMaxY, 
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  String text = '';
                  if (_viewLevel == ViewLevel.year) {
                    final monthIndex = (value.toInt() % 12) + 1;
                    text = DateFormat('MMM').format(DateTime(2000, monthIndex)).substring(0, 1);
                  } else if (_viewLevel == ViewLevel.month) {
                    text = 'W${value.toInt() + 1}';
                  } else { 
                    final dayIndex = (value.toInt() % 7) + 1;
                    text = DateFormat('E').format(DateTime(2000, 1, 2 + dayIndex)).substring(0, 1);
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: chartData
              .asMap()
              .map((index, value) => MapEntry(
                    index,
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: AppTheme.primaryColor,
                          width: 16,
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                      ],
                    ),
                  ))
              .values
              .toList(),
        ),
      ),
    );
  }

  // 👇 Modified to accept the String directly
  Widget _buildAiInsightCard(String insightText) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.primaryColor.withAlpha(26),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eco-Coach Insight',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insightText,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            )
          ],
        ),
      ),
    );
  }
}