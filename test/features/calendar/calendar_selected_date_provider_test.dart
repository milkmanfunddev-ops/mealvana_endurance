import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';

void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  group('CalendarSelectedDate', () {
    test('initial state is today normalised to midnight', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final today = DateTime.now();
      final state = container.read(calendarSelectedDateProvider);

      expect(state.year, today.year);
      expect(state.month, today.month);
      expect(state.day, today.day);
      // Must be normalised – no time component
      expect(state.hour, 0);
      expect(state.minute, 0);
      expect(state.second, 0);
    });

    test('setDate strips time component (normalisation)', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final dateWithTime = DateTime(2026, 9, 15, 14, 30, 45);
      container
          .read(calendarSelectedDateProvider.notifier)
          .setDate(dateWithTime);

      final state = container.read(calendarSelectedDateProvider);
      expect(state, DateTime(2026, 9, 15));
      expect(state.hour, 0);
      expect(state.minute, 0);
      expect(state.second, 0);
    });

    test('setDate to a specific date updates state correctly', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container
          .read(calendarSelectedDateProvider.notifier)
          .setDate(DateTime(2026, 1, 20));
      final state = container.read(calendarSelectedDateProvider);
      expect(state, DateTime(2026, 1, 20));
    });

    test('setDate called twice reflects the most recent date', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container
          .read(calendarSelectedDateProvider.notifier)
          .setDate(DateTime(2026, 1, 1));
      container
          .read(calendarSelectedDateProvider.notifier)
          .setDate(DateTime(2026, 12, 31));

      final state = container.read(calendarSelectedDateProvider);
      expect(state, DateTime(2026, 12, 31));
    });

    test('normalises a UTC datetime to local date without time', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Provide a DateTime that has explicit midnight via constructor
      final utcMidnight = DateTime.utc(2026, 6, 15, 0, 0, 0);
      container
          .read(calendarSelectedDateProvider.notifier)
          .setDate(utcMidnight);

      final state = container.read(calendarSelectedDateProvider);
      // Regardless of UTC/local the hour/minute/second should be zero
      expect(state.hour, 0);
      expect(state.minute, 0);
      expect(state.second, 0);
    });

    test('two different containers have independent state', () {
      final c1 = makeContainer();
      final c2 = makeContainer();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      c1
          .read(calendarSelectedDateProvider.notifier)
          .setDate(DateTime(2026, 6, 1));
      c2
          .read(calendarSelectedDateProvider.notifier)
          .setDate(DateTime(2026, 9, 1));

      expect(c1.read(calendarSelectedDateProvider), DateTime(2026, 6, 1));
      expect(c2.read(calendarSelectedDateProvider), DateTime(2026, 9, 1));
    });
  });

  // -------------------------------------------------------------------------
  // _getWeekStart logic (extracted from CalendarController._getWeekStart)
  // Tests mirror the controller logic: weekStart = date - weekday + 1 (Monday)
  // -------------------------------------------------------------------------

  group('Week start calculation (Monday-based)', () {
    DateTime getWeekStart(DateTime date) {
      // Replicate CalendarController._getWeekStart exactly
      return DateTime(date.year, date.month, date.day - date.weekday + 1);
    }

    test('Monday returns itself as week start', () {
      // 2026-06-15 is a Monday
      final monday = DateTime(2026, 6, 15);
      expect(getWeekStart(monday), DateTime(2026, 6, 15));
    });

    test('Sunday returns the preceding Monday', () {
      // 2026-06-21 is a Sunday (weekday == 7)
      final sunday = DateTime(2026, 6, 21);
      expect(getWeekStart(sunday), DateTime(2026, 6, 15));
    });

    test('Wednesday returns the same-week Monday', () {
      // 2026-06-17 is a Wednesday (weekday == 3)
      final wednesday = DateTime(2026, 6, 17);
      expect(getWeekStart(wednesday), DateTime(2026, 6, 15));
    });

    test('Saturday returns the same-week Monday', () {
      // 2026-06-20 is a Saturday (weekday == 6)
      final saturday = DateTime(2026, 6, 20);
      expect(getWeekStart(saturday), DateTime(2026, 6, 15));
    });

    test('week start of Jan 1 Monday returns Jan 1', () {
      // 2024-01-01 is a Monday
      final jan1 = DateTime(2024, 1, 1);
      expect(getWeekStart(jan1), DateTime(2024, 1, 1));
    });

    // IMPORTANT: This test documents a POTENTIAL BUG in _getWeekStart.
    // When date.weekday == 7 (Sunday) and day == 1 (first of month),
    // the subtraction: day - weekday + 1 = 1 - 7 + 1 = -5
    // DateTime(year, month, -5) is handled by Dart via date arithmetic.
    // Verifying Dart handles it correctly (overflow to prior month).
    test(
      'BUG-CHECK: Sunday Jan 5 2025 returns Monday Dec 30 2024 (cross-month)',
      () {
        // 2025-01-05 is a Sunday
        final sunday = DateTime(2025, 1, 5);
        expect(sunday.weekday, 7); // confirm it is Sunday
        final weekStart = getWeekStart(sunday);
        // day - weekday + 1 = 5 - 7 + 1 = -1 → Dec 30 2024
        expect(weekStart, DateTime(2024, 12, 30));
      },
    );

    // Verify that activity day-bucketing uses local date, not UTC offset.
    // An activity at 2026-06-15 23:30 local and the filter uses naive local
    // startDate 2026-06-15 00:00 should include it.
    test('activity at 23:30 on the start day is within the week', () {
      // The activities_service uses isBetweenValues(weekStart, weekEnd)
      // where weekEnd = weekStart + 6 days + 23h 59m 59s
      final weekStart = DateTime(2026, 6, 15); // Monday
      final weekEnd = weekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      final activityTime = DateTime(2026, 6, 15, 23, 30);
      expect(
        activityTime.isAfter(weekStart) ||
            activityTime.isAtSameMomentAs(weekStart),
        isTrue,
      );
      expect(activityTime.isBefore(weekEnd), isTrue);
    });

    test(
      'activity at midnight Mon June 15 is within week starting June 15',
      () {
        final weekStart = DateTime(2026, 6, 15);
        final weekEnd = weekStart.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );

        final activityMidnight = DateTime(2026, 6, 15, 0, 0, 0);
        // isBetweenValues in Drift is >= startDate AND <= endDate
        expect(!activityMidnight.isBefore(weekStart), isTrue);
        expect(!activityMidnight.isAfter(weekEnd), isTrue);
      },
    );

    // KEY TZ BUG CLASS: if scheduledDateTime were stored as UTC and then compared
    // using a naive local weekStart, an activity at 22:00 UTC (= 18:00 ET)
    // would appear to be outside the week if the comparison used UTC day.
    // This test verifies local-day interpretation.
    test(
      'naive-local boundary: 22:00 local on Sunday is still within that week',
      () {
        final weekStart = DateTime(2026, 6, 15); // Monday
        final weekEnd = weekStart.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );

        // Sunday 22:00 — should be within the week
        final sundayEvening = DateTime(2026, 6, 21, 22, 0, 0);
        expect(!sundayEvening.isBefore(weekStart), isTrue);
        expect(!sundayEvening.isAfter(weekEnd), isTrue);
      },
    );

    test('activity one second after weekEnd is NOT in the week', () {
      final weekStart = DateTime(2026, 6, 15);
      final weekEnd = weekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      // One second past weekEnd
      final nextWeekMon = weekEnd.add(const Duration(seconds: 1));
      expect(nextWeekMon.isAfter(weekEnd), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // CalendarState indicators (domain logic tests without Flutter widgets)
  // -------------------------------------------------------------------------

  group('Day indicator logic', () {
    // Helper: simulate how CalendarMonthViewKyle decides which indicators to show
    Set<String> indicatorsForDate(
      DateTime date, {
      required List<DateTime> activityDates,
      required List<DateTime> eventDates,
      required List<DateTime> carbLoadingDates,
    }) {
      final indicators = <String>{};
      if (activityDates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      )) {
        indicators.add('activity');
      }
      if (eventDates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      )) {
        indicators.add('event');
      }
      if (carbLoadingDates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      )) {
        indicators.add('carbLoading');
      }
      return indicators;
    }

    test('day with activity shows activity indicator', () {
      final date = DateTime(2026, 9, 15);
      final indicators = indicatorsForDate(
        date,
        activityDates: [DateTime(2026, 9, 15, 7, 0)],
        eventDates: [],
        carbLoadingDates: [],
      );
      expect(indicators, contains('activity'));
      expect(indicators, hasLength(1));
    });

    test('day with event shows event indicator', () {
      final date = DateTime(2026, 9, 15);
      final indicators = indicatorsForDate(
        date,
        activityDates: [],
        eventDates: [DateTime(2026, 9, 15)],
        carbLoadingDates: [],
      );
      expect(indicators, contains('event'));
    });

    test('day with carb loading shows carbLoading indicator', () {
      final date = DateTime(2026, 10, 3);
      final indicators = indicatorsForDate(
        date,
        activityDates: [],
        eventDates: [],
        carbLoadingDates: [DateTime(2026, 10, 3)],
      );
      expect(indicators, contains('carbLoading'));
    });

    test('day with all three shows all three indicators', () {
      final date = DateTime(2026, 10, 3);
      final indicators = indicatorsForDate(
        date,
        activityDates: [DateTime(2026, 10, 3, 7)],
        eventDates: [DateTime(2026, 10, 3)],
        carbLoadingDates: [DateTime(2026, 10, 3)],
      );
      expect(indicators, containsAll(['activity', 'event', 'carbLoading']));
    });

    test('activity at 23:59 still matches the correct day', () {
      final date = DateTime(2026, 9, 15);
      final indicators = indicatorsForDate(
        date,
        activityDates: [DateTime(2026, 9, 15, 23, 59)],
        eventDates: [],
        carbLoadingDates: [],
      );
      expect(indicators, contains('activity'));
    });

    test('activity at midnight NEXT day does NOT match current day', () {
      final date = DateTime(2026, 9, 15);
      final indicators = indicatorsForDate(
        date,
        activityDates: [DateTime(2026, 9, 16, 0, 0, 0)], // next day midnight
        eventDates: [],
        carbLoadingDates: [],
      );
      expect(indicators, isEmpty);
    });
  });
}
