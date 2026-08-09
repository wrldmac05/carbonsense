// lib/features/analytics/analytics_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🌟 1. Lookup Provider: Fetches emission factors once and maps them by factor_id
final emissionFactorsProvider = FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client.from('emission_factors').select('*');
    final Map<String, Map<String, dynamic>> factorsMap = {};

    for (var item in (response as List)) {
      // 🎯 FIXED: Changed item['id'] -> item['factor_id'] to match your SQL schema
      if (item['factor_id'] != null) {
        factorsMap[item['factor_id'].toString()] = Map<String, dynamic>.from(item);
      }
    }
    return factorsMap;
  } catch (e) {
    return {};
  }
});

// 2. Stream the GENERAL AI Insight (Macro View)
final generalAiInsightProvider = StreamProvider.autoDispose<String>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value("No user logged in.");

  return Supabase.instance.client.from('ai_prescriptions').stream(primaryKey: ['insight_id']).map((events) {
    final userEvents = events.where((e) => e['user_id'] == userId && e['context_type'] == 'general').toList();
    userEvents.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    if (userEvents.isNotEmpty) {
      return userEvents.first['ai_text'] as String;
    }
    return "Your AI Eco-Coach is analyzing your overall trends. Keep logging activities!";
  });
});

// 3. Stream the MONTHLY AI Insight (Micro View)
final monthlyAiInsightProvider = StreamProvider.family.autoDispose<String, int>((ref, monthIndex) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value("No user logged in.");

  final currentYear = DateTime.now().year;
  final targetContext = 'month_${monthIndex}_$currentYear';

  return Supabase.instance.client.from('ai_prescriptions').stream(primaryKey: ['insight_id']).map((events) {
    final userEvents = events.where((e) => e['user_id'] == userId && e['context_type'] == targetContext).toList();
    userEvents.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    if (userEvents.isNotEmpty) {
      return userEvents.first['ai_text'] as String;
    }
    return "No specific AI insight generated for this month yet.";
  });
});

// 4. Stream Activity Logs merged with Emission Factors
final activityLogsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  final factorsAsync = ref.watch(emissionFactorsProvider);
  final factorsMap = factorsAsync.asData?.value ?? {};

  return Supabase.instance.client.from('activity_logs').stream(primaryKey: ['log_id']).map((events) {
    return events.where((e) => e['user_id'] == userId).map((log) {
      final factorId = log['factor_id']?.toString();
      final factorData = factorId != null ? factorsMap[factorId] : null;

      return {...log, 'emission_factors': factorData};
    }).toList();
  });
});
