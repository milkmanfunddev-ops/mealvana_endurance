import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../activities/data/activities_repository.dart';
import '../../application/carbs_per_hour_service.dart';
import '../../domain/carbs_per_hour_summary.dart';

part 'carbs_per_hour_providers.g.dart';

/// Pure logic for the post-workout carbs/hr summary.
@riverpod
CarbsPerHourService carbsPerHourService(Ref ref) => const CarbsPerHourService();

/// The same-sport fueling baseline for the activity being reviewed.
///
/// Reads the user's recent completed efforts of [activityType] and reduces
/// them to qualifying per-session carbs/hr (oldest → newest, windowed). The
/// current session is excluded so it isn't compared against itself.
@riverpod
Future<CarbsPerHourBaseline> carbsPerHourBaseline(
  Ref ref,
  String activityId,
  ActivityType activityType,
) async {
  // const service — read (not watch) to avoid needless dependency tracking.
  final service = ref.read(carbsPerHourServiceProvider);
  final userId = await ref.watch(userIdProvider.future);
  final repo = ref.read(activitiesRepositoryProvider);

  final recent = await repo.getRecentCompletedActivitiesBySport(
    userId,
    activityType,
    excludeActivityId: activityId,
  );

  return service.baselineFromHistory(recent);
}
