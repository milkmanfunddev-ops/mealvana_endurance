import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/macro_cache_invalidation.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Pins the macro-cache invalidation window.
///
/// A day's macros are computed from activities on that day, on the day either
/// side (adjacent-day context), and from the total training hours of its Mon–Sun
/// week. So an activity on X can only stale-affect X's Monday-week plus X±1 —
/// nothing else. These tests fix that contract in both directions: the window
/// must be wide enough (no stale rows survive) and no wider (no needless cache
/// loss).
///
/// If the macro calculation ever reads activities from OUTSIDE this window — a
/// rolling 14-day load, a next-race lookahead — these tests will still pass while
/// the cache silently goes stale. Widen `daysAffectedByActivityOn` AND these
/// expectations together.
void main() {
  // 2026-07-15 is a Wednesday. Its Mon–Sun week is Jul 13 (Mon) .. Jul 19 (Sun).
  final wednesday = DateTime(2026, 7, 15);
  final monday = DateTime(2026, 7, 13);
  final sunday = DateTime(2026, 7, 19);

  final epoch = DateTime(2026, 1, 1);

  Activity activityOn(
    DateTime when, {
    String id = 'a1',
    String title = 'Run',
    int? durationMinutes,
    double? distanceMiles,
    IntensityLevel? intensityLevel,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    bool? needsUpload,
  }) {
    return Activity(
      id: id,
      userId: 'u1',
      activityType: ActivityType.running,
      title: title,
      scheduledDateTime: when,
      durationMinutes: durationMinutes,
      distanceMiles: distanceMiles,
      intensityLevel: intensityLevel,
      createdAt: epoch,
      updatedAt: updatedAt ?? epoch,
      lastSyncedAt: lastSyncedAt,
      needsUpload: needsUpload,
    );
  }

  group('daysAffectedByActivityOn', () {
    test('a mid-week activity affects exactly its Mon–Sun week (7 days)', () {
      final affected = daysAffectedByActivityOn(wednesday);

      expect(affected, hasLength(7));
      for (var i = 0; i < 7; i++) {
        expect(affected, contains(monday.add(Duration(days: i))));
      }
      // Wed's neighbours (Tue/Thu) already sit inside the week.
      expect(
        affected,
        isNot(contains(monday.subtract(const Duration(days: 1)))),
      );
      expect(affected, isNot(contains(sunday.add(const Duration(days: 1)))));
    });

    test('a Monday activity also affects the previous Sunday (8 days)', () {
      final affected = daysAffectedByActivityOn(monday);

      expect(affected, hasLength(8));
      // Sunday Jul 12 reads Monday Jul 13 as its "tomorrow" context.
      expect(affected, contains(DateTime(2026, 7, 12)));
      expect(affected, contains(sunday));
      // But not two days back.
      expect(affected, isNot(contains(DateTime(2026, 7, 11))));
    });

    test('a Sunday activity also affects the following Monday (8 days)', () {
      final affected = daysAffectedByActivityOn(sunday);

      expect(affected, hasLength(8));
      // Monday Jul 20 reads Sunday Jul 19 as its "yesterday" context.
      expect(affected, contains(DateTime(2026, 7, 20)));
      expect(affected, contains(monday));
      expect(affected, isNot(contains(DateTime(2026, 7, 21))));
    });

    test('the time of day is irrelevant — days are normalized', () {
      expect(
        daysAffectedByActivityOn(DateTime(2026, 7, 15, 6, 30)),
        equals(daysAffectedByActivityOn(DateTime(2026, 7, 15, 22, 45))),
      );
    });

    test('every returned day is midnight, even across a DST boundary', () {
      // US DST springs forward on Sun 2026-03-08. `Duration(days: 1)` is exactly
      // 24h, so naive arithmetic over this week lands on 01:00 rather than
      // midnight — and cached rows, keyed at midnight, would never match.
      for (final date in [
        DateTime(2026, 3, 7), // Sat, day before the shift
        DateTime(2026, 3, 8), // Sun, the shift itself
        DateTime(2026, 3, 9), // Mon, day after
        DateTime(2026, 11, 1), // fall back
      ]) {
        for (final day in daysAffectedByActivityOn(date)) {
          expect(
            [day.hour, day.minute, day.second],
            [0, 0, 0],
            reason: '$day (from $date) is not normalized to midnight',
          );
        }
      }
    });

    test('an unrelated week is never touched', () {
      final affected = daysAffectedByActivityOn(wednesday);
      expect(affected, isNot(contains(DateTime(2026, 3, 4))));
      expect(affected, isNot(contains(DateTime(2026, 7, 22))));
    });
  });

  group('changedActivityDates', () {
    test('an added activity marks its day', () {
      final dates = changedActivityDates([], [activityOn(wednesday)]);
      expect(dates, equals({wednesday}));
    });

    test('a removed activity marks its day', () {
      final dates = changedActivityDates([activityOn(wednesday)], []);
      expect(dates, equals({wednesday}));
    });

    test('a rescheduled activity marks BOTH the old and the new day', () {
      final friday = DateTime(2026, 7, 17);
      final dates = changedActivityDates(
        [activityOn(wednesday)],
        [activityOn(friday)], // same id, moved
      );
      expect(
        dates,
        equals({wednesday, friday}),
        reason: 'the day it left is stale too, not just the day it landed on',
      );
    });

    test('an edited activity that did not move marks its day once', () {
      final dates = changedActivityDates(
        [activityOn(wednesday, durationMinutes: 45)],
        [activityOn(wednesday, durationMinutes: 90)],
      );
      expect(dates, equals({wednesday}));
    });

    test('every field the macro calculation reads counts as a change', () {
      // One case per input in `_macroInputsDiffer`. If the macro calculation
      // starts reading another field, add it here and there together.
      final cases = <String, List<Activity>>{
        'durationMinutes': [
          activityOn(wednesday, durationMinutes: 45),
          activityOn(wednesday, durationMinutes: 90),
        ],
        'distanceMiles': [
          activityOn(wednesday, distanceMiles: 5),
          activityOn(wednesday, distanceMiles: 12),
        ],
        'intensityLevel': [
          activityOn(wednesday, intensityLevel: IntensityLevel.easy),
          activityOn(wednesday, intensityLevel: IntensityLevel.race),
        ],
      };

      cases.forEach((field, revisions) {
        expect(
          changedActivityDates([revisions[0]], [revisions[1]]),
          equals({wednesday}),
          reason: '$field feeds the macro calculation and must invalidate',
        );
      });
    });

    test('a Skip / Unskip toggles the day (v2 unified-skip model)', () {
      // status='skipped' rows are filtered out of every macro input query,
      // so skipping (or unskipping) moves the day's inputs.
      final planned = activityOn(wednesday, durationMinutes: 60);
      final skipped = planned.copyWith(status: ActivityStatus.skipped);
      expect(changedActivityDates([planned], [skipped]), equals({wednesday}));
      expect(changedActivityDates([skipped], [planned]), equals({wednesday}));
    });

    test('mark-done / mark-undone (planned <-> completed) changes nothing', () {
      // The prospective calculation reads no status other than `skipped`;
      // a swipe must not cost the user a cached week and an edge-function
      // round trip (the invalidation-storm flicker, fixed in 3ca2ee27).
      final planned = activityOn(wednesday, durationMinutes: 60);
      final done = planned.copyWith(
        status: ActivityStatus.completed,
        actualTime: DateTime(2026, 7, 15, 15, 0),
      );
      expect(changedActivityDates([planned], [done]), isEmpty);
      expect(changedActivityDates([done], [planned]), isEmpty);
    });

    test('a macro-irrelevant edit changes nothing', () {
      // Title never reaches the edge function. Renaming a workout should not
      // cost the user a cached week and a network round trip.
      final dates = changedActivityDates(
        [activityOn(wednesday, title: 'Easy run')],
        [activityOn(wednesday, title: 'Tempo run')],
      );
      expect(dates, isEmpty);
    });

    test('a sync that only restamps bookkeeping timestamps changes nothing', () {
      // REGRESSION: `Activity.operator==` includes updatedAt / lastSyncedAt /
      // needsUpload, and background sync restamps them on rows nobody edited.
      // Comparing whole objects therefore reported "modified" on every launch,
      // and each false positive expanded to a full week — 28 cached days wiped
      // across four unrelated weeks, forcing a blocking edge-function call to
      // rebuild the day the dashboard was about to paint.
      final before = activityOn(
        wednesday,
        durationMinutes: 60,
        updatedAt: epoch,
        lastSyncedAt: null,
        needsUpload: true,
      );
      final afterSync = activityOn(
        wednesday,
        durationMinutes: 60, // identical training content
        updatedAt: DateTime(2026, 7, 18, 9, 1),
        lastSyncedAt: DateTime(2026, 7, 18, 9, 1),
        needsUpload: false,
      );

      expect(
        before == afterSync,
        isFalse,
        reason: 'precondition: whole-object equality still sees these differ',
      );
      expect(
        changedActivityDates([before], [afterSync]),
        isEmpty,
        reason: 'but no macro input moved, so nothing may be invalidated',
      );
      expect(macroDatesToInvalidate([before], [afterSync]), isEmpty);
    });

    test('reordering the list changes nothing', () {
      final a = activityOn(wednesday, id: 'a');
      final b = activityOn(DateTime(2026, 7, 16), id: 'b');

      expect(changedActivityDates([a, b], [b, a]), isEmpty);
    });

    test('an identical list changes nothing', () {
      final a = activityOn(wednesday);
      expect(changedActivityDates([a], [a]), isEmpty);
    });
  });

  group('macroDatesToInvalidate', () {
    test('no change invalidates nothing', () {
      final a = activityOn(wednesday);
      expect(macroDatesToInvalidate([a], [a]), isEmpty);
    });

    test('deleting a mid-week activity invalidates only that week', () {
      final stale = macroDatesToInvalidate([activityOn(wednesday)], []);

      expect(stale, hasLength(7));
      expect(stale, contains(monday));
      expect(stale, contains(sunday));
      // The user's other cached weeks survive — this is the whole point.
      expect(stale, isNot(contains(DateTime(2026, 7, 20))));
      expect(stale, isNot(contains(DateTime(2026, 7, 12))));
    });

    test(
      'a reschedule across weeks invalidates both weeks, and only those',
      () {
        final nextWeekThursday = DateTime(2026, 7, 23);
        final stale = macroDatesToInvalidate(
          [activityOn(wednesday)],
          [activityOn(nextWeekThursday)],
        );

        // Jul 13–19 (the week it left) and Jul 20–26 (the week it landed in).
        expect(stale, contains(monday));
        expect(stale, contains(sunday));
        expect(stale, contains(DateTime(2026, 7, 20)));
        expect(stale, contains(DateTime(2026, 7, 26)));
        expect(stale, hasLength(14));

        // Weeks on either side are untouched.
        expect(stale, isNot(contains(DateTime(2026, 7, 12))));
        expect(stale, isNot(contains(DateTime(2026, 7, 27))));
      },
    );
  });
}
