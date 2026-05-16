import 'package:carbonsense/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_providers.dart';
import 'package:carbonsense/widgets/custom_drawer.dart';
import 'package:carbonsense/widgets/quick_start_guide_dialog.dart';

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

  Future<void> _runSmartSync() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.functions.invoke(
        'eco_coach',
        body: {'user_id': userId}, 
      );
    } catch (e) {
      debugPrint("Silent Sync Error: $e"); 
    }
  }

  List<double> _getYearlyData(List<Map<String, dynamic>> logs) {
    List<double> yearlyData = List.filled(12, 0.0);
    final currentYear = DateTime.now().year;

    for (var log in logs) {
      DateTime date = DateTime.parse(log['logged_at']);
      if (date.year == currentYear) {
        yearlyData[date.month - 1] += (log['total_co2e'] as num).toDouble();
      }
    }
    return yearlyData;
  }

  // 🎨 YOUR UPGRADED MODERN HEADER ENGINE
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Analytics", 
          style: TextStyle(
            fontSize: 34, 
            fontWeight: FontWeight.w900, 
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Review your real-time carbon mitigation insights.",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
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
      drawer: const CustomDrawer(),
      
      // 1. CLEAN APP BAR Layout 
      // Gives full focus to your page header while natively housing the hamburger menu
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true, // Centers your logo beautifully in the middle

        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.primaryColor),
            tooltip: 'Quick Start Guide',
            onPressed: () => showQuickStartGuideDialog(context), // Works instantly!
          ),
          const SizedBox(width: 12),
        ],
        
        // Custom branding layout inside the title
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
        
        // Optional: Add a subtle notification or profile trigger on the right side to balance out the layout      
        
        // NOTE: You do not need to add a leading IconButton for the hamburger menu!
        // Flutter automatically detects the 'drawer' property above and generates 
        // a perfect, theme-matched hamburger button for you right here.
      ),
        
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (logs) {
          final yearlyData = _getYearlyData(logs);
          final totalYearlyImpact = yearlyData.fold(0.0, (sum, item) => sum + item);
          final selectedMonthImpact = yearlyData[_selectedMonthIndex];

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 CONNECTION STEP: Injecting your beautiful new header here!
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: _buildHeader(),
                ),
                const SizedBox(height: 16),

                // 2. GENERAL AI INSIGHT (The Big Picture)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: generalAiAsync.when(
                    loading: () => const LinearProgressIndicator(color: AppTheme.primaryColor),
                    error: (err, _) => const SizedBox.shrink(),
                    data: (text) => _buildAiCard("GENERAL ECO-COACH", text, isGeneral: true),
                  ),
                ),

                // 3. YEARLY OVERVIEW GRAPH
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildYearlyChartCard(yearlyData, totalYearlyImpact),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text("Monthly Deep Dive", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ),

                // 4. MONTH SELECTOR
                _buildMonthSelector(),

                // 5. MONTH-SPECIFIC DETAILS & AI
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildMonthSummaryCard(selectedMonthImpact),
                      const SizedBox(height: 16),
                      
                      monthlyAiAsync.when(
                        loading: () => const LinearProgressIndicator(color: Colors.greenAccent),
                        error: (err, _) => const SizedBox.shrink(),
                        data: (text) {
                          if (_selectedMonthIndex == DateTime.now().month - 1) {
                            text = "Activity tracking in progress... Your full AI summary will be generated on the 1st of next month!";
                          }

                          return _buildAiCard(
                            "${DateFormat('MMMM').format(DateTime(2026, _selectedMonthIndex + 1)).toUpperCase()} INSIGHT", 
                            text,
                            isGeneral: false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
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
        boxShadow: [
          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: isGeneral ? AppTheme.primaryColor : Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Text(title, 
                style: TextStyle(
                  color: isGeneral ? AppTheme.primaryColor : Colors.greenAccent, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 11, 
                  letterSpacing: 1.2
                )),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, 
            style: TextStyle(
              fontSize: 15, 
              height: 1.5, 
              color: isGeneral ? Colors.black87 : Colors.white
            )),
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
          const Text("Year-to-Date Impact", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("${total.toStringAsFixed(1)} kg CO₂e", 
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
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
          maxY: maxY == 0 ? 10 : maxY, 
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false, 
            getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)
          ),
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
                getTitlesWidget: (val, _) {
                  final months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
                  int index = val.toInt();
                  if (index < 0 || index > 11) return const SizedBox.shrink();
                  
                  bool isSelected = index == _selectedMonthIndex;
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      months[index], 
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey, 
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                        fontSize: 12
                      )
                    ),
                  );
                },
              ),
            ),
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.primaryColor.withOpacity(0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 12,
        itemBuilder: (context, index) {
          bool isSelected = index == _selectedMonthIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200),
                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Center(
                child: Text(
                  months[index], 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : Colors.black87)
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSummaryCard(double impact) {
    String monthName = DateFormat('MMMM').format(DateTime(2026, _selectedMonthIndex + 1));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$monthName Total", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("${impact.toStringAsFixed(1)} kg", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 32),
        ],
      ),
    );
  }
}