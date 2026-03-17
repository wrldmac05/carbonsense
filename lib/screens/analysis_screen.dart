import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Footprint Analysis',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildPieChartCard(context),
                const SizedBox(height: 24),
                _buildBarChartCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Impact Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                        color: Colors.green.shade800,
                        value: 40,
                        title: '40%',
                        radius: 50),
                    PieChartSectionData(
                        color: Colors.green.shade500,
                        value: 30,
                        title: '30%',
                        radius: 50),
                    PieChartSectionData(
                        color: Colors.lightGreen.shade500,
                        value: 20,
                        title: '20%',
                        radius: 50),
                    PieChartSectionData(
                        color: Colors.lime.shade400,
                        value: 10,
                        title: '10%',
                        radius: 50),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // FIX #1: Removed 'const' from this Row!
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Indicator(color: Colors.green.shade800, text: 'Transport'),
                _Indicator(color: Colors.green.shade500, text: 'Energy'),
                _Indicator(color: Colors.lightGreen.shade500, text: 'Food'),
                _Indicator(color: Colors.lime.shade400, text: 'Waste'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Weekly Footprint Score',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    _makeGroupData(0, 5),
                    _makeGroupData(1, 6.5),
                    _makeGroupData(2, 5),
                    _makeGroupData(3, 7.5),
                    _makeGroupData(4, 9),
                    _makeGroupData(5, 11.5),
                    _makeGroupData(6, 6.5),
                  ],
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14);
                          String text;
                          switch (value.toInt()) {
                            case 0:
                              text = 'M';
                              break;
                            case 1:
                              text = 'T';
                              break;
                            case 2:
                              text = 'W';
                              break;
                            case 3:
                              text = 'T';
                              break;
                            case 4:
                              text = 'F';
                              break;
                            case 5:
                              text = 'S';
                              break;
                            case 6:
                              text = 'S';
                              break;
                            default:
                              text = '';
                              break;
                          }
                          // FIX #2: Added axisSide parameter here!
                          return Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Text(text, style: style),
  );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
        toY: y,
        color: AppTheme.primaryColor,
        width: 22,
        borderRadius: BorderRadius.zero,
      )
    ]);
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    super.key, // Removed because it's not strictly needed for this fix, but keeping the super.key is fine
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(text)
      ],
    );
  }
}