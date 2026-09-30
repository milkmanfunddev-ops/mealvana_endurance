import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/prefs_provider.dart';
import '../domain/night_before_nudge_engine.dart';

/// One long workout the night-before nudge may fire for.
typedef NightBeforeWorkout = ({
  String id,
  DateTime start,
  int? durationMinutes,
  bool hasPlan,
  ActivityType? type,
});

/// The scheduling surface, behind a seam so the service is testable without
/// the platform channel (same shape as [CarbNudgeGateway]).
abstract class NightBeforeNudgeGateway {
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  });

  Future<void> cancel(int id);
}

class NotificationServiceNightBeforeGateway implements NightBeforeNudgeGateway {
  const NotificationServiceNightBeforeGateway();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) => NotificationService.scheduleCarbNudge(
    id: id,
    title: title,
    body: body,
    fireAt: fireAt,
    payload: payload,
  );

  @override
  Future<void> cancel(int id) => NotificationService.cancelById(id);
}

/// Arms, disarms and instruments the night-before long-workout nudge.
///
/// RULED 2026-09-30: long is >= 90 min, it fires at 19:00 local the evening
/// before, and it is SKIPPED ENTIRELY when a fuelling plan already exists —
/// no variant, no nag. That last rule is why [evaluate] cancels as readily as
/// it schedules: a plan created after the nudge was armed must take the
/// pending notification away with it, or the athlete gets told to do something
/// they have already done.
class NightBeforeNudgeService {
  NightBeforeNudgeService({
    required NightBeforeNudgeGateway gateway,
    required SharedPreferences prefs,
    required AnalyticsTracker analytics,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _prefs = prefs,
       _analytics = analytics,
       _clock = clock ?? DateTime.now;

  final NightBeforeNudgeGateway _gateway;
  final SharedPreferences _prefs;
  final AnalyticsTracker _analytics;
  final DateTime Function() _clock;

  /// Activity ids currently armed — the set we may need to cancel later.
  static const _armedKey = 'night_before_nudge_armed';

  /// `<activityId>|<epochMs>` for the most recent tap, so a plan created
  /// afterwards can be attributed to the nudge.
  static const _tappedKey = 'night_before_nudge_tapped';

  /// How long after a tap a new plan still counts as "the nudge worked".
  static const Duration attributionWindow = Duration(hours: 24);

  /// The open/resume pass: bring every candidate's armed state in line with
  /// the rules, and attribute any plan created since the last tap.
  Future<void> evaluate(List<NightBeforeWorkout> workouts) async {
    final now = _clock();
    final armed = (_prefs.getStringList(_armedKey) ?? const []).toSet();

    for (final w in workouts) {
      final shouldArm =
          NightBeforeNudgeEngine.isLong(w.durationMinutes) &&
          !w.hasPlan &&
          NightBeforeNudgeEngine.isFireAhead(workoutStart: w.start, now: now);

      final id = NightBeforeNudgeEngine.notificationId(w.id);

      if (!shouldArm) {
        // Idempotent: cancelling an id that was never scheduled is a no-op,
        // and this is the path that honours "skip entirely when a plan
        // exists" for a plan created AFTER arming.
        if (armed.contains(w.id)) {
          await _gateway.cancel(id);
          armed.remove(w.id);
        }
        continue;
      }

      // Re-arm unconditionally: the workout's time or duration may have moved
      // since it was scheduled, and zonedSchedule replaces by id.
      await _gateway.cancel(id);
      await _gateway.schedule(
        id: id,
        title: NightBeforeNudgeEngine.titleFor(w.type),
        body: NightBeforeNudgeEngine.body(
          NightBeforeNudgeEngine.formatDuration(w.durationMinutes!),
        ),
        fireAt: NightBeforeNudgeEngine.fireInstantFor(w.start),
        payload: NightBeforeNudgeEngine.payload(w.id),
      );

      if (armed.add(w.id)) {
        // "Sent" at arm time, deliberately. A local notification's actual
        // delivery is the OS's business and is not observable to us, so this
        // is the closest honest signal — a scheduled nudge that the OS drops
        // is counted here as sent and will simply never be tapped.
        await _analytics.trackNightBeforeNudgeSent(
          activityId: w.id,
          durationMinutes: w.durationMinutes!,
          scheduledFor: NightBeforeNudgeEngine.fireInstantFor(w.start),
        );
      }
    }

    await _prefs.setStringList(_armedKey, armed.toList());
    await _attributePlanCreation(workouts, now);
  }

  /// Records a tap so a plan created soon after can be attributed to it.
  Future<void> recordTap(String activityId) async {
    await _analytics.trackNightBeforeNudgeTapped(activityId: activityId);
    await _prefs.setString(
      _tappedKey,
      '$activityId|${_clock().millisecondsSinceEpoch}',
    );
  }

  /// Fires the plan-created event when the tapped workout has since gained a
  /// plan, inside the attribution window.
  ///
  /// Deliberately evaluated on the next sweep rather than hooked into plan
  /// creation: the hook would have to reach across features for a signal that
  /// is only ever read in aggregate, and a one-app-open delay costs the
  /// funnel nothing.
  Future<void> _attributePlanCreation(
    List<NightBeforeWorkout> workouts,
    DateTime now,
  ) async {
    final raw = _prefs.getString(_tappedKey);
    if (raw == null) return;

    final parts = raw.split('|');
    if (parts.length != 2) {
      await _prefs.remove(_tappedKey);
      return;
    }
    final tappedId = parts[0];
    final tappedMs = int.tryParse(parts[1]);
    if (tappedMs == null) {
      await _prefs.remove(_tappedKey);
      return;
    }

    final tappedAt = DateTime.fromMillisecondsSinceEpoch(tappedMs);
    if (now.difference(tappedAt) > attributionWindow) {
      await _prefs.remove(_tappedKey);
      return;
    }

    for (final w in workouts) {
      if (w.id == tappedId && w.hasPlan) {
        await _analytics.trackNightBeforeNudgePlanCreated(
          activityId: w.id,
          minutesAfterTap: now.difference(tappedAt).inMinutes,
        );
        await _prefs.remove(_tappedKey);
        return;
      }
    }
  }
}

final nightBeforeNudgeServiceProvider = Provider<NightBeforeNudgeService>(
  (ref) => NightBeforeNudgeService(
    gateway: const NotificationServiceNightBeforeGateway(),
    prefs: ref.watch(sharedPreferencesProvider),
    analytics: ref.watch(analyticsTrackerProvider),
  ),
);
