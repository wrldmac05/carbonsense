import 'package:carbonsense/main.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Dummy states for the UI
  bool _dailyReminders = true;
  bool _aiInsights = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appearance', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: const Text('Dark Theme'),
                  value: themeNotifier.value == ThemeMode.dark,
                  onChanged: (bool value) {
                    setState(() {
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  secondary: const Icon(Icons.dark_mode, color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              
              Text('Notifications', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Daily Task Reminders'),
                      subtitle: const Text('Get notified to complete your eco-tasks.'),
                      value: _dailyReminders,
                      onChanged: (bool value) => setState(() => _dailyReminders = value),
                      activeColor: AppTheme.primaryColor,
                      secondary: const Icon(Icons.checklist, color: AppTheme.primaryColor),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('AI Coach Insights'),
                      subtitle: const Text('Alerts when your AI coach has a new tip.'),
                      value: _aiInsights,
                      onChanged: (bool value) => setState(() => _aiInsights = value),
                      activeColor: AppTheme.primaryColor,
                      secondary: const Icon(Icons.psychology, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}