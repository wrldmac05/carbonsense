import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ViewLevel { year, month, week }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  ViewLevel _viewLevel = ViewLevel.year;
  DateTime _selectedDate = DateTime.now();
  final List<DateTime> _dateHistory = [];

  // Mock data for the chart
  final Map<ViewLevel, List<double>> _mockData = {
    ViewLevel.year: [150, 200, 180, 220, 170, 210, 250, 230, 200, 190, 240, 260],
    ViewLevel.month: [50, 65, 55, 70, 45],
    ViewLevel.week: [10, 12, 8, 15, 11, 13, 9],
  };

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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_viewLevel != ViewLevel.week) _buildTimeframeSelectorGrid(),
              const SizedBox(height: 24),
              _buildChart(),
              const SizedBox(height: 24),
              _buildAiInsightCard(),
            ],
          ),
        ),
      ),
    );
  }

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
        // Calculate start and end of the week for the title
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
        } else { // Month view
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

  Widget _buildChart() {
    final data = _mockData[_viewLevel]!;
    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: data.reduce((a, b) => a > b ? a : b) * 1.2, // Add some padding to the top
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
                    meta: meta, // 👈 Fixed right here!
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
          barGroups: data
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

  Widget _buildAiInsightCard() {
    String timeframe;
     switch (_viewLevel) {
      case ViewLevel.year:
        timeframe = 'for ${DateFormat('yyyy').format(_selectedDate)}';
        break;
      case ViewLevel.month:
        timeframe = 'for ${DateFormat('MMMM').format(_selectedDate)}';
        break;
      case ViewLevel.week:
        timeframe = 'for this week';
        break;
    }


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eco-Coach Insight: $timeframe',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Analyzing your data... You kept your transport emissions incredibly low this timeframe! Let's keep that momentum going by trying to swap one car trip for a bike ride.",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            )
          ],
        ),
      ),
    );
  }
}
