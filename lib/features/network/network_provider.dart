import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
// 🌟 1. Import Supabase to check the session
import 'package:supabase_flutter/supabase_flutter.dart';

enum NetworkState { strong, weak, lost, initial }

class NetworkNotifier extends StateNotifier<NetworkState> {
  NetworkNotifier() : super(NetworkState.initial) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  Timer? _pingTimer;

  void _init() {
    // Listen for interface changes (e.g. Wi-Fi turned off)
    _subscription = _connectivity.onConnectivityChanged.listen((_) {
      _checkConnection();
    });

    // Periodically test the connection strength every 15 seconds
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkConnection();
    });

    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Ping Google DNS to test actual internet availability and speed
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 3));
      stopwatch.stop();
      socket.destroy();

      // If ping takes longer than 400ms, consider it weak
      if (stopwatch.elapsedMilliseconds > 400) {
        if (state != NetworkState.weak) state = NetworkState.weak;
      } else {
        if (state != NetworkState.strong) state = NetworkState.strong;
      }
    } catch (_) {
      // If the socket connection fails or times out, connection is lost
      if (state != NetworkState.lost) state = NetworkState.lost;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }
}

// Global provider for the network state
final networkProvider = StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});

// 🌟 2. Added Auth State Provider to listen for login/logout events
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

class GlobalNetworkBanner extends ConsumerWidget {
  final Widget child;

  const GlobalNetworkBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkState = ref.watch(networkProvider);

    // 🌟 3. Watch the auth state so the banner rebuilds immediately on login/logout
    ref.watch(authStateProvider);

    // 🌟 4. Check if the user currently has an active session
    final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    // 🌟 5. We only show the banner if it's lost/weak AND the user is logged in.
    final bool showBanner = (networkState == NetworkState.lost || networkState == NetworkState.weak) && isLoggedIn;

    final String message = networkState == NetworkState.lost ? 'No Internet Connection' : 'Weak Connection';

    final Color backgroundColor = networkState == NetworkState.lost ? Colors.red.shade600 : Colors.orange.shade600;

    final IconData icon = networkState == NetworkState.lost ? Icons.wifi_off : Icons.wifi_1_bar;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // The main app content
          child,

          // The animated global banner
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            // Adjust the top value based on your app's SafeArea/AppBar needs
            top: showBanner ? MediaQuery.of(context).padding.top + 10 : -100.0,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: backgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
