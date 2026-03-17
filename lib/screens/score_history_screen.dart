import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ScoreHistoryScreen extends StatelessWidget {
  const ScoreHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // Snaps to top
              crossAxisAlignment: CrossAxisAlignment.stretch, // Expands full width
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Footprint Trends',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
                    child: SizedBox(
                      height: 300,
                      child: LineChart(
                        _mainData(),
                      ),
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

  LineChartData _mainData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (double value, TitleMeta meta) {
              const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
              String text;
              switch (value.toInt()) {
                case 0:
                  text = 'Baseline';
                  break;
                case 2:
                  text = 'Week 1';
                  break;
                case 4:
                  text = 'Week 2';
                  break;
                case 6:
                  text = 'Current';
                  break;
                default:
                  return const SizedBox.shrink(); // Cleaner than Container()
              }
              // The bulletproof Padding fix!
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(text, style: style),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (double value, TitleMeta meta) {
              // Added padding here so numbers don't touch the line
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text('${value.toInt()}', textAlign: TextAlign.left),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 60), // Baseline
            FlSpot(1, 75),
            FlSpot(2, 65),
            FlSpot(3, 80),
            FlSpot(4, 70),
            FlSpot(5, 85),
            FlSpot(6, 90), // Current
          ],
          isCurved: true,
          color: AppTheme.primaryColor,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}