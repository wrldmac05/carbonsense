import 'package:carbonsense/features/activity/activity_log_screen.dart';
import 'package:carbonsense/features/tasks/daily_tasks_screen.dart';
import 'package:carbonsense/features/auth/forgot_password_screen.dart';
import 'package:carbonsense/features/navigation/home_dashboard.dart';
import 'package:carbonsense/features/auth/login_screen.dart';
import 'package:carbonsense/features/navigation/main_navigation.dart';
import 'package:carbonsense/features/navigation/help_support_screen.dart';
import 'package:carbonsense/features/profile/profile_screen.dart';
import 'package:carbonsense/features/auth/register_screen.dart';
import 'package:carbonsense/features/activity/score_history_screen.dart';
import 'package:carbonsense/features/activity/food_camera_screen.dart';
import 'package:carbonsense/features/activity/bill_scanner_screen.dart';
import 'package:carbonsense/features/profile/edit_profile_screen.dart';
import 'package:carbonsense/features/auth/welcome_screen.dart';
import 'package:carbonsense/features/analytics/analytics_screen.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:carbonsense/features/auth/reset_password_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';

// 🌟 CRITICAL FIX 1: Brought Riverpod import back!
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

final _router = GoRouter(
  initialLocation: '/welcome',
  routes: [
    // --- AUTH ROUTES (FULL SCREEN) ---
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/help-support',
      builder: (context, state) => const HelpSupportScreen(),
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
                // 🌟 ADD THIS SUB-ROUTE INSIDE THE ACTIVITY LOG BRANCH
                GoRoute(
                  path: 'food-scanner',
                  name: 'food-scanner',
                  builder: (context, state) => const FoodCameraScreen(),
                ),
                GoRoute(
                  path: 'bill-scanner',
                  name: 'bill-scanner',
                  builder: (context, state) => const BillScannerScreen(),
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
        // BRANCH 2: Analytics
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],

  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;

    // 🌟 ULTIMATE CATCH-ALL: Checks the entire URL string (scheme, host, path, and fragments)
    final urlString = state.uri.toString();
    final isResetRoute = urlString.contains('reset-password');

    final path = state.uri.path;
    final isAuthRoute =
        path == '/login' ||
        path == '/register' ||
        path == '/welcome' ||
        path == '/forgot-password';

    // 1. If the URL has "reset-password" anywhere in it, rescue them!
    if (isResetRoute) {
      // If GoRouter hasn't officially placed them on the exact path yet, force it:
      if (state.matchedLocation != '/reset-password') {
        return '/reset-password';
      }
      return null; // They are safely on the screen, let them stay!
    }

    // 2. 🌟 NEW: Detect if this is the email confirmation link from a new registration
    // Supabase appends 'type=signup' into the link hash after validation
    final isEmailConfirmation = urlString.contains('type=signup');
    if (isEmailConfirmation) {
      // Intentionally sign out to destroy the auto-login session
      Supabase.instance.client.auth.signOut();
      // Force them to the login page
      return '/login';
    }

    // 2. Logged in but trying to see auth screens -> Home
    if (session != null && isAuthRoute) {
      return '/home';
    }

    // 3. NOT logged in but trying to see private screens -> Login
    if (session == null && !isAuthRoute) {
      return '/login';
    }

    return null; // Otherwise, let them go where they requested
  },
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://gdreefwxoftmhekchszr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcmVlZnd4b2Z0bWhla2Noc3pyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5OTY5MjQsImV4cCI6MjA4OTU3MjkyNH0.uUtp4zOZupEe4ZA3lp2xtOeaCk_ba60XumVlXIgrE9U',
  );

  // 🌟 CRITICAL FIX 2: Wrapped the app in ProviderScope!
  runApp(const ProviderScope(child: CarbonSense()));
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
