// G18 seam test (carb-loading@v1, RULED 2026-09-26 option 1): the
// meal_logs.slot upload seam across the app ⇄ Postgres boundary.
//
// Seam-test rules (docs/test/README.md §Seam tests): the stored rows are
// PRODUCER-shaped — a Drift entry as the log-a-meal path actually writes it,
// including the v14-era null slot — never the wire mapper's own output fed
// back to itself.
//
// Pins:
//  * a NULL-slot (untagged) row serializes with an explicit `slot: null`
//    key — the exact payload that failed against the pre-G18 NOT NULL and
//    is RULED valid now (null = untagged, CL-11-consistent);
//  * the three loading-day wire values survive the round trip;
//  * an unknown future wire value skips the row (forward-compat), it does
//    not crash.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

MealLogEntry storedRow({String? slot}) => MealLogEntry(
  id: 'log-1',
  userId: 'u1',
  logDate: '2026-09-26',
  // Producer shape: the quick-log path writes the slot wire string (or
  // null when the athlete cleared the chip), name/source as strings, and
  // items as a JSON-encoded array.
  slot: slot,
  name: 'Everything Bagel',
  source: 'manual',
  items: '[]',
  calories: 320,
  carbsG: 58,
  proteinG: 11,
  fatG: 6,
  isDeleted: false,
  createdAt: DateTime.utc(2026, 9, 26, 12),
  updatedAt: DateTime.utc(2026, 9, 26, 12),
);

void main() {
  test('null-slot stored row serializes with an explicit slot: null', () {
    final log = MealLog.fromDriftEntry(storedRow(slot: null));
    expect(log, isNotNull);
    final json = log!.toSupabaseJson();
    expect(
      json.containsKey('slot'),
      isTrue,
      reason: 'the column must be SENT (as null), not omitted',
    );
    expect(json['slot'], isNull);
  });

  test('the loading-day wire values round-trip through the seam', () {
    for (final wire in ['morning_snack', 'afternoon_snack', 'evening_snack']) {
      final log = MealLog.fromDriftEntry(storedRow(slot: wire));
      expect(log, isNotNull, reason: wire);
      expect(log!.slot?.wireValue, wire);
      expect(log.toSupabaseJson()['slot'], wire);
      final back = MealLog.fromSupabaseJson(log.toSupabaseJson());
      expect(back?.slot?.wireValue, wire);
    }
  });

  test('legacy snack still parses (display-time fold, no data migration)', () {
    final log = MealLog.fromDriftEntry(storedRow(slot: 'snack'));
    expect(log?.slot, MealSlot.snack);
  });

  test('an unknown future wire value skips the row, never crashes', () {
    expect(MealLog.fromDriftEntry(storedRow(slot: 'second_breakfast')), isNull);
  });
}
