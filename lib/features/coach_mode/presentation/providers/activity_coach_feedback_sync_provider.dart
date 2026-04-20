import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/sync/data_sync_service.dart';
import 'activity_coach_feedback_provider.dart';

part 'activity_coach_feedback_sync_provider.g.dart';

/// Provider that syncs coach messages for a specific activity from Supabase
/// AND subscribes to Supabase Realtime for instant updates.
///
/// When the widget is displayed, this provider:
/// 1. Syncs existing messages from Supabase to local DB
/// 2. Sets up a Realtime subscription for new activity comments
/// 3. Invalidates the feedback provider whenever new data arrives
@riverpod
Future<void> activityCoachFeedbackSync(
  Ref ref,
  String activityId,
) async {
  final syncService = ref.read(dataSyncServiceProvider);
  final logger = ref.read(appLoggerProvider);

  // 1. Initial sync: pull latest coach messages for this activity
  await syncService.syncCoachMessagesForActivity(activityId);

  // 2. Invalidate the feedback provider to reload fresh data from local database
  ref.invalidate(activityCoachFeedbackProvider(activityId));

  // 3. Set up Realtime subscription for new activity comments
  final supabase = Supabase.instance.client;
  final channelName = 'activity-feedback:$activityId';

  final channel = supabase
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'coach_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'activity_id',
          value: activityId,
        ),
        callback: (payload) {
          logger.info(
            'Realtime activity feedback received',
            context: 'ACTIVITY_FEEDBACK_SYNC',
            data: {
              'activityId': activityId,
              'eventType': payload.eventType.toString(),
            },
          );

          // Re-sync and refresh the feedback list
          syncService.syncCoachMessagesForActivity(activityId).then((_) {
            ref.invalidate(activityCoachFeedbackProvider(activityId));
          });
        },
      )
      .subscribe();

  logger.info(
    'Subscribed to realtime activity feedback',
    context: 'ACTIVITY_FEEDBACK_SYNC',
    data: {'activityId': activityId, 'channelName': channelName},
  );

  // Clean up subscription when provider is disposed
  ref.onDispose(() {
    logger.info(
      'Unsubscribing from realtime activity feedback',
      context: 'ACTIVITY_FEEDBACK_SYNC',
      data: {'channelName': channelName},
    );
    channel.unsubscribe();
    supabase.removeChannel(channel);
  });
}
