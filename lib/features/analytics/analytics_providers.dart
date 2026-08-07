// lib/features/analytics/analytics_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Stream the GENERAL AI Insight (Macro View)
final generalAiInsightProvider = StreamProvider.autoDispose<String>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value("No user logged in.");

  return Supabase.instance.client.from('ai_prescriptions').stream(primaryKey: ['insight_id']).map((events) {
    // 1. Filter for this user and the 'general' context
    final userEvents = events.where((e) => e['user_id'] == userId && e['context_type'] == 'general').toList();

    // 2. Sort to get the newest one first
    userEvents.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    // 3. Return the text if it exists
    if (userEvents.isNotEmpty) {
      return userEvents.first['ai_text'] as String;
    }
    return "Your AI Eco-Coach is analyzing your overall trends. Keep logging activities!";
  });
});

// 2. Stream the MONTHLY AI Insight (Micro View)
final monthlyAiInsightProvider = StreamProvider.family.autoDispose<String, int>((ref, monthIndex) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value("No user logged in.");

  // 🌟 FIX: Automatically fetch the current year to match our new Edge Function format!
  final currentYear = DateTime.now().year;
  final targetContext = 'month_${monthIndex}_$currentYear'; // e.g., "month_3_2026"

  return Supabase.instance.client.from('ai_prescriptions').stream(primaryKey: ['insight_id']).map((events) {
    final userEvents = events.where((e) => e['user_id'] == userId && e['context_type'] == targetContext).toList();

    userEvents.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    if (userEvents.isNotEmpty) {
      return userEvents.first['ai_text'] as String;
    }
    return "No specific AI insight generated for this month yet.";
  });
});

// 3. Stream the Activity Logs for the Chart
final activityLogsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return Supabase.instance.client.from('activity_logs').stream(primaryKey: ['id']).map((events) {
    // Filter logs so we only see the current user's data
    return events.where((e) => e['user_id'] == userId).toList();
  });
});
