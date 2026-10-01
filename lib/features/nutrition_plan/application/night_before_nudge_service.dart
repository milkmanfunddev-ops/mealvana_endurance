import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/app_config.dart';
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
    bool fastFire = false,
  }) : _gateway = gateway,
       _prefs = prefs,
       _analytics = analytics,
       _fastFire = fastFire,
       _clock = clock ?? DateTime.now;

  final NightBeforeNudgeGateway _gateway;
  final SharedPreferences _prefs;
  final AnalyticsTracker _analytics;
  final DateTime Function() _clock;

  /// DEV ONLY. Fires two minutes from now instead of 19:00-the-evening-before,
  /// so a nudge can be exercised on a device without waiting for the evening.
  /// Set from the provider, which requires BOTH the dev flavor and an explicit
  /// dart-define — a prod build cannot reach this even if the flag is passed.
  final bool _fastFire;

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
    // ignore: avoid_print
    print('[NIGHT_BEFORE] evaluate candidates=${workouts.length} '
        'fastFire=$_fastFire now=$now');
    final armed = (_prefs.getStringList(_armedKey) ?? const []).toSet();

    for (final w in workouts) {
      // Ruled 2026-09-30 (second pass): having a plan no longer means silence,
      // it means a DIFFERENT nudge. So plan-existence selects the variant
      // rather than gating the arm.
      final variant = w.hasPlan
          ? NightBeforeVariant.rehearse
          : NightBeforeVariant.noPlan;

      // Under the dev override the variants keep their relative offset, so the
      // "never stack" property still holds while testing on a device.
      final fireAt = _fastFire
          ? now.add(
              Duration(
                minutes: variant == NightBeforeVariant.noPlan ? 2 : 3,
              ),
            )
          : NightBeforeNudgeEngine.fireInstantFor(w.start, variant);

      final shouldArm =
          NightBeforeNudgeEngine.isLong(w.durationMinutes) &&
          (_fastFire || fireAt.isAfter(now));

      final id = NightBeforeNudgeEngine.notificationId(w.id);
      // Keyed by variant: a workout that swaps no_plan -> rehearse must be
      // able to report `sent` again. Keyed by id alone, the swap would fire a
      // notification the funnel never recorded.
      final armKey = '${w.id}|${variant.tag}';

      if (!shouldArm) {
        // Idempotent: cancelling an id that was never scheduled is a no-op,
        // and this is the path that honours "skip entirely when a plan
        // exists" for a plan created AFTER arming.
        if (armed.any((k) => k.startsWith('${w.id}|'))) {
          await _gateway.cancel(id);
          armed.removeWhere((k) => k.startsWith('${w.id}|'));
        }
        continue;
      }

      // Re-arm unconditionally: the workout's time, duration or PLAN STATE may
      // have moved since it was scheduled, and zonedSchedule replaces by id.
      // This is also the swap-on-late-plan path — same slot, new variant.
      await _gateway.cancel(id);
      // Drop only the OTHER variant's key, never this one: removing this
      // variant's key would make `armed.add` succeed on every sweep and
      // re-report `sent` each time, inflating the funnel denominator.
      armed.removeWhere((k) => k.startsWith('${w.id}|') && k != armKey);
      await _gateway.schedule(
        id: id,
        title: variant == NightBeforeVariant.noPlan
            ? NightBeforeNudgeEngine.titleFor(w.type)
            : NightBeforeNudgeEngine.rehearseTitle,
        body: variant == NightBeforeVariant.noPlan
            ? NightBeforeNudgeEngine.noPlanBody
            : NightBeforeNudgeEngine.rehearseBody(w.type),
        fireAt: fireAt,
        payload: NightBeforeNudgeEngine.payloadFor(w.id, variant),
      );

      // Deliberate, permanent diagnostics. The DI-25 lesson applies here too:
      // a scheduling path whose only evidence is a notification that may or may
      // not appear is indistinguishable from one that never ran.
      // ignore: avoid_print
      print('[NIGHT_BEFORE] armed id=${w.id} variant=${variant.tag} '
          'fireAt=$fireAt fastFire=$_fastFire title="${variant == NightBeforeVariant.noPlan ? NightBeforeNudgeEngine.titleFor(w.type) : NightBeforeNudgeEngine.rehearseTitle}"');

      if (armed.add(armKey)) {
        // "Sent" at arm time, deliberately. A local notification's actual
        // delivery is the OS's business and is not observable to us, so this
        // is the closest honest signal — a scheduled nudge that the OS drops
        // is counted here as sent and will simply never be tapped.
        await _analytics.trackNightBeforeNudgeSent(
          activityId: w.id,
          durationMinutes: w.durationMinutes!,
          scheduledFor: fireAt,
          variant: variant.tag,
        );
      }
    }

    await _prefs.setStringList(_armedKey, armed.toList());
    await _attributePlanCreation(workouts, now);
  }

  /// Records a tap so a plan created soon after can be attributed to it.
  ///
  /// Only the no-plan variant seeds attribution: a rehearse tap lands on a
  /// plan that already exists, so "a plan appeared afterwards" would be
  /// meaningless there. The rehearse variant HAS NO SUCCESS SIGNAL YET —
  /// whoever adds one should not read its silence as failure.
  Future<void> recordTap(
    String activityId, {
    NightBeforeVariant variant = NightBeforeVariant.noPlan,
  }) async {
    await _analytics.trackNightBeforeNudgeTapped(
      activityId: activityId,
      variant: variant.tag,
    );
    if (variant != NightBeforeVariant.noPlan) return;
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

/// DEV-ONLY fire-time override, opt-in at build time:
///   flutter run --flavor dev --dart-define=NUDGE_FAST_FIRE=true
/// It requires BOTH the compile-time define AND the dev flavor at runtime, so
/// a prod build cannot take this path even if the define is passed.
const bool _nudgeFastFireDefine = bool.fromEnvironment('NUDGE_FAST_FIRE');

final nightBeforeNudgeServiceProvider = Provider<NightBeforeNudgeService>(
  (ref) => NightBeforeNudgeService(
    gateway: const NotificationServiceNightBeforeGateway(),
    prefs: ref.watch(sharedPreferencesProvider),
    analytics: ref.watch(analyticsTrackerProvider),
    fastFire:
        _nudgeFastFireDefine && ref.watch(appConfigProvider).devModeEnabled,
  ),
);
