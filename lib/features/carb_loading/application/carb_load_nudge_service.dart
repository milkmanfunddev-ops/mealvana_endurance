import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _prefs = prefs,
       _clock = clock ?? DateTime.now;

  final CarbNudgeGateway _gateway;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const _shownDayKey = 'carb_nudge_last_shown_day';
  static String _armedKey(String eventId) => 'carb_nudge_armed_$eventId';

  static String _dayStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Arm (or re-arm) the event's remaining fires. Idempotent: cancels the
  /// full id set first, then schedules what's still ahead of the clock.
  Future<void> armEvent(CarbNudgeEvent event) async {
    final now = _clock();
    await disarmEvent(event.id);
    final fires = CarbNudgeEngine.remainingFires(
      raceDate: event.raceDate,
      now: now,
    );
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
    }
    // The armed-day record is the catch-up's evidence that a scheduled fire
    // existed for a given day (delivery itself is the OS's, unobservable).
    await _prefs.setStringList(
      _armedKey(event.id),
      fires.map(_dayStr).toList(),
    );
  }

  /// Cancel every fire for the event (plan created, or event gone).
  Future<void> disarmEvent(String eventId) async {
    for (final id in CarbNudgeEngine.allNotificationIds(eventId)) {
      await _gateway.cancel(id);
    }
    await _prefs.remove(_armedKey(eventId));
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

    for (final event in events) {
      if (eventIdsWithPlan.contains(event.id)) {
        await disarmEvent(event.id);
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
      await _prefs.setString(_shownDayKey, today);
      return; // at most one nudge per day, full stop
    }
  }
}

@riverpod
CarbLoadNudgeService carbLoadNudgeService(Ref ref) => CarbLoadNudgeService(
  gateway: NotificationServiceCarbNudgeGateway(),
  prefs: ref.watch(sharedPreferencesProvider),
);
