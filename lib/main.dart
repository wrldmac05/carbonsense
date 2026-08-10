import 'package:carbonsense/features/activity/activity_log_screen.dart';
import 'package:carbonsense/features/activity/log_activity_screen.dart';
import 'package:carbonsense/features/network/network_provider.dart';
import 'package:carbonsense/features/tasks/daily_tasks_screen.dart';
import 'package:carbonsense/features/auth/forgot_password_screen.dart';
import 'package:carbonsense/features/navigation/home_dashboard.dart';
import 'package:carbonsense/features/navigation/main_navigation.dart';
import 'package:carbonsense/features/navigation/help_support_screen.dart';
import 'package:carbonsense/features/profile/profile_screen.dart';
import 'package:carbonsense/features/activity/score_history_screen.dart';
import 'package:carbonsense/features/activity/food_camera_screen.dart';
import 'package:carbonsense/features/activity/manual_food_screen.dart';
import 'package:carbonsense/features/activity/manual_bill_screen.dart';
import 'package:carbonsense/features/activity/bill_scanner_screen.dart';
import 'package:carbonsense/features/profile/edit_profile_screen.dart';
import 'package:carbonsense/features/analytics/analytics_screen.dart';
import 'package:carbonsense/widgets/terms_of_use_screen.dart';
import 'package:carbonsense/widgets/privacy_policy_screen.dart';
import 'package:carbonsense/widgets/legal_terms_screen.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:carbonsense/features/auth/reset_password_screen.dart';
import 'package:carbonsense/features/auth/auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// 1. Declare a GlobalKey for the root navigator
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _router = GoRouter(
  // 2. Attach the root navigator key
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    // --- AUTH & STANDALONE ROUTES (FULL SCREEN) ---
    GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
    GoRoute(path: '/edit-profile', builder: (context, state) => const EditProfileScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/help-support', builder: (context, state) => const HelpSupportScreen()),
    GoRoute(path: '/terms-of-use', builder: (context, state) => const TermsOfUseScreen()),
    GoRoute(path: '/privacy-policy', builder: (context, state) => const PrivacyPolicyScreen()),
    GoRoute(
      path: '/legal',
      builder: (context, state) {
        final tabIndex = state.extra as int? ?? 0;
        return LegalTermsScreen(initialIndex: tabIndex);
      },
    ),

    // --- SHELL ROUTE (BOTTOM NAVIGATION BAR) ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigation(navigationShell: navigationShell);
      },
      branches: [
        // BRANCH 0: Activity Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              builder: (context, state) => const ActivityLogScreen(),
              routes: [
                GoRoute(path: 'score-history', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ScoreHistoryScreen()),
                GoRoute(
                  path: 'log-activity',
                  name: 'log-activity',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final category = state.extra as String?;
                    return LogActivityScreen(category: category);
                  },
                ),
                GoRoute(path: 'food-scanner', name: 'food-scanner', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const FoodCameraScreen()),
                GoRoute(path: 'manual-food', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ManualFoodLogScreen()),
                GoRoute(path: 'manual-bill', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ManualBillScreen()),
                GoRoute(path: 'bill-scanner', name: 'bill-scanner', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const BillScannerScreen()),
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
              routes: [GoRoute(path: 'daily-tasks', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const DailyTasksScreen())],
            ),
          ],
        ),

        // BRANCH 2: Analytics
        StatefulShellBranch(
          routes: [GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen())],
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final urlString = state.uri.toString();
    final isResetRoute = urlString.contains('reset-password');
    final path = state.uri.path;

    // Define auth and public routes
    final isAuthRoute = path == '/login' || path == '/forgot-password';
    final isPublicRoute = isAuthRoute || path == '/terms-of-use' || path == '/privacy-policy';

    if (isResetRoute) {
      if (state.matchedLocation != '/reset-password') {
        return '/reset-password';
      }
      return null;
    }
    final isEmailConfirmation = urlString.contains('type=signup');
    if (isEmailConfirmation) {
      Supabase.instance.client.auth.signOut();
      return '/login';
    }

    // Authenticated users hitting login or forgot-password go home
    if (session != null && isAuthRoute) {
      return '/home';
    }

    // Unauthenticated users trying to access non-public routes get redirected to login
    if (session == null && !isPublicRoute) {
      return '/login';
    }

    return null;
  },
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://gdreefwxoftmhekchszr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcmVlZnd4b2Z0bWhla2Noc3pyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5OTY5MjQsImV4cCI6MjA4OTU3MjkyNH0.uUtp4zOZupEe4ZA3lp2xtOeaCk_ba60XumVlXIgrE9U',
  );
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
          builder: (context, routerChild) {
            return GlobalNetworkBanner(child: routerChild ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
