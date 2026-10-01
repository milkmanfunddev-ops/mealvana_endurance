import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/app_config.dart';
import '../../../shared/services/prefs_provider.dart';
import '../domain/night_before_nudge_engine.dart';
import '../../../shared/services/launch_trail.dart';

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

  /// Dev-override bookkeeping: the fire instant already chosen for an armKey,
  /// so a resume does not move it. Production never reads this — see
  /// [_fastFireInstant].
  static const _fastFireAtKey = 'night_before_nudge_fast_fire_at';

  /// `<activityId>|<epochMs>` for the most recent tap, so a plan created
  /// afterwards can be attributed to the nudge.
  static const _tappedKey = 'night_before_nudge_tapped';

  /// How far apart two nudges sharing a base instant are spaced.
  ///
  /// Anything greater than zero fixes the collision; 30s keeps a handful of
  /// nudges inside the same minute or two of 19:00, which is what the ruling
  /// means by "the evening before". The grouping in [evaluate] guarantees a
  /// slot can never push a nudge into another base's slot range.
  static const int _staggerStepSeconds = 30;

  /// How long after a tap a new plan still counts as "the nudge worked".
  static const Duration attributionWindow = Duration(hours: 24);

  /// The open/resume pass: bring every candidate's armed state in line with
  /// the rules, and attribute any plan created since the last tap.
  Future<void> evaluate(List<NightBeforeWorkout> workouts) async {
    final now = _clock();
    // Taped, not just printed. `print` is invisible in a release build, which
    // is why the on-device trail dialog showed launch lines and nothing about
    // the sweep — so a nudge that never armed and one that armed and was
    // swallowed looked identical (Xuan, 2026-10-01: "contains no log").
    LaunchTrail.add(
      'nudge evaluate candidates=${workouts.length} fastFire=$_fastFire',
    );
    final armed = (_prefs.getStringList(_armedKey) ?? const []).toSet();
    final candidateIds = workouts.map((w) => w.id).toSet();

    // RECONCILE THE ARMED SET DOWNWARD, not just candidates upward.
    //
    // The per-workout loop below can only disarm something it still SEES. A
    // workout that has left the calendar entirely — deleted, rescheduled out of
    // the window — never appears as a candidate, so its pending notification
    // was never cancelled and fired anyway. Observed 2026-10-01: a nudge fired
    // for a DELETED brick and landed on a create screen for a dead workout.
    //
    // So walk the armed set first and cancel anything no longer a candidate.
    // This also retires the variant question for such a row: a deleted workout
    // has no correct variant.
    for (final key in armed.toList()) {
      final split = key.lastIndexOf('|');
      final armedId = split > 0 ? key.substring(0, split) : key;
      if (candidateIds.contains(armedId)) continue;
      await _gateway.cancel(NightBeforeNudgeEngine.notificationId(armedId));
      armed.remove(key);
      LaunchTrail.add('nudge DISARMED id=$armedId (gone from the calendar)');
    }

    // THE COLLISION FIX. Two nudges at the same instant mean ONE delivery.
    //
    // `fireInstantFor` returns the evening-before date at 19:00, so EVERY
    // same-day no-plan nudge used to land on exactly 19:00:00.000 — and iOS
    // delivers one of two same-instant legacy notifications. The per-workout
    // ruling ("each workout gets its own nudge") was therefore defeated at the
    // delivery layer for precisely the multi-sport athlete the feature targets.
    // Evidenced on device 2026-10-01: five armed, the 40-mi ride paired to the
    // microsecond with a rehearse nudge on every re-arm and never once
    // delivered, while the one nudge with an instant to itself always did.
    //
    // So the stagger is computed WITHIN each identical base instant: group the
    // candidates by the base they resolve to, order each group by id so the
    // slots are deterministic and survive a re-arm, and space them 30s apart.
    // Grouping rather than one global index is what keeps the offset from ever
    // walking into another group's base — the noPlan and rehearse bases are 30
    // minutes apart, and a slot can only ever move a nudge within its own
    // group.
    final bases = <String, ({NightBeforeVariant variant, DateTime base})>{};
    for (final w in workouts) {
      // Ruled 2026-09-30 (second pass): having a plan no longer means silence,
      // it means a DIFFERENT nudge. So plan-existence selects the variant
      // rather than gating the arm.
      final variant = w.hasPlan
          ? NightBeforeVariant.rehearse
          : NightBeforeVariant.noPlan;
      bases[w.id] = (
        variant: variant,
        // The dev override needs no variant offset: one workout has one
        // notification id and only ever one armed variant, so the two can
        // never coexist. The old per-variant base was what made the stagger
        // collide — a 60s variant gap is an exact multiple of the 30s step, so
        // a rehearse nudge landed on top of the no-plan nudge two slots later.
        base: _fastFire
            ? now.add(const Duration(minutes: 2))
            : NightBeforeNudgeEngine.fireInstantFor(w.start, variant),
      );
    }

    final slots = <String, int>{};
    final byBase = <String, List<String>>{};
    for (final entry in bases.entries) {
      byBase
          .putIfAbsent(entry.value.base.toIso8601String(), () => <String>[])
          .add(entry.key);
    }
    for (final ids in byBase.values) {
      ids.sort();
      for (var i = 0; i < ids.length; i++) {
        slots[ids[i]] = i;
      }
    }

    for (final w in workouts) {
      final variant = bases[w.id]!.variant;
      final armKeyForFire = '${w.id}|${variant.tag}';
      final staggered = bases[w.id]!.base.add(
        Duration(seconds: _staggerStepSeconds * (slots[w.id] ?? 0)),
      );
      final fireAt = _fastFire
          ? _heldFastFireInstant(armKeyForFire, now, staggered)
          : staggered;

      final shouldArm =
          NightBeforeNudgeEngine.isLong(w.durationMinutes) &&
          (_fastFire || fireAt.isAfter(now));

      final id = NightBeforeNudgeEngine.notificationId(w.id);
      // Keyed by variant: a workout that swaps no_plan -> rehearse must be
      // able to report `sent` again. Keyed by id alone, the swap would fire a
      // notification the funnel never recorded.
      final armKey = armKeyForFire;

      if (!shouldArm) {
        // Idempotent: cancelling an id that was never scheduled is a no-op,
        // and this is the path that honours "skip entirely when a plan
        // exists" for a plan created AFTER arming.
        if (armed.any((k) => k.startsWith('${w.id}|'))) {
          await _gateway.cancel(id);
          armed.removeWhere((k) => k.startsWith('${w.id}|'));
          LaunchTrail.add('nudge DISARMED id=${w.id} (no longer eligible)');
        } else {
          LaunchTrail.add(
            'nudge skip id=${w.id} duration=${w.durationMinutes} '
            'long=${NightBeforeNudgeEngine.isLong(w.durationMinutes)}',
          );
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
      LaunchTrail.add(
        'nudge ARMED id=${w.id} variant=${variant.tag} fireAt=$fireAt '
        'notifId=$id fastFire=$_fastFire',
      );

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

  /// The dev override's fire instant, chosen ONCE per armKey and then held.
  ///
  /// WHY A HOLD EXISTS. `evaluate` re-arms unconditionally on every open and
  /// resume — correct, because a workout's time, duration or plan state may
  /// have moved — and under the override the instant is derived from `now`. So
  /// every touch of the app pushed every pending nudge further away. Observed
  /// 2026-10-01: resumes at 10:45:58, 10:46:02 and 10:52:16 re-lit a
  /// two-minute fuse before it could ever burn down, and the ride and brick
  /// nudges never fired at all.
  ///
  /// Production needs no hold and does not get one: [NightBeforeNudgeEngine.fireInstantFor]
  /// derives the instant from the WORKOUT's start, so re-arming reschedules
  /// the same 19:00.
  ///
  /// [candidate] is the already-staggered instant. Holding the FINAL value
  /// matters: holding a pre-stagger base and re-applying the slot would let a
  /// changed candidate list move a held nudge back on top of another one,
  /// which is the collision this release is fixing.
  DateTime _heldFastFireInstant(
    String armKey,
    DateTime now,
    DateTime candidate,
  ) {
    final held = _prefs.getStringList(_fastFireAtKey) ?? const <String>[];
    final kept = <String>[];
    DateTime? mine;

    for (final entry in held) {
      final split = entry.lastIndexOf('@');
      if (split <= 0) continue;
      final key = entry.substring(0, split);
      final at = DateTime.tryParse(entry.substring(split + 1));
      // Drop instants that have passed: that nudge has fired (or been missed),
      // and the next sweep should be free to arm a fresh one.
      if (at == null || !at.isAfter(now)) continue;
      kept.add(entry);
      if (key == armKey) mine = at;
    }

    if (mine != null) return mine;

    kept.add('$armKey@${candidate.toIso8601String()}');
    // Fire-and-forget: a dev-only bookkeeping write must not make the sweep
    // async-fragile, and a lost write only costs one re-stagger.
    _prefs.setStringList(_fastFireAtKey, kept);
    return candidate;
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
