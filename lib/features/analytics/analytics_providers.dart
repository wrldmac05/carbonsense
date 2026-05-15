// lib/features/analytics/analytics_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Stream the AI Insight
final aiInsightStreamProvider = StreamProvider.autoDispose<String>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value("No user logged in.");

  return Supabase.instance.client
      .from('ai_prescriptions')
      .stream(primaryKey: ['id']) // Assuming 'id' is your primary key
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(1)
      .map((event) {
        if (event.isNotEmpty) {
          return event.first['ai_text'] as String;
        }
        return "Your AI Eco-Coach is gathering enough data to generate your personalized insight. Keep logging!";
      });
});

// 2. Stream the Activity Logs for the Chart
final activityLogsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return Supabase.instance.client
      .from('activity_logs')
      .stream(primaryKey: ['id']) // Assuming 'id' is your primary key
      .eq('user_id', userId)
      .map((data) => List<Map<String, dynamic>>.from(data));
});