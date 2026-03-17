import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Mock data for tasks
  final Map<String, bool> _starterTasks = {
    'Use a reusable water bottle': true,
    'Turn off lights when not in use': false,
    'Recycle paper and plastic': true,
  };

  final Map<String, bool> _midTasks = {
    'Take shorter showers': false,
    'Use public transportation once a week': false,
  };

  final Map<String, bool> _fullSaverTasks = {
    'Start composting food scraps': false,
    'Switch to a renewable energy provider': false,
    'Install a smart thermostat': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco-Goals'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTaskCategory('Starter', _starterTasks),
                    const SizedBox(height: 24),
                    _buildTaskCategory('Mid-Tier', _midTasks),
                    const SizedBox(height: 24),
                    _buildTaskCategory('Full Saver', _fullSaverTasks),
                  ],
                ),
              ),
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
