import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/plan_reminder_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';

import '../domain/fixture_helpers.dart';

/// Plan Phase 3.5 / 4.3 — the reminder slots are pure date maths off the
/// plan's week (a Sunday): check-in = 18:00 the evening before cook day,
/// debrief = 18:00 on the Sunday that closes the week; both `null` once past.
void main() {
  final plan = MealPlan.fromJson(
    (loadFixture('batch')['parts'] as List).first['plan'] as Map<String, dynamic>,
  ).copyWith(weekStart: '2026-09-06');

  test('cook day is the plan week start (a Sunday)', () {
    final cook = PlanReminderService.cookDayFor(plan);
    expect(cook, DateTime(2026, 9, 6));
    expect(cook.weekday, DateTime.sunday);
  });

  test('check-in fires 18:00 the evening before cook day', () {
    final when = PlanReminderService.checkinTimeFor(
      plan,
      now: DateTime(2026, 9, 1, 12),
    );
    expect(when, DateTime(2026, 9, 5, PlanReminderService.reminderHour));
  });

  test('debrief fires 18:00 on the closing Sunday', () {
    final when = PlanReminderService.debriefTimeFor(
      plan,
      now: DateTime(2026, 9, 1, 12),
    );
    expect(when, DateTime(2026, 9, 13, PlanReminderService.reminderHour));
  });

  test('a slot already in the past yields null (nothing to schedule)', () {
    expect(
      PlanReminderService.checkinTimeFor(plan, now: DateTime(2026, 9, 5, 19)),
      isNull,
    );
    expect(
      PlanReminderService.debriefTimeFor(plan, now: DateTime(2026, 9, 14)),
      isNull,
    );
  });
}
