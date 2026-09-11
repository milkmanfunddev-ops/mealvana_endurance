/// The moment resolver (vana-moment spec, M-1, M-2 and Cadence) over rows
/// shaped the way the producers shape them: activities through
/// [ActivityMapper] from a Supabase row (a finished one as mark-done or the
/// Garmin match writes it), meal logs through [MealLog.fromSupabaseJson]. The
/// clock is local wall time, as `scheduled_date_time` is.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_exchange.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/recovery_window_authority.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

final _mapper = ActivityMapper(logger: NoopAppLogger());

/// A Supabase `activities` row. `scheduled_date_time` is timestamp without
/// time zone: the athlete's wall clock, no offset.
Activity _activity({
  String id = 'act-run',
  String title = 'Tempo run',
  String type = 'running',
  String scheduled = '2026-09-11T17:30:00',
  String status = 'planned',
  int? durationMinutes = 60,
  int? timeBeforeMinutes = 60,
  String? deletedAt,
  String createdAt = '2026-09-01T12:00:00+00:00',
  String? plannedTime,
  String? actualTime,
  int? actualDurationMinutes,
  String? completedAt,
}) => _mapper.fromJson({
  'id': id,
  'user_id': 'user-1',
  'activity_type': type,
  'title': title,
  'scheduled_date_time': scheduled,
  'status': status,
  'duration_minutes': durationMinutes,
  'time_before_minutes': timeBeforeMinutes,
  'deleted_at': deletedAt,
  'created_at': createdAt,
  'updated_at': '2026-09-01T12:00:00+00:00',
  'planned_time': plannedTime,
  'actual_time': actualTime,
  'actual_duration_minutes': actualDurationMinutes,
  'completed_at': completedAt,
});

/// This morning's run, marked done in the app: mark-done writes
/// `actual_time` and `completed_at` as the planned start (G1), not the moment
/// of the tap. 06:30 for 60 min: it ended at 07:30.
Activity _markedDone({
  String id = 'act-am',
  String scheduled = '2026-09-11T06:30:00',
  int durationMinutes = 60,
}) => _activity(
  id: id,
  title: 'Easy run',
  scheduled: scheduled,
  status: 'completed',
  durationMinutes: durationMinutes,
  plannedTime: scheduled,
  actualTime: scheduled,
  completedAt: scheduled,
);

/// The same run matched by Garmin: the measured start replaces
/// `scheduled_date_time` and `actual_time` (naive local), the measured length
/// fills both durations, `completed_at` is the end as a UTC instant. Started
/// 06:40, ran 70 min: it ended at 07:50.
Activity _garminMatched() => _activity(
  id: 'act-am',
  title: 'Easy run',
  scheduled: '2026-09-11T06:40:00',
  status: 'completed',
  durationMinutes: 70,
  plannedTime: '2026-09-11T06:30:00',
  actualTime: '2026-09-11T06:40:00',
  actualDurationMinutes: 70,
  completedAt: DateTime(2026, 9, 11, 7, 50).toUtc().toIso8601String(),
);

/// A Supabase `meal_logs` row. `eaten_at` and `created_at` are timestamptz,
/// which PostgREST returns in UTC.
MealLog _log({
  String id = 'log-1',
  DateTime? eatenAt,
  required DateTime createdAt,
}) => MealLog.fromSupabaseJson({
  'id': id,
  'user_id': 'user-1',
  'log_date': '2026-09-11',
  'slot': 'snack',
  'name': 'Bagel and honey',
  'source': 'manual',
  'items': <Object?>[],
  'eaten_at': eatenAt?.toUtc().toIso8601String(),
  'created_at': createdAt.toUtc().toIso8601String(),
  'updated_at': createdAt.toUtc().toIso8601String(),
  'is_deleted': false,
})!;

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 9, 11, hour, minute);

VanaMoment? _resolve({
  required DateTime now,
  List<Activity>? activities,
  List<MealLog> logs = const [],
  Set<String> rung = const {},
  Set<String> answered = const {},
}) => resolveVanaMoment(
  now: now,
  activities: activities ?? [_activity()],
  mealLogs: logs,
  rung: rung,
  answered: answered,
);

