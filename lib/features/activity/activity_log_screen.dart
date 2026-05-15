import 'package:carbonsense/features/activity/log_activity_screen.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  bool _isLoadingLogs = true;
  List<Map<String, dynamic>> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentLogs();
  }

  Future<void> _fetchRecentLogs() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch the last 5 logs and join with the emission_factors table to get the name and unit
      final response = await Supabase.instance.client
          .from('activity_logs')
          .select('*, emission_factors(activity_name, unit)')
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(5);

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

  void _openCategory(String categoryName) async {
    // Navigate to the selection screen, wait for it to pop back, then refresh logs
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogActivityScreen(category: categoryName),
      ),
    );
    _fetchRecentLogs(); // Refresh the list when we come back!
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchRecentLogs,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log Activity',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                // THE 3 MAIN CATEGORY BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildCategoryButton(context, Icons.directions_car, 'Transport')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCategoryButton(context, Icons.restaurant, 'Diet')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCategoryButton(context, Icons.power, 'Energy')),
                  ],
                ),
                const SizedBox(height: 32),
                
                Text(
                  'Recent Logs',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                // LIVE RECENT LOGS FROM DATABASE
                _isLoadingLogs
                    ? const Center(child: CircularProgressIndicator())
                    : _recentLogs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No activities logged yet. Start tracking!'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentLogs.length,
                            itemBuilder: (context, index) {
                              final log = _recentLogs[index];
                              final factorData = log['emission_factors'] as Map<String, dynamic>?;
                              final activityName = factorData?['activity_name'] ?? 'Unknown Activity';
                              final unit = factorData?['unit'] ?? '';
                              final inputValue = log['input_value']?.toString() ?? '0';
                              final totalCo2 = (log['total_co2e'] as num?)?.toStringAsFixed(2) ?? '0.00';

                              return _buildRecentAction(
                                activityName,
                                '$inputValue $unit • $totalCo2 kg CO₂',
                              );
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, IconData icon, String label) {
    return ElevatedButton(
      onPressed: () => _openCategory(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 20),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecentAction(String title, String subtitle) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withAlpha(26),
          child: const Icon(Icons.check_circle, color: AppTheme.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}