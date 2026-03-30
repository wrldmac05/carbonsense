import 'dart:math';

import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  double _netFootprint = 0.0;
  double _monthlyTarget = 1.0; // Default to 1 to avoid division by zero
  double _progress = 0.0;

  late final String _userId;

  @override
  void initState() {
    super.initState();
    // Ensure the user is logged in before proceeding.
    if (Supabase.instance.client.auth.currentUser != null) {
      _userId = Supabase.instance.client.auth.currentUser!.id;
      _initializeDashboard();
    } else {
      // Handle case where user is not logged in
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeDashboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchMonthlyTarget();
      await _fetchOrGenerateTasks();
      await _calculateNetFootprint();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing dashboard: ${error.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMonthlyTarget() async {
    final response = await Supabase.instance.client
        .from('user_profiles')
        .select('monthly_co2_target')
        .eq('user_id', _userId) // 👈 FIX 1: Uses user_id, not id
        .maybeSingle();

    if (mounted && response != null) {
      final target = response['monthly_co2_target'] as double?;
      _monthlyTarget = (target != null && target > 0) ? target : 1.0;
    }
  }

  Future<void> _fetchOrGenerateTasks() async {
    var response = await Supabase.instance.client
        .from('user_tasks')
        .select('*, tasks_dictionary(*)') // 👈 FIX 2: Correct join syntax for your table name
        .eq('user_id', _userId);

    if (response.isEmpty) {
      // No tasks found! Trigger the RPC Dealer.
      await Supabase.instance.client
          .rpc('generate_smart_tasks', params: {'current_user_id': _userId});
          
      // Re-fetch after the AI deals new tasks
      response = await Supabase.instance.client
          .from('user_tasks')
          .select('*, tasks_dictionary(*)')
          .eq('user_id', _userId);
    }

    if (mounted) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _calculateNetFootprint() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // 1. Sum emissions from activity_logs
    final emissionsResponse = await Supabase.instance.client
        .from('activity_logs')
        .select('total_co2e')
        .eq('user_id', _userId)
        .gte('logged_at', startOfMonth.toIso8601String()) // 👈 FIXED
        .lte('logged_at', endOfMonth.toIso8601String());  // 👈 FIXED

    final totalEmissions = emissionsResponse.fold<double>(
        0.0, (sum, item) => sum + (item['total_co2e'] ?? 0.0));

    // 2. Sum savings from completed user_tasks
    final savedResponse = await Supabase.instance.client
        .from('user_tasks')
        .select('tasks_dictionary(co2_saved_estimate)')
        .eq('user_id', _userId)
        .eq('is_completed', true)
        .gte('completed_at', startOfMonth.toIso8601String())
        .lte('completed_at', endOfMonth.toIso8601String());

    final totalSaved = savedResponse.fold<double>(0.0, (sum, item) {
       final taskData = item['tasks_dictionary'];
       if (taskData != null) {
         return sum + double.parse(taskData['co2_saved_estimate'].toString());
       }
       return sum;
    });

    if (mounted) {
      setState(() {
        _netFootprint = max(0, totalEmissions - totalSaved);
        _progress = min(1.0, max(0.0, _netFootprint / _monthlyTarget));
      });
    }
  }

  Future<void> _updateTaskStatus(String userTaskId, bool isCompleted) async {
    try {
      // 👈 FIX 3: Looks for user_task_id instead of id
      final taskIndex = _tasks.indexWhere((t) => t['user_task_id'] == userTaskId);
      if (taskIndex == -1) return;

      // Optimistically update UI
      setState(() {
        _tasks[taskIndex]['is_completed'] = isCompleted;
      });

      // Update Database
      await Supabase.instance.client.from('user_tasks').update({
        'is_completed': isCompleted,
        'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
      }).eq('user_task_id', userTaskId); // 👈 FIX 4: Targets correct primary key
      
      // Recalculate score after successful update
      await _calculateNetFootprint();

    } catch (error) {
      // Revert optimistic update on failure
      final taskIndex = _tasks.indexWhere((t) => t['user_task_id'] == userTaskId);
       if (taskIndex != -1) {
          setState(() {
             _tasks[taskIndex]['is_completed'] = !isCompleted;
          });
       }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProgressSection(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                          const SizedBox(height: 24),
                          _buildDailyTasksSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Net Footprint',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor),
                ),
                Center(
                  child: Text(
                    '${_netFootprint.toStringAsFixed(1)} kg',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionIconButton(context, Icons.water_drop, 'Water'),
        _buildActionIconButton(context, Icons.lightbulb, 'Energy'),
        _buildActionIconButton(context, Icons.directions_bike, 'Travel'),
      ],
    );
  }

  Widget _buildDailyTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Tasks',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _tasks.isEmpty 
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No tasks generated yet. Try refreshing!", style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                // 👈 FIX 5: Uses the correct joined table name
                final taskDetails = task['tasks_dictionary'] as Map<String, dynamic>? ?? {}; 
                final userTaskId = task['user_task_id'] as String; // 👈 FIX 6
                final isCompleted = task['is_completed'] as bool? ?? false;

                // Grab the description directly since there is no 'name' column in your dictionary!
                final description = taskDetails['description'] ?? 'Unnamed Task';
                final tier = taskDetails['tier'] ?? 'Standard';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: CheckboxListTile(
                    title: Text(description, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('Tier: $tier', style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.7))),
                    value: isCompleted,
                    onChanged: (bool? value) {
                      if (value != null) {
                        _updateTaskStatus(userTaskId, value);
                      }
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                );
              },
          ),
      ],
    );
  }

  Widget _buildActionIconButton(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.primaryColor,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: () {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$label shortcut coming soon!'),
                    duration: const Duration(seconds: 1),
                ));
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppTheme.primaryColor)),
      ],
    );
  }
}