void main() {
  group('M-1: the pre-workout window', () {
    test('not raised before the window opens', () {
      expect(_resolve(now: _at(16, 29)), isNull);
    });

    test('raised once the window has opened and nothing is logged', () {
      final moment = _resolve(now: _at(16, 30))!;
      expect(moment.kind, VanaMomentKind.preWorkout);
      expect(moment.activityId, 'act-run');
      expect(moment.title, 'Tempo run');
      expect(moment.startsAt, _at(17, 30));
      expect(moment.windowOpensAt, _at(16, 30));
      expect(moment.windowMinutes, 60);
      expect(moment.rings, isTrue);
      expect(moment.recovery, isNull);
    });

    test('a snack logged after the window opened retires it', () {
      final snack = _log(eatenAt: _at(16, 40), createdAt: _at(16, 41));
      expect(_resolve(now: _at(16, 45), logs: [snack]), isNull);
    });

    test('a log with no eaten time counts from when it was written', () {
      final snack = _log(createdAt: _at(16, 35));
      expect(_resolve(now: _at(16, 45), logs: [snack]), isNull);
    });

    test('a meal eaten before the window opened leaves it raised', () {
      final lunch = _log(eatenAt: _at(12, 30), createdAt: _at(16, 40));
      expect(_resolve(now: _at(16, 45), logs: [lunch]), isNotNull);
    });

    test('the workout starting retires it', () {
      expect(_resolve(now: _at(17, 30)), isNull);
      final started = _activity(status: 'in_progress');
      expect(_resolve(now: _at(17, 10), activities: [started]), isNull);
    });

    test('a completed, skipped, draft or deleted workout raises nothing', () {
      for (final activity in [
        _activity(status: 'completed'),
        _activity(status: 'skipped'),
        _activity(status: 'draft'),
        _activity(deletedAt: '2026-09-11T10:00:00+00:00'),
      ]) {
        expect(
          _resolve(now: _at(16, 45), activities: [activity]),
          isNull,
          reason: activity.status.name,
        );
      }
    });

    test('a workout on another day raises nothing today', () {
      final tomorrow = _activity(scheduled: '2026-09-12T00:30:00');
      expect(_resolve(now: _at(23, 45), activities: [tomorrow]), isNull);
    });

    test('with no window on the row, the §3a table default applies', () {
      // 100 min, no preset: the 1.5–2.5 h row, 150 min.
      final ride = _activity(
        id: 'act-ride',
        type: 'cycling',
        scheduled: '2026-09-11T18:00:00',
        durationMinutes: 100,
        timeBeforeMinutes: null,
      );
      expect(_resolve(now: _at(15, 29), activities: [ride]), isNull);
      final moment = _resolve(now: _at(15, 30), activities: [ride])!;
      expect(moment.windowOpensAt, _at(15, 30));
      expect(moment.windowMinutes, 150);
    });
  });

  test('with no window on the row, a session planned close to its start '
      'has its window clamped to the time there was', () {
    // Planned at 17:20 for 18:00: the authority caps the window at the 40
    // minutes left when it was planned.
    final ride = _activity(
      id: 'act-late',
      type: 'cycling',
      scheduled: '2026-09-11T18:00:00',
      durationMinutes: 100,
      timeBeforeMinutes: null,
      createdAt: DateTime(2026, 9, 11, 17, 20).toUtc().toIso8601String(),
    );
    expect(_resolve(now: _at(17, 19), activities: [ride]), isNull);
    expect(_resolve(now: _at(17, 20), activities: [ride])!.windowMinutes, 40);
  });

  test('the moment says what it is about and that it is a to-do', () {
    final moment = _resolve(now: _at(16, 45))!;
    expect(moment.kind.topic, VanaExchangeTopic.fuelPlan);
    expect(moment.kind.toDo, isTrue);
    expect(moment.partOfDay, VanaMomentPartOfDay.evening);
  });

  group('M-2: the recovery window', () {
    test('a session marked done, nothing logged since it ended: raised', () {
      final moment = _resolve(now: _at(7, 45), activities: [_markedDone()])!;
      expect(moment.kind, VanaMomentKind.recovery);
      expect(moment.activityId, 'act-am');
      expect(moment.title, 'Easy run');
      expect(moment.startsAt, _at(6, 30));
      expect(moment.windowOpensAt, _at(7, 30));
      expect(moment.rings, isTrue);
      expect(moment.kind.toDo, isTrue);
      expect(moment.kind.topic, VanaExchangeTopic.fuelPlan);
      expect(moment.partOfDay, VanaMomentPartOfDay.morning);
    });

    test('a session matched from Garmin ends when it measured', () {
      final moment = _resolve(now: _at(8), activities: [_garminMatched()])!;
      expect(moment.kind, VanaMomentKind.recovery);
      expect(moment.windowOpensAt, _at(7, 50));
    });

    test('with no fuel-demanding session within 8 h, it is the 2 h protein '
        'window, and it names no next session', () {
      final moment = _resolve(now: _at(7, 45), activities: [_markedDone()])!;
      expect(moment.closesAt, _at(9, 30));
      expect(moment.windowMinutes, 120);
      expect(moment.recovery!.branch, RecoveryBranch.relaxed);
      expect(moment.recovery!.nextActivityId, isNull);
      expect(moment.toWire(), {
        'kind': 'recovery',
        'activity_id': 'act-am',
        'window_minutes': 120,
        'branch': 'relaxed',
      });
    });

    test('a fuel-demanding session 8 to 24 h away: relaxed, 2 h, naming it '
        'so the copy can lean earlier', () {
      // Tonight's 17:30 run is 10 h after the 07:30 end.
      final moment = _resolve(
        now: _at(7, 45),
        activities: [_markedDone(), _activity()],
      )!;
      expect(moment.closesAt, _at(9, 30));
      expect(moment.toWire(), {
        'kind': 'recovery',
        'activity_id': 'act-am',
        'window_minutes': 120,
        'branch': 'relaxed',
        'next_activity_id': 'act-run',
      });
    });

    test('a session a day or more away is not named', () {
      final tomorrow = _activity(scheduled: '2026-09-12T08:00:00');
      final moment = _resolve(
        now: _at(7, 45),
        activities: [_markedDone(), tomorrow],
      )!;
      expect(moment.recovery!.nextActivityId, isNull);
    });

    test('the window closed: nothing raised', () {
      expect(_resolve(now: _at(9, 29), activities: [_markedDone()]), isNotNull);
      expect(_resolve(now: _at(9, 30), activities: [_markedDone()]), isNull);
    });

    test('something logged after it ended retires it', () {
      final shake = _log(eatenAt: _at(7, 40), createdAt: _at(7, 41));
      expect(
        _resolve(now: _at(7, 45), activities: [_markedDone()], logs: [shake]),
        isNull,
      );
    });

    test('a log from before it ended leaves it raised', () {
      final gel = _log(eatenAt: _at(6, 15), createdAt: _at(7, 35));
      expect(
        _resolve(now: _at(7, 45), activities: [_markedDone()], logs: [gel]),
        isNotNull,
      );
    });

    test('a fuel-demanding session within 8 h makes it urgent: 4 h, naming '
        'the next session', () {
      final ride = _activity(
        id: 'act-ride',
        type: 'cycling',
        title: 'Lunch ride',
        scheduled: '2026-09-11T13:00:00',
        durationMinutes: 90,
      );
      final moment = _resolve(
        now: _at(7, 45),
        activities: [_markedDone(), ride],
      )!;
      expect(moment.kind, VanaMomentKind.recovery);
      expect(moment.closesAt, _at(11, 30));
      expect(moment.recovery!.branch, RecoveryBranch.urgent);
      expect(moment.toWire(), {
        'kind': 'recovery',
        'activity_id': 'act-am',
        'window_minutes': 240,
        'branch': 'urgent',
        'next_activity_id': 'act-ride',
      });
    });

    test('a short session next does not make it urgent', () {
      final jog = _activity(
        id: 'act-jog',
        scheduled: '2026-09-11T12:00:00',
        durationMinutes: 30,
      );
      final moment = _resolve(
        now: _at(7, 45),
        activities: [_markedDone(), jog],
      )!;
      expect(moment.closesAt, _at(9, 30));
      expect(moment.recovery!.branch, RecoveryBranch.relaxed);
    });

    test('a session under 60 min, or a strength hour, raises nothing', () {
      for (final activity in [
        _markedDone(durationMinutes: 45),
        _activity(
          id: 'act-gym',
          type: 'other',
          title: 'Strength',
          scheduled: '2026-09-11T06:30:00',
          status: 'completed',
          actualTime: '2026-09-11T06:30:00',
        ),
      ]) {
        expect(
          _resolve(now: _at(7, 45), activities: [activity]),
          isNull,
          reason: activity.title,
        );
      }
    });

    test('a planned session whose time has passed is not finished', () {
      final missed = _activity(scheduled: '2026-09-11T06:30:00');
      expect(_resolve(now: _at(7, 45), activities: [missed]), isNull);
    });

    test('Garmin refining a marked-done session keeps the same moment', () {
      final marked = _resolve(now: _at(7, 45), activities: [_markedDone()])!;
      final matched = _resolve(
        now: _at(8),
        activities: [_garminMatched()],
        rung: {marked.key},
      )!;
      expect(matched.key, marked.key);
      expect(matched.rings, isFalse);
    });
  });

  group('overlap: the window that closes sooner speaks', () {
    // This morning's run ended 07:30. A ride at 11:00 is under 8 h away, so
    // the run's recovery runs 4 h, to 11:30.
    Activity ride(String scheduled, int window) => _activity(
      id: 'act-ride',
      type: 'cycling',
      title: 'Lunch ride',
      scheduled: scheduled,
      durationMinutes: 90,
      timeBeforeMinutes: window,
    );

    test('the ride starting before the recovery closes: the pre-workout '
        'moment', () {
      // The ride's window opens 09:00 and closes at its 11:00 start.
      final moment = _resolve(
        now: _at(9, 15),
        activities: [_markedDone(), ride('2026-09-11T11:00:00', 120)],
      )!;
      expect(moment.kind, VanaMomentKind.preWorkout);
      expect(moment.activityId, 'act-ride');
    });

    test('the recovery closing before the ride starts: the recovery '
        'moment', () {
      // A 13:00 ride: its window opens 10:00 and closes at 13:00; the
      // recovery closes at 11:30.
      final moment = _resolve(
        now: _at(10, 15),
        activities: [_markedDone(), ride('2026-09-11T13:00:00', 180)],
      )!;
      expect(moment.kind, VanaMomentKind.recovery);
      expect(moment.activityId, 'act-am');
    });
  });

  group('cadence', () {
    test('a moment that has rung is still live, and does not ring again', () {
      final first = _resolve(now: _at(16, 45))!;
      final again = _resolve(now: _at(16, 50), rung: {first.key})!;
      expect(again.key, first.key);
      expect(again.rings, isFalse);
    });

    test('moving the workout makes a new window, which rings', () {
      final first = _resolve(now: _at(16, 45))!;
      final moved = _activity(scheduled: '2026-09-11T17:45:00');
      final next = _resolve(
        now: _at(16, 50),
        activities: [moved],
        rung: {first.key},
      )!;
      expect(next.key, isNot(first.key));
      expect(next.rings, isTrue);
    });

    test('an answered moment retires', () {
      final first = _resolve(now: _at(16, 45))!;
      expect(_resolve(now: _at(16, 50), answered: {first.key}), isNull);
    });

    test('a third moment in a day is not raised', () {
      final rungToday = {'pre_workout:act-am:x', 'recovery:act-am'};
      expect(_resolve(now: _at(16, 45), rung: rungToday), isNull);
    });

    test('a moment that rang before the cap was reached stays live', () {
      final first = _resolve(now: _at(16, 45))!;
      final again = _resolve(
        now: _at(16, 50),
        rung: {'recovery:act-am', first.key},
      )!;
      expect(again.key, first.key);
      expect(again.rings, isFalse);
    });

    test('one at a time: the window that closes sooner wins', () {
      final swim = _activity(
        id: 'act-swim',
        type: 'swimming',
        title: 'Masters swim',
        scheduled: '2026-09-11T17:00:00',
        timeBeforeMinutes: 45,
      );
      final moment = _resolve(
        now: _at(16, 45),
        activities: [_activity(), swim],
      )!;
      expect(moment.activityId, 'act-swim');
    });
  });
}
