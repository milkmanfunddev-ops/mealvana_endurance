/// The moment resolver (vana-moment spec, M-1 and Cadence) over rows shaped
/// the way the producers shape them: activities through [ActivityMapper]
/// from a Supabase row, meal logs through [MealLog.fromSupabaseJson]. The
/// clock is local wall time, as `scheduled_date_time` is.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
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
  'created_at': '2026-09-01T12:00:00+00:00',
  'updated_at': '2026-09-01T12:00:00+00:00',
});

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
