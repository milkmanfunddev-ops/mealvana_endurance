import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../activities/data/activities_repository.dart';
import '../../application/night_before_nudge_service.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../domain/night_before_nudge_engine.dart';
import '../../../../shared/services/launch_trail.dart';
import '../../../activities/domain/activity.dart';

/// The open/resume sweep that keeps the night-before nudge in step with what
/// is actually on the calendar.
///
/// Runs from the root widget on first frame and on every foreground resume,
/// alongside the carb-nudge sweep. Every failure is swallowed: a nudge must
/// never take the app down, and the next resume retries.
///
/// It looks TWO days ahead, not one. A sweep on Monday evening must be able to
/// arm Tuesday's 19:00 fire for a Wednesday workout, and an athlete who opens
/// the app rarely should still get the nudge for anything already on the
/// calendar.
class NightBeforeNudgeCoordinator {
  NightBeforeNudgeCoordinator(this.ref);

  final Ref ref;
  bool _running = false;

  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      final userId = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentUser
          ?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final repo = ref.read(activitiesRepositoryProvider);
      final rawActivities = await repo.getActivitiesForDateRange(
        userId,
        today,
        today.add(const Duration(days: 3)),
      );

      // Fill in a duration for the distance-only workouts FIRST, because the
      // `isLong` filter below is exactly where a NULL duration silently drops
      // out — the miss this nudge exists to prevent.
      //
      // The import seam cannot cover these: a provider re-sync of an unchanged
      // row writes nothing, so every workout already on the calendar was
      // unreachable from it. This sweep already reads these rows, so the
      // estimate costs no extra query.
      final activities = await repo.estimateMissingDurations(rawActivities);

      final planRepo = await ref.read(nutritionPlanRepositoryProvider.future);
      final candidates = <NightBeforeWorkout>[];
      for (final a in activities) {
        final start = a.scheduledDateTime;
        // Only the long ones are worth a plan lookup — the lookup reads the
        // activity row's embedded plan JSON, so this keeps the sweep cheap on
        // a busy calendar.
        // A workout that is not going to happen gets no nudge. The date-range
        // read already drops soft-deleted and brick-archived rows, but NOT a
        // skipped one, nor a tombstone whose deleted_at was never set — and
        // nothing downstream would catch it, because the sweep's only other
        // test is duration (2026-10-01: a nudge fired for a deleted brick).
        if (!_nudgeable(a.status)) continue;
        if (!NightBeforeNudgeEngine.isLong(a.durationMinutes)) continue;
        final plan = await planRepo.getNutritionPlanByActivityId(userId, a.id);
        candidates.add((
          id: a.id,
          start: start,
          durationMinutes: a.durationMinutes,
          hasPlan: plan != null,
          type: a.activityType,
        ));
      }

      // Say what the sweep did. The standing lesson from the DI-25 and launch
      // seams: a path that can fail silently must write down what it did —
      // armed-for-tomorrow and never-armed looked identical from outside, and
      // an estimate that did not happen looks the same as a short workout.
      final estimatedCount = activities
          .where((a) => a.isDurationEstimated)
          .length;
      LaunchTrail.add(
        'nudge sweep activities=${activities.length} '
        'estimated=$estimatedCount longCandidates=${candidates.length}',
      );
      await ref.read(nightBeforeNudgeServiceProvider).evaluate(candidates);
    } catch (e, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Night-before nudge sweep failed; will retry on next resume',
            context: 'NIGHT_BEFORE_NUDGE',
            error: e,
            stackTrace: stackTrace,
          );
    } finally {
      _running = false;
    }
  }

  /// Statuses a nudge is for: a workout still ahead of the athlete.
  ///
  /// Deliberately a whitelist. A new status should default to "no nudge" and
  /// have to argue its way in, rather than silently inheriting one.
  static bool _nudgeable(ActivityStatus status) => switch (status) {
    ActivityStatus.draft ||
    ActivityStatus.planned ||
    ActivityStatus.inProgress => true,
    ActivityStatus.completed ||
    ActivityStatus.skipped ||
    ActivityStatus.archivedForBrick ||
    ActivityStatus.deleted => false,
  };
}

final nightBeforeNudgeCoordinatorProvider =
    Provider<NightBeforeNudgeCoordinator>(NightBeforeNudgeCoordinator.new);
