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

// Root navigator key
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',

  routes: [
    // ============================================================
    // AUTH & STANDALONE ROUTES
    // ============================================================
    GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),

    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),

    // Password recovery destination
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

    // ============================================================
    // SHELL ROUTE - BOTTOM NAVIGATION
    // ============================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigation(navigationShell: navigationShell);
      },

      branches: [
        // ========================================================
        // BRANCH 0: ACTIVITY
        // ========================================================
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

        // ========================================================
        // BRANCH 1: HOME
        // ========================================================
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeDashboard(),

              routes: [GoRoute(path: 'daily-tasks', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const DailyTasksScreen())],
            ),
          ],
        ),

        // ========================================================
        // BRANCH 2: ANALYTICS
        // ========================================================
        StatefulShellBranch(
          routes: [GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen())],
        ),
      ],
    ),
  ],

  // ============================================================
  // ROUTER REDIRECT
  // ============================================================
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;

    final path = state.uri.path;
    final urlString = state.uri.toString();

    // ------------------------------------------------------------
    // Password recovery route
    // ------------------------------------------------------------
    //
    // This route must remain accessible even when there is no
    // normal authenticated session yet.
    //
    final isResetRoute = path == '/reset-password';

    // ------------------------------------------------------------
    // Authentication routes
    // ------------------------------------------------------------

    final isAuthRoute = path == '/login' || path == '/forgot-password';

    // ------------------------------------------------------------
    // Public routes
    // ------------------------------------------------------------

    final isPublicRoute = isAuthRoute || isResetRoute || path == '/terms-of-use' || path == '/privacy-policy';

    // ------------------------------------------------------------
    // Password reset
    // ------------------------------------------------------------
    //
    // Do NOT redirect a password recovery user to /login.
    // Supabase may establish the recovery session around the
    // same time that the deep link is processed.
    //

    if (isResetRoute) {
      return null;
    }

    // ------------------------------------------------------------
    // Email confirmation
    // ------------------------------------------------------------

    final isEmailConfirmation = urlString.contains('type=signup');

    if (isEmailConfirmation) {
      Supabase.instance.client.auth.signOut();
      return '/login';
    }

    // ------------------------------------------------------------
    // Authenticated users should not remain on login/forgot
    // password screens.
    // ------------------------------------------------------------

    if (session != null && isAuthRoute) {
      return '/home';
    }

    // ------------------------------------------------------------
    // Unauthenticated users cannot access protected routes.
    // ------------------------------------------------------------

    if (session == null && !isPublicRoute) {
      return '/login';
    }

    return null;
  },
);

// ================================================================
// MAIN
// ================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await Supabase.initialize(
    url: 'https://gdreefwxoftmhekchszr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcmVlZnd4b2Z0bWhla2Noc3pyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5OTY5MjQsImV4cCI6MjA4OTU3MjkyNH0.uUtp4zOZupEe4ZA3lp2xtOeaCk_ba60XumVlXIgrE9U',
  );

  runApp(const ProviderScope(child: CarbonSense()));
}

// ================================================================
// CARBONSENSE ROOT WIDGET
// ================================================================

class CarbonSense extends ConsumerStatefulWidget {
  const CarbonSense({super.key});

  @override
  ConsumerState<CarbonSense> createState() => _CarbonSenseState();
}

class _CarbonSenseState extends ConsumerState<CarbonSense> {
  RealtimeChannel? _securityChannel;

  @override
  void initState() {
    super.initState();

    _listenToAuthChanges();
  }

  // ==============================================================
  // SUPABASE AUTH STATE LISTENER
  // ==============================================================

  void _listenToAuthChanges() {
    // 🔍 TEMP DEBUG
    debugPrint('🔍 LISTENER ATTACHED at ${DateTime.now()}');

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      // 🔍 TEMP DEBUG
      debugPrint('🔍 AUTH EVENT: $event | session: ${session?.user.id} | at ${DateTime.now()}');

      // ----------------------------------------------------------
      // PASSWORD RECOVERY
      // ----------------------------------------------------------
      //
      // Supabase emits passwordRecovery after a recovery link
      // has been processed and the temporary recovery session
      // has been established.
      //
      if (event == AuthChangeEvent.passwordRecovery) {
        _router.go('/reset-password');
        return;
      }

      // ----------------------------------------------------------
      // NORMAL AUTHENTICATED SESSION
      // ----------------------------------------------------------

      if (session != null) {
        _subscribeToSecurityChannel(session.user.id);
      } else {
        _unsubscribeSecurityChannel();
      }
    });
  }

  // ==============================================================
  // SECURITY CHANNEL
  // ==============================================================

  void _subscribeToSecurityChannel(String userId) {
    _unsubscribeSecurityChannel();

    _securityChannel = Supabase.instance.client
        .channel('public:user_profiles:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_profiles',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) async {
            final isBanned = payload.newRecord['is_banned'] as bool? ?? false;

            final isArchived = payload.newRecord['is_archived'] as bool? ?? false;

            if (isBanned || isArchived) {
              await Supabase.instance.client.auth.signOut();

              _router.go('/login');

              _showCustomBanDialog(
                title: isBanned ? 'Account Suspended' : 'Account Archived',
                message: isBanned ? 'Your account has been suspended by an administrator due to policy violations.' : 'Your account has been archived by an administrator.',
              );
            }
          },
        )
        .subscribe();
  }

  void _unsubscribeSecurityChannel() {
    if (_securityChannel != null) {
      Supabase.instance.client.removeChannel(_securityChannel!);

      _securityChannel = null;
    }
  }

  // ==============================================================
  // BAN / ARCHIVE DIALOG
  // ==============================================================

  void _showCustomBanDialog({required String title, required String message}) {
    final context = _rootNavigatorKey.currentContext;

    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFED7D7), width: 2),
                ),
                child: const Center(child: Text('🚫', style: TextStyle(fontSize: 28))),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Color(0xFF718096), height: 1.5),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Acknowledge', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _unsubscribeSecurityChannel();

    super.dispose();
  }

  // ==============================================================
  // BUILD
  // ==============================================================

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
