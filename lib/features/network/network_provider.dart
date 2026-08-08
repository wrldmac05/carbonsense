import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Listen for connection status changes (Wi-Fi, Mobile Data, None)
    _subscription = _connectivity.onConnectivityChanged.listen((_) {
      _checkConnection();
    });

    // Periodically test connection strength every 15 seconds
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkConnection();
    });

    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      // 🌟 First check interface connection type
      final connectivityResults = await _connectivity.checkConnectivity();

      // If there's no interface active (no Wi-Fi and no Cellular data)
      if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
        if (state != NetworkState.lost) state = NetworkState.lost;
        return;
      }

      final stopwatch = Stopwatch()..start();

      // 🌟 Uses system DNS resolution which works seamlessly across Mobile Data (LTE/5G) and Wi-Fi
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));

      stopwatch.stop();

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // Ping threshold: > 800ms indicates weak/laggy cellular or Wi-Fi signal
        if (stopwatch.elapsedMilliseconds > 800) {
          if (state != NetworkState.weak) state = NetworkState.weak;
        } else {
          if (state != NetworkState.strong) state = NetworkState.strong;
        }
      } else {
        if (state != NetworkState.lost) state = NetworkState.lost;
      }
    } catch (_) {
      // If DNS lookup fails or times out, network connection is lost
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

// Auth state provider to track logged-in status
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

class GlobalNetworkBanner extends ConsumerWidget {
  final Widget child;

  const GlobalNetworkBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkState = ref.watch(networkProvider);
    ref.watch(authStateProvider);

    final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    final bool showBanner = (networkState == NetworkState.lost || networkState == NetworkState.weak) && isLoggedIn;

    final String message = networkState == NetworkState.lost ? 'No Internet' : 'Weak Signal';
    final Color backgroundColor = networkState == NetworkState.lost ? Colors.red.shade600 : Colors.orange.shade600;
    final IconData icon = networkState == NetworkState.lost ? Icons.wifi_off_rounded : Icons.signal_cellular_connected_no_internet_4_bar_rounded;

    // Calculate bottom offset so it floats right above the bottom navigation bar
    final double bottomInset = MediaQuery.of(context).padding.bottom + 90.0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // The main app content
          child,

          // 🌟 Compact, Pill-shaped floating banner
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            bottom: showBanner ? bottomInset : -100.0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                elevation: 4, // Softer shadow
                borderRadius: BorderRadius.circular(30), // Sleek pill shape
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Tighter padding
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // 🌟 Shrinks to fit content exactly
                    children: [
                      Icon(icon, color: Colors.white, size: 14), // Smaller icon
                      const SizedBox(width: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12, // Smaller font
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
