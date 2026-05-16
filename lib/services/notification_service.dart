import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Initialize notification setup
  Future<void> initNotifications() async {
    // 1. Request Permission from the user (Required for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions.');
      
      // 2. Get the unique FCM token for this specific device
      await tokenRefreshAndSync();

      // 3. Listen for token updates (in case Firebase refreshes it)
      _fcm.onTokenRefresh.listen((newToken) async {
        await _saveTokenToSupabase(newToken);
      });

      // 4. Handle foreground messages (when user is actively using the app)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground message: ${message.notification?.title}');
        // You can use a local notification package here later if you want 
        // to show a banner while the app is open.
      });
    } else {
      debugPrint('User declined or has not accepted notification permissions.');
    }
  }

  // Fetch the token and push it to Supabase
  Future<void> tokenRefreshAndSync() async {
    try {
      String? token = await _fcm.getToken(
        vapidKey: "BGa_r7H5DwjijVk3sbkAC-LWRkOkYcLat55Sf801YYy8SuBhprL-sjlHp_F2qBWUwbmL5nCCkpXQiO93gAbR-3Y", 
      );
      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  // Helper method to write the token to your user_profiles table
  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No logged-in user found. Skipping token sync.');
      return;
    }

    try {
      await _supabase
          .from('user_profiles')
          .update({'fcm_token': token})
          .eq('user_id', userId);
      debugPrint('FCM Token successfully synchronized with Supabase.');
    } catch (e) {
      debugPrint('Error saving FCM token to Supabase: $e');
    }
  }
}