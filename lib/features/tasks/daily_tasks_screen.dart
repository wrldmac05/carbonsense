// TODO: Consolidate this screen with tasks_screen.dart
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  // Mock data for tasks
  final Map<String, bool> _seedlingTasks = {
    'Use a reusable shopping bag': true,
    'Unplug chargers when not in use': false,
  };

  final Map<String, bool> _sproutTasks = {
    'Eat a meat-free meal': false,
    'Air dry your clothes': false,
  };

  final Map<String, bool> _canopyTasks = {
    'Bike or walk for a short trip': false,
    'Research a local sustainability group': false,
  };

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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    Text(
                      'Daily Tasks',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTaskCategory('Seedling (Easy)', _seedlingTasks),
                const SizedBox(height: 24),
                _buildTaskCategory('Sprout (Medium)', _sproutTasks),
                const SizedBox(height: 24),
                _buildTaskCategory('Canopy (Advanced)', _canopyTasks),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCategory(String title, Map<String, bool> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            String key = tasks.keys.elementAt(index);
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: CheckboxListTile(
                title: Text(key),
                value: tasks[key],
                onChanged: (bool? value) {
                  setState(() {
                    tasks[key] = value!;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            );
          },
        ),
      ],
    );
  }
}
