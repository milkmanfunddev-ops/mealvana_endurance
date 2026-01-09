import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/sync/data_sync_service.dart';

part 'athlete_data_sync_provider.g.dart';

/// Provider that syncs a specific athlete's data from Supabase (on-demand)
/// This is triggered when a coach views athlete details and taps refresh
/// Fetches events, activities, and carb loading plans for the specified athlete
///
/// Note: Does NOT invalidate athleteDetailController - the controller handles
/// reloading its own data after this sync completes
@riverpod
Future<void> athleteDataSync(
  Ref ref,
  String relationshipId,
  String athleteUserId,
) async {
  final syncService = ref.read(dataSyncServiceProvider);

  // Sync only this athlete's data (lightweight, focused sync)
  await syncService.syncAthleteData(athleteUserId);

  // Don't invalidate here - let the calling controller reload its own data
  // This avoids "Ref disposed" errors when the auto-dispose provider cleans up
}
