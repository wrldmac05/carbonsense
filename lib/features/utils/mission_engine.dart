import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionEngine {
  static Future<List<String>> evaluateTelemetry({
    required String userId,
    required String category,
    required String activityName,
    bool isMeatless = false,
  }) async {
    final client = Supabase.instance.client;
    List<String> newlyCompletedMissions = [];

    try {
      final pendingTasksResponse = await client
          .from('user_tasks')
          .select('user_task_id, tasks_dictionary(*)')
          .eq('user_id', userId)
          .eq('is_completed', false);

      final lowerActivity = activityName.toLowerCase();

      for (var taskRecord in pendingTasksResponse) {
        final taskDict = taskRecord['tasks_dictionary'];
        final taskId = taskRecord['user_task_id'];
        final taskTag = taskDict['target_lifestyle_tag'];
        final taskDesc = taskDict['description'].toString().toLowerCase();

        // 🛑 NEW: Skip this task entirely if it requires manual reflection
        final validationMethod = taskDict['validation_method'] ?? 'telemetry';
        if (validationMethod == 'reflection') {
          continue;
        }

        bool isMatch = false;

        if (category == 'Commute' && taskTag == 'Commute') {
          if (taskDesc.contains('public transit') &&
              (lowerActivity.contains('jeep') ||
                  lowerActivity.contains('bus') ||
                  lowerActivity.contains('transit') ||
                  lowerActivity.contains('train') ||
                  lowerActivity.contains('mrt') ||
                  lowerActivity.contains('lrt'))) {
            isMatch = true;
          } else if (taskDesc.contains('carpool') &&
              lowerActivity.contains('carpool')) {
            isMatch = true;
          }
        } else if (category == 'Diet' && taskTag == 'Diet') {
          // 🚀 SUPER-FAILSAFE:
          // Matches if AI said it's meatless OR if common plant-based ingredients are in the name
          final bool isConfirmedMeatless =
              isMeatless ||
              lowerActivity.contains('vegetable') ||
              lowerActivity.contains('plant') ||
              lowerActivity.contains('tofu') ||
              lowerActivity.contains('bean') ||
              lowerActivity.contains('lentil') ||
              lowerActivity.contains('vegan') ||
              lowerActivity.contains('vegetarian');

          // 🎯 WIDER KEYWORD NET:
          // Accounts for different ways you might have written the mission in the Supabase table
          final bool hasMeatlessKeyword =
              taskDesc.contains('plant-based') ||
              (taskDesc.contains('skip') && taskDesc.contains('meat')) ||
              taskDesc.contains('vegetarian') ||
              taskDesc.contains('meatless') ||
              taskDesc.contains('vegan') ||
              taskDesc.contains('no meat');

          if (hasMeatlessKeyword && isConfirmedMeatless) {
            isMatch = true;
          }
        } else if (category == 'Energy' && taskTag == 'Energy') {
          if (taskDesc.contains('air-dry') &&
              lowerActivity.contains('air dry')) {
            isMatch = true;
          }
        }

        if (isMatch) {
          await client
              .from('user_tasks')
              .update({
                'is_completed': true,
                'completed_at': DateTime.now().toIso8601String(),
              })
              .eq('user_task_id', taskId);

          newlyCompletedMissions.add(taskDict['description']);
        }
      }
      return newlyCompletedMissions;
    } catch (e) {
      // 🛑 CRITICAL: This will now expose any hidden Supabase errors in your console!
      debugPrint('❌ MISSION ENGINE ERROR: $e');
      return [];
    }
  }
}
