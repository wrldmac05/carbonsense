import 'package:carbonsense/features/activity/log_activity_screen.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/widgets/custom_drawer.dart';
import 'package:intl/intl.dart';
import 'package:carbonsense/widgets/quick_start_guide_dialog.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Set<int> _daysWithData = {};
  bool _isLoadingLogs = true;
  List<Map<String, dynamic>> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentLogs();
    _fetchMonthDataOverview();
  }

  Future<void> _fetchRecentLogs() async {
    if (!mounted) return;
    setState(() => _isLoadingLogs = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Calculate the start and end of the selected day
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('activity_logs')
          .select('*, emission_factors(activity_name, unit, category)')
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String()) // Greater than or equal to start of day
          .lt('logged_at', endOfDay.toIso8601String())    // Less than start of NEXT day
          .order('logged_at', ascending: false);

      if (mounted) {
        setState(() {
          _recentLogs = List<Map<String, dynamic>>.from(response);
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  // 🌟 NEW: Scans the month for active days
  Future<void> _fetchMonthDataOverview() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Start and end bounds for the currently viewed month
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);

      // Lightweight query: We ONLY ask for the 'logged_at' column, nothing else!
      final response = await Supabase.instance.client
          .from('activity_logs')
          .select('logged_at')
          .eq('user_id', userId)
          .gte('logged_at', startOfMonth.toIso8601String())
          .lte('logged_at', endOfMonth.toIso8601String());

      final Set<int> activeDays = {};
      for (var log in response) {
        // Parse the date and grab just the day number
        final date = DateTime.parse(log['logged_at']).toLocal();
        activeDays.add(date.day);
      }

      if (mounted) {
        setState(() {
          _daysWithData = activeDays;
        });
      }
    } catch (e) {
      debugPrint('Error fetching month overview: $e');
    }
  }

  void _openCategory(String categoryName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogActivityScreen(category: categoryName),
      ),
    );
    _fetchRecentLogs(); 
  }

  // Smart Icon Mapper for the Recent Logs list
  IconData _getIconForCategory(String? category) {
    if (category == 'Transport') return Icons.directions_car;
    if (category == 'Diet') return Icons.restaurant;
    if (category == 'Energy') return Icons.bolt;
    return Icons.eco;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9), // Clean, off-white eco background
      drawer: const CustomDrawer(),
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
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _fetchRecentLogs,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // --- HEADER SECTION ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track Activity',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'What did you do today?',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_chart, color: AppTheme.primaryColor),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // --- MODERN CATEGORY GRID ---
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

                    // --- RECENT LOGS SECTION ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Daily Timeline',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                        // Shows the full date dynamically (e.g., "Oct 14, 2026")
                        Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 🌟 INSERT THE DATE SELECTOR HERE
                    _buildDateSelector(),
                    
                    const SizedBox(height: 24),

                    // LIVE RECENT LOGS FROM DATABASE
                    _isLoadingLogs
                        ? const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                          )
                        : _recentLogs.isEmpty
                            ? _buildEmptyState()
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: _recentLogs.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100, indent: 70),
                                  itemBuilder: (context, index) {
                                    final log = _recentLogs[index];
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
                                    );
                                  },
                                ),
                              ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 // 🗓️ THE ULTIMATE TIMELINE & MONTH SELECTOR
  Widget _buildDateSelector() {
    // 1. Calculate how many days are in the currently focused month
    final int daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 📅 MONTH NAVIGATOR ROW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.grey.shade700),
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                });
                _fetchMonthDataOverview();
              },
            ),
            Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: Colors.grey.shade700),
              // Disable the right arrow if we are already in the current month!
              onPressed: (_focusedMonth.month == now.month && _focusedMonth.year == now.year)
                  ? null 
                  : () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                      });
                      _fetchMonthDataOverview();
                    },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // --- 🔢 HORIZONTAL DAY SCROLLER ---
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final int dayNumber = index + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, index + 1);
              
              final isSelected = date.year == _selectedDate.year &&
                                 date.month == _selectedDate.month &&
                                 date.day == _selectedDate.day;

              // Check if the date is in the future
              final isFuture = date.isAfter(now);
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

              // 🌟 Check if this specific day is in our active data set!
              final hasData = _daysWithData.contains(dayNumber);

              String dayLabel = isToday ? "Today" : DateFormat('EEE').format(date); // Mon, Tue, etc.

              return GestureDetector(
                onTap: isFuture 
                    ? null // Prevent clicking future dates
                    : () {
                        setState(() => _selectedDate = date);
                        _fetchRecentLogs(); // 🔥 Refetch logs for the clicked day
                      },
                child: Opacity(
                  opacity: isFuture ? 0.3 : 1.0, // Dim future dates visually
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                      ),
                      boxShadow: isSelected 
                          ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] 
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white70 : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                       // 🌟 THE MAGIC DOT INDICATOR
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            // Make it white if the pill is selected, otherwise make it your primary theme color (or invisible if no data)
                            color: hasData 
                                ? (isSelected ? Colors.white : AppTheme.primaryColor) 
                                : Colors.transparent, 
                            shape: BoxShape.circle,
                          ),
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

  // 🎨 Sleek, tappable category cards
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: themeColor.shade600),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📝 Clean transaction-style list tile
  Widget _buildModernListTile({
    required String title,
    required String category,
    required String subtitle,
    required String co2Value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text('kg CO₂', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  // 📭 Nice empty state for new users
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