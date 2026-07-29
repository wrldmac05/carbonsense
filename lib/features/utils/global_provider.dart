import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// This provider listens to the Supabase database in real-time.
// It sits globally above your UI, so it never pauses when you change screens.
final userProfileStreamProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        return Stream.value(null);
      }

      // Supabase's .stream() automatically handles the WebSocket Realtime connection!
      return Supabase.instance.client
          .from('user_profiles')
          .stream(primaryKey: ['profile_id']) // Tells Supabase what to watch
          .eq('user_id', userId)
          .map((data) => data.isNotEmpty ? data.first : null);
    });

final userTasksStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        return Stream.value([]);
      }

      // Stream user_tasks and map them to include the dictionary data
      return Supabase.instance.client
          .from('user_tasks')
          .stream(primaryKey: ['user_task_id'])
          .eq('user_id', userId)
          .asyncMap((tasksData) async {
            // For each task, fetch its corresponding dictionary entry if needed,
            // or fetch all dictionary entries once to attach them.
            final enrichedTasks = <Map<String, dynamic>>[];

            for (var task in tasksData) {
              final taskId = task['task_id'];
              var dictData = <String, dynamic>{};

              if (taskId != null) {
                final dictRes = await Supabase.instance.client
                    .from('tasks_dictionary')
                    .select()
                    .eq('task_id', taskId)
                    .maybeSingle();
                if (dictRes != null) {
                  dictData = dictRes;
                }
              }

              enrichedTasks.add({...task, 'tasks_dictionary': dictData});
            }

            return enrichedTasks;
          });
    });
// Stream provider to watch user activity logs in real-time with emission factors joined
final activityLogsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        return Stream.value([]);
      }

      return Supabase.instance.client
          .from('activity_logs')
          .stream(primaryKey: ['log_id']) // 🌟 Matches your primary key column
          .eq('user_id', userId)
          .asyncMap((logsData) async {
            final enrichedLogs = <Map<String, dynamic>>[];

            for (var log in logsData) {
              final factorId = log['factor_id'];
              var factorData = <String, dynamic>{};

              if (factorId != null) {
                final factorRes = await Supabase.instance.client
                    .from('emission_factors')
                    .select('activity_name, unit, category')
                    .eq('factor_id', factorId)
                    .maybeSingle();
                if (factorRes != null) {
                  factorData = factorRes;
                }
              }

              enrichedLogs.add({...log, 'emission_factors': factorData});
            }

            return enrichedLogs;
          });
    });
