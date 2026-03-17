
import 'package:carbonsense/screens/daily_tasks_screen.dart';
import 'package:carbonsense/screens/forgot_password_screen.dart';
import 'package:carbonsense/screens/home_dashboard.dart';
import 'package:carbonsense/screens/login_screen.dart';
import 'package:carbonsense/screens/main_navigation.dart';
import 'package:carbonsense/screens/profile_screen.dart';
import 'package:carbonsense/screens/register_screen.dart';
import 'package:carbonsense/screens/score_history_screen.dart';
import 'package:carbonsense/screens/settings_screen.dart';
import 'package:carbonsense/screens/welcome_screen.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const CarbonSense());
}

class CarbonSense extends StatelessWidget {
  const CarbonSense({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'CarbonSense',
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: '/welcome',
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/home': (context) => const HomeDashboard(),
            '/main-navigation': (context) => const MainNavigation(),
            '/daily-tasks': (context) => const DailyTasksScreen(),
            '/score-history': (context) => const ScoreHistoryScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
