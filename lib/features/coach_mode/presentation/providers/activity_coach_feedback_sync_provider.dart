import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/sync/data_sync_service.dart';
import 'activity_coach_feedback_provider.dart';

part 'activity_coach_feedback_sync_provider.g.dart';

/// Provider that syncs coach messages for a specific activity from Supabase
/// This is triggered when the ActivityCoachFeedbackWidget is displayed
/// to ensure athletes see the latest coach feedback immediately
@riverpod
Future<void> activityCoachFeedbackSync(
  Ref ref,
  String activityId,
) async {
  final syncService = ref.read(dataSyncServiceProvider);

  // Sync only coach messages for this activity (lightweight, focused sync)
  await syncService.syncCoachMessagesForActivity(activityId);

  // Invalidate the feedback provider to reload fresh data from local database
  ref.invalidate(activityCoachFeedbackProvider(activityId));
}
