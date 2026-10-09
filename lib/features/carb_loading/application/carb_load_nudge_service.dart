import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/prefs_provider.dart';
import '../domain/carb_nudge_engine.dart';

part 'carb_load_nudge_service.g.dart';

/// The one seam between G27's decisions and the notification plugin, so the
/// L2 drives the REAL service against a recording fake. The production
/// implementation is [NotificationServiceCarbNudgeGateway].
abstract class CarbNudgeGateway {
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  });

  Future<void> cancel(int id);

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  /// Whether the OS will actually deliver. Read at SCHEDULE time so the
  /// silent permission bail inside the plugin layer becomes visible in
  /// analytics (`notif_scheduled` with notifications_enabled=false) rather
  /// than vanishing (qa pin 2026-09-27).
  Future<bool> notificationsEnabled();
}

class NotificationServiceCarbNudgeGateway implements CarbNudgeGateway {
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

  @override
  Future<bool> notificationsEnabled() =>
      NotificationService.areNotificationsEnabled();

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) => NotificationService.showCarbNudge(
    id: id,
    title: title,
    body: body,
    payload: payload,
  );
}

/// One event as the nudge sees it.
typedef CarbNudgeEvent = ({String id, String name, DateTime raceDate});

/// G27 (qa 9b15fcc): the race-window carb-load nudge.
///
/// Delivery contract:
///  * SCHEDULED — local notifications at 06:00 local, daily, race−3…race−1
///    (never race day), armed when the event exists/syncs; arming
///    mid-window schedules only the remaining fires.
///  * Plan creation CANCELS every remaining fire; plan deletion RE-ARMS the
///    remainder — plan-existence is the truth, not a fired flag.
///  * ON-OPEN CATCH-UP — inside the window with no plan, show at most ONE
///    nudge per local day across BOTH paths, surviving restarts: the
///    shown-day marker persists, a catch-up cancels today's still-pending
///    scheduled fire, and a scheduled fire that already passed today
///    (armed before 06:00) suppresses the catch-up.
class CarbLoadNudgeService {
  CarbLoadNudgeService({
    required CarbNudgeGateway gateway,
    required SharedPreferences prefs,
    required AnalyticsTracker analytics,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _prefs = prefs,
       _analytics = analytics,
       _clock = clock ?? DateTime.now;

  final CarbNudgeGateway _gateway;
  final SharedPreferences _prefs;
  final AnalyticsTracker _analytics;
  final DateTime Function() _clock;

  /// Shared discriminators on every nudge event (qa pin 2026-09-27): the
  /// 09-17 CTA schema's vocabulary, so this CTA joins the others. Consumers
  /// MUST read `cta_transport` before comparing rates — a local "fired" and
  /// a remote "sent" are not the same measurement.
  static const Map<String, dynamic> _ctaProps = {
    'cta': 'carb_load',
    'cta_transport': 'local',
  };

  static const _shownDayKey = 'carb_nudge_last_shown_day';
  static const _armedKeyPrefix = 'carb_nudge_armed_';
  static String _armedKey(String eventId) => '$_armedKeyPrefix$eventId';

  static String _dayStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Arm (or re-arm) the event's remaining fires. Idempotent: cancels the
  /// full id set first, then schedules what's still ahead of the clock.
  Future<void> armEvent(CarbNudgeEvent event) async {
    final now = _clock();
    // Days already armed BEFORE this re-arm. A fire whose time has passed may
    // have delivered, and that fact never stops being true — if we dropped it
    // the catch-up would lose its only evidence and nudge a second time the
    // same day (ruled: at most one per day across both paths).
    final previouslyArmed =
        _prefs.getStringList(_armedKey(event.id)) ?? const <String>[];
    await disarmEvent(event.id);
    final fires = CarbNudgeEngine.remainingFires(
      raceDate: event.raceDate,
      now: now,
    );
    // Read once per arm, not per fire: the answer cannot change mid-loop and
    // the plugin layer would otherwise swallow a denial silently.
    final enabled = await _gateway.notificationsEnabled();
    for (final fireAt in fires) {
      final daysBefore = CarbNudgeEngine.daysBeforeFor(
        raceDate: event.raceDate,
        fireAt: fireAt,
      );
      await _gateway.schedule(
        id: CarbNudgeEngine.notificationId(event.id, daysBefore),
        title: CarbNudgeEngine.title,
        body: CarbNudgeEngine.body(event.name),
        fireAt: fireAt,
        payload: CarbNudgeEngine.payload(event.id),
      );
      await _analytics.track(
        'notif_scheduled',
        properties: {
          ..._ctaProps,
          'event_id': event.id,
          'days_before': daysBefore,
          'fire_at': fireAt.toIso8601String(),
          'notifications_enabled': enabled,
        },
      );
    }
    // The armed-day record is the catch-up's evidence that a scheduled fire
    // existed for a given day (delivery itself is the OS's, unobservable).
    // Carry forward past days rather than replacing: see [previouslyArmed].
    final today = _dayStr(now);
    final armedDays = <String>{
      ...previouslyArmed.where((d) => d.compareTo(today) <= 0),
      ...fires.map(_dayStr),
    }.toList()
      ..sort();
    await _prefs.setStringList(_armedKey(event.id), armedDays);
  }

  /// Cancel every fire for the event. [reason] is the pinned vocabulary —
  /// plan_created | event_deleted | window_passed | permission_lost — so
  /// "scheduled but never tapped" decomposes into *couldn't have fired* vs
  /// *fired and was ignored*. Null means bookkeeping (the idempotent clear
  /// inside armEvent), which emits nothing: a re-arm reports itself through
  /// fresh notif_scheduled rows, not a cancel/re-arm pair.
  ///
  /// Returns whether the event had an armed record, so a caller can write
  /// down a disarm that found nothing (CLAUDE.md D9; ticket 80).
  Future<bool> disarmEvent(String eventId, {String? reason}) async {
    for (final id in CarbNudgeEngine.allNotificationIds(eventId)) {
      await _gateway.cancel(id);
    }
    final hadArmed =
        (_prefs.getStringList(_armedKey(eventId)) ?? const []).isNotEmpty;
    await _prefs.remove(_armedKey(eventId));
    if (reason == null || !hadArmed) return hadArmed;
    await _analytics.track(
      'notif_cancelled',
      properties: {..._ctaProps, 'event_id': eventId, 'reason': reason},
    );
    return hadArmed;
  }

  /// Event ids that have an armed record but are not in [liveEventIds]:
  /// their event was deleted somewhere this device's delete never ran (the
  /// coach portal, another device, a sync removal).
  List<String> _orphanedArmedEventIds(Set<String> liveEventIds) {
    const prefix = _armedKeyPrefix;
    return [
      for (final key in _prefs.getKeys())
        if (key.startsWith(prefix) &&
            !liveEventIds.contains(key.substring(prefix.length)))
          key.substring(prefix.length),
    ];
  }

  /// The open/resume pass: keeps every event's armed state matching
  /// plan-existence, then shows the catch-up when the window is open, no
  /// plan exists, and nothing has been shown today by either path.
  Future<void> evaluateOnOpen({
    required List<CarbNudgeEvent> events,
    required Set<String> eventIdsWithPlan,
  }) async {
    final now = _clock();
    final today = _dayStr(now);

    // Ticket 80: an armed event that no longer exists still has three OS
    // fires pending for a race that is gone. The list is the caller's whole
    // event set (an empty list means no events), so every armed record
    // outside it is an orphan.
    final liveIds = {for (final event in events) event.id};
    for (final orphanId in _orphanedArmedEventIds(liveIds)) {
      await disarmEvent(orphanId, reason: 'event_deleted');
    }

    for (final event in events) {
      if (eventIdsWithPlan.contains(event.id)) {
        await disarmEvent(event.id, reason: 'plan_created');
      } else if (!CarbNudgeEngine.inWindow(
            raceDate: event.raceDate,
            now: now,
          ) &&
          !now.isBefore(event.raceDate)) {
        // Race reached/passed with the window never converted.
        await disarmEvent(event.id, reason: 'window_passed');
      } else if (CarbNudgeEngine.remainingFires(
        raceDate: event.raceDate,
        now: now,
      ).isNotEmpty) {
        await armEvent(event);
      }
    }

    if (_prefs.getString(_shownDayKey) == today) return;

    for (final event in events) {
      if (eventIdsWithPlan.contains(event.id)) continue;
      if (!CarbNudgeEngine.inWindow(raceDate: event.raceDate, now: now)) {
        continue;
      }
      final todayFire = CarbNudgeEngine.todayFire(
        raceDate: event.raceDate,
        now: now,
      )!;
      final armedDays = _prefs.getStringList(_armedKey(event.id)) ?? const [];
      final todayWasArmed = armedDays.contains(today);
      if (todayWasArmed && !now.isBefore(todayFire)) {
        // The scheduled fire already delivered today — one per day stands.
        continue;
      }
      final daysBefore = CarbNudgeEngine.daysBeforeFor(
        raceDate: event.raceDate,
        fireAt: todayFire,
      );
      if (todayWasArmed) {
        // Catch-up takes today's slot; the pending 06:00 fire must not
        // double it.
        await _gateway.cancel(
          CarbNudgeEngine.notificationId(event.id, daysBefore),
        );
        await _prefs.setStringList(
          _armedKey(event.id),
          armedDays.where((d) => d != today).toList(),
        );
      }
      await _gateway.show(
        id: CarbNudgeEngine.notificationId(event.id, daysBefore),
        title: CarbNudgeEngine.title,
        body: CarbNudgeEngine.body(event.name),
        payload: CarbNudgeEngine.payload(event.id),
      );
      // The ONLY show the app genuinely observes. The 06:00 scheduled fires
      // are delivered by the OS with no callback, so they get no fired event
      // — inventing one would repeat the biased-proxy error the 09-17 item
      // documents (a tap opens the app, so tapped fires look delivered and
      // un-tapped ones do not; CTR inflates toward 100%).
      await _analytics.track(
        'notif_fired',
        properties: {
          ..._ctaProps,
          'event_id': event.id,
          'days_before': daysBefore,
          'path': 'catchup',
        },
      );
      await _prefs.setString(_shownDayKey, today);
      return; // at most one nudge per day, full stop
    }
  }
}

@riverpod
CarbLoadNudgeService carbLoadNudgeService(Ref ref) => CarbLoadNudgeService(
  gateway: NotificationServiceCarbNudgeGateway(),
  prefs: ref.watch(sharedPreferencesProvider),
  analytics: ref.watch(appExternalDepsProvider).analytics,
);
