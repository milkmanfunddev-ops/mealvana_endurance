import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../activities/data/activities_repository.dart';
import '../../application/night_before_nudge_service.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../domain/night_before_nudge_engine.dart';

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
      final activities = await ref
          .read(activitiesRepositoryProvider)
          .getActivitiesForDateRange(
            userId,
            today,
            today.add(const Duration(days: 3)),
          );

      final planRepo = await ref.read(nutritionPlanRepositoryProvider.future);
      final candidates = <NightBeforeWorkout>[];
      for (final a in activities) {
        final start = a.scheduledDateTime;
        // Only the long ones are worth a plan lookup — the lookup reads the
        // activity row's embedded plan JSON, so this keeps the sweep cheap on
        // a busy calendar.
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

      // ignore: avoid_print
      print('[NIGHT_BEFORE] sweep userId=$userId activities=${activities.length} '
          'longCandidates=${candidates.length}');
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
}

final nightBeforeNudgeCoordinatorProvider =
    Provider<NightBeforeNudgeCoordinator>(NightBeforeNudgeCoordinator.new);
