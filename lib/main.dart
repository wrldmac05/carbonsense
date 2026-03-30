import 'package:carbonsense/features/activity/activity_log_screen.dart';
import 'package:carbonsense/features/tasks/daily_tasks_screen.dart';
import 'package:carbonsense/features/auth/forgot_password_screen.dart';
import 'package:carbonsense/features/navigation/home_dashboard.dart';
import 'package:carbonsense/features/auth/login_screen.dart';
import 'package:carbonsense/features/navigation/main_navigation.dart';
import 'package:carbonsense/features/navigation/menu_main_screen.dart'; 
import 'package:carbonsense/features/profile/profile_screen.dart';
import 'package:carbonsense/features/auth/register_screen.dart';
import 'package:carbonsense/features/activity/score_history_screen.dart';
import 'package:carbonsense/features/profile/settings_screen.dart';
import 'package:carbonsense/features/profile/edit_profile_screen.dart';
import 'package:carbonsense/features/auth/welcome_screen.dart';
import 'package:carbonsense/features/analytics/analytics_screen.dart'; // 👈 Added the new Analytics import!
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

final _router = GoRouter(
  initialLocation: '/welcome',
  routes: [
    // --- AUTH ROUTES (FULL SCREEN) ---
    GoRoute(
      path: '/welcome', 
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login', 
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register', 
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),

    // --- SHELL ROUTE (BOTTOM NAVIGATION BAR) ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigation(navigationShell: navigationShell);
      },
      branches: [
        // BRANCH 0: Activity
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              builder: (context, state) => const ActivityLogScreen(),
              routes: [
                GoRoute(
                  path: 'score-history',
                  builder: (context, state) => const ScoreHistoryScreen(),
                ),
              ],
            ),
          ],
        ),
        // BRANCH 1: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeDashboard(),
              routes: [
                GoRoute(
                  path: 'daily-tasks',
                  builder: (context, state) => const DailyTasksScreen(),
                ),
              ],
            ),
          ],
        ),
        // 🌟 BRANCH 2: Analytics (THE NEW TAB)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsScreen(),
            ),
          ],
        ),
        // BRANCH 3: Menu 
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/menu',
              builder: (context, state) => const MenuMainScreen(), 
              routes: [
                GoRoute(
                  path: 'profile', 
                  builder: (context, state) => const ProfileScreen(),
                ),
                GoRoute(
                  path: 'settings', 
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/welcome' ||
        state.matchedLocation == '/forgot-password';

    if (session != null && isAuthRoute) {
      return '/home'; 
    }

    if (session == null && !isAuthRoute) {
      return '/welcome'; 
    }

    return null;
  },
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gdreefwxoftmhekchszr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcmVlZnd4b2Z0bWhla2Noc3pyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5OTY5MjQsImV4cCI6MjA4OTU3MjkyNH0.uUtp4zOZupEe4ZA3lp2xtOeaCk_ba60XumVlXIgrE9U',
  );

  runApp(const CarbonSense());
}

class CarbonSense extends StatelessWidget {
  const CarbonSense({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp.router(
          title: 'CarbonSense',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          routerConfig: _router,
        );
      },
    );
  }
}