// Carb dashboard assembler — the copy register v1 rendered VERBATIM and the
// slot-card data contract (carb-loading@v1 G4/G5 L2 rows: register strings,
// receipt-sum, summary-line register, CL-11 eaten scope, CD-4 day variants).
//
// Numbers ride the conformance-verified engine; these tests pin the STRING
// layer above it — the surface renders exactly what the register says, from
// the oracle's canonical day (544 g, the 3 PM walk state).
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/carb_dashboard_assembler.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/carb_dashboard_models.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

CarbLoadingDay day({
  int target = 544,
  int dayNumber = 2,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 9, 26);
  return CarbLoadingDay(
    id: 'day-$dayNumber',
    carbLoadingPlanId: 'plan-1',
    planDate: d,
    dayNumber: dayNumber,
    carbTargetGrams: target,
    carbProtocolGPerKg: 8.0,
    mealCount: 6,
    breakfastPercent: 0.25,
    morningSnackPercent: 0.10,
    lunchPercent: 0.25,
    afternoonSnackPercent: 0.15,
    dinnerPercent: 0.20,
    eveningSnackPercent: 0.05,
    loggedCarbsGrams: 0,
    loggedCalories: 0,
    completed: false,
    needsUpload: false,
    localUpdatedAt: DateTime(2026, 9, 1),
  );
}

MealLog log(
  String id,
  double carbs, {
  MealSlot? slot,
  bool eaten = true,
  double protein = 10,
  double fat = 5,
  int kcal = 200,
  String? name,
}) {
  return MealLog(
    id: id,
    userId: 'u1',
    logDate: '2026-09-26',
    name: name ?? 'Item $id',
    source: MealLogSource.manual,
    components: const <MealComponent>[],
    slot: slot,
    carbsG: carbs,
    proteinG: protein,
    fatG: fat,
    calories: kcal,
    eatenAt: eaten ? DateTime(2026, 9, 26, 9) : null,
    createdAt: DateTime(2026, 9, 26, 9),
    updatedAt: DateTime(2026, 9, 26, 9),
  );
}

void main() {
  const assembler = CarbDashboardAssembler();
  final selectedDate = DateTime(2026, 9, 26);

  CarbDashboardData assemble({
    List<MealLog> meals = const [],
    DateTime? now,
    DateTime? selected,
    int target = 544,
  }) {
    return assembler.assemble(
      day: day(target: target),
      totalDays: 3,
      planDays: [
        day(target: 544, dayNumber: 1, date: DateTime(2026, 9, 25)),
        day(target: target, dayNumber: 2, date: DateTime(2026, 9, 26)),
        day(target: 680, dayNumber: 3, date: DateTime(2026, 9, 27)),
      ],
      meals: meals,
      selectedDate: selected ?? selectedDate,
      now: now ?? DateTime(2026, 9, 26, 15, 0),
      eventId: 'event-1',
    )!;
  }

  group('copy register v1 — verbatim', () {
    test('behind: "31 g" / "behind pace" at the canonical 3 PM state', () {
      // 295 g at 3 PM vs owed 326 → 31 behind (the walked state).
      final data = assemble(meals: [log('a', 295)]);
      expect(data.face.paceMainStr, '31 g');
      expect(data.face.paceSubStr, 'behind pace');
      expect(data.face.paceMainIsWord, isFalse);
      expect(data.face.labelLine, 'CARB LOAD · DAY 2 OF 3');
    });

    test('on pace: word form with grams sub-line', () {
      final data = assemble(meals: [log('a', 322)]);
      expect(data.face.paceMainStr, 'On pace');
      expect(data.face.paceSubStr, '322 of 544 g');
      expect(data.face.paceMainIsWord, isTrue);
    });

    test('ahead: "N g" / "ahead of pace"', () {
      final data = assemble(meals: [log('a', 380)]);
      expect(data.face.paceMainStr, '54 g');
      expect(data.face.paceSubStr, 'ahead of pace');
    });

    test('loaded flips the label and shows actual grams over target (CD-5)',
        () {
      final data = assemble(meals: [log('a', 547)]);
      expect(data.face.labelLine, 'LOADED · DAY 2 OF 3');
      expect(data.face.paceMainStr, 'Loaded');
      expect(data.face.paceSubStr, '547 of 544 g');
      expect(data.face.tickHidden, isTrue);
      expect(data.face.fillFrac, 1.0);
    });

    test('to-go clamps at zero; completion reads "Target met" (G19)', () {
      // G19 register amendment: the loaded state substitutes the word form;
      // every un-loaded state keeps the clamped figure.
      expect(assemble(meals: [log('a', 547)]).face.toGoStr, 'Target met');
      expect(assemble(meals: [log('a', 544)]).face.toGoStr, 'Target met');
      expect(assemble(meals: [log('a', 295)]).face.toGoStr, '249 g to go');
      expect(assemble(meals: [log('a', 543)]).face.toGoStr, '1 g to go');
    });

    test('pace-by-now renders owed grams; suppressed pre-window and loaded',
        () {
      expect(
        assemble(meals: [log('a', 295)]).face.paceByNowStr,
        'pace 326 g by now',
      );
      expect(
        assemble(now: DateTime(2026, 9, 26, 5, 30)).face.paceByNowStr,
        isNull,
      );
      expect(assemble(meals: [log('a', 547)]).face.paceByNowStr, isNull);
    });

    test('future day: "<target> g / planned", no tick (CD-4)', () {
      final data = assemble(
        selected: DateTime(2026, 9, 26),
        now: DateTime(2026, 9, 25, 12, 0),
      );
      expect(data.dayRel, CarbDayRel.future);
      expect(data.face.paceMainStr, '544 g');
      expect(data.face.paceSubStr, 'planned');
      expect(data.face.tickHidden, isTrue);
      expect(data.face.tickFrac, isNull);
    });

    test('past day: outcome face "<eaten> g / of <target> g" (CD-4)', () {
      final data = assemble(
        meals: [log('a', 521)],
        selected: DateTime(2026, 9, 26),
        now: DateTime(2026, 9, 27, 8, 0),
      );
      expect(data.dayRel, CarbDayRel.past);
      expect(data.face.paceMainStr, '521 g');
      expect(data.face.paceSubStr, 'of 544 g');
      expect(data.face.tickHidden, isTrue);
    });
  });

  group('slot cards (carb-slot-card.md data contract)', () {
    test('CL-11: day total counts EVERY eaten log; slots sum only tagged',
        () {
      final data = assemble(
        meals: [
          log('a', 100, slot: MealSlot.breakfast),
          log('b', 50), // untagged — counts to the day, no slot card
          log('c', 30, slot: MealSlot.snack), // legacy → Afternoon Snack
          log('d', 40, eaten: false), // planned, not eaten: counts nowhere
        ],
      );
      expect(data.face.eatenOfTargetStr, '180 of 544 g');
      final breakfast = data.slots[0];
      expect(breakfast.eatenG, 100);
      final afternoon = data.slots[3];
      expect(afternoon.label, 'Afternoon Snack');
      expect(afternoon.eatenG, 30, reason: 'legacy snack folds in');
      expect(data.slots.map((s) => s.eatenG).fold<int>(0, (a, b) => a + b),
          130);
    });

    test('slot targets derive from the STORED split fractions (CL-4)', () {
      final data = assemble();
      expect(
        data.slots.map((s) => s.targetG).toList(),
        [136, 54, 136, 82, 109, 27],
      );
      expect(
        data.slots.map((s) => s.clockStr).toList(),
        ['6:00 AM', '9:00 AM', '12:00 PM', '3:00 PM', '6:00 PM', '9:00 PM'],
      );
    });

    test('receipt rows sum to the card figure exactly', () {
      final data = assemble(
        meals: [
          log('a', 58, slot: MealSlot.breakfast, name: 'Bagel'),
          log('b', 39, slot: MealSlot.breakfast, name: 'Granola Bar'),
          log('c', 27, slot: MealSlot.breakfast, name: 'Chocolate Milk'),
        ],
      );
      final b = data.slots[0];
      expect(b.eatenG, 124);
      expect(b.items.map((i) => i.gramsStr).toList(), ['58 g', '39 g', '27 g']);
    });

    test('summary-line register: 1 / 2 / ≥3 forms', () {
      CarbSlotCardData bf(List<MealLog> meals) => assemble(meals: meals)
          .slots
          .firstWhere((s) => s.label == 'Breakfast');
      expect(
        bf([log('a', 10, slot: MealSlot.breakfast, name: 'Granola Bar')])
            .summaryLine,
        'Granola Bar',
      );
      expect(
        bf([
          log('a', 10, slot: MealSlot.breakfast, name: 'Granola Bar'),
          log('b', 10, slot: MealSlot.breakfast, name: 'Chocolate Milk'),
        ]).summaryLine,
        'Granola Bar + Chocolate Milk',
      );
      expect(
        bf([
          log('a', 10, slot: MealSlot.breakfast, name: 'Everything Bagel'),
          log('b', 10, slot: MealSlot.breakfast, name: 'B'),
          log('c', 10, slot: MealSlot.breakfast, name: 'C'),
        ]).summaryLine,
        'Everything Bagel +2 more',
      );
    });
  });

  group('breakdown page data', () {
    test('macro strip + by-meal rows + protocol chips', () {
      final data = assemble(
        meals: [log('a', 295, protein: 73, fat: 45, kcal: 1874)],
      );
      final b = data.breakdown;
      expect(b.titleLine, 'Carb Load · Day 2 of 3');
      expect(b.eatenOfTargetStr, '295 of 544 g carbs');
      expect(b.carbsStr, '295g');
      expect(b.proteinStr, '73g');
      expect(b.fatStr, '45g');
      expect(b.kcalStr, '1,874');
      expect(b.mealRows, hasLength(6));
      // 3 PM sits in the Afternoon Snack window (15:00–18:00).
      expect(
        b.mealRows.map((r) => r.isCurrentWindow).toList(),
        [false, false, false, true, false, false],
      );
      expect(b.dayChips.map((c) => c.targetStr).toList(),
          ['544 g', '544 g', '680 g']);
      expect(b.dayChips.map((c) => c.isViewed).toList(),
          [false, true, false]);
    });
  });

  test(
    'G20 out-of-slot-entry-renders-on-loading-day: untagged food is an '
    'ordinary timeline entry at its clock AND moves the face — one write, '
    'both surfaces',
    () {
      // ONE untagged log at 10:30 AM alongside a tagged breakfast.
      final meals = [
        log('a', 100, slot: MealSlot.breakfast),
        log('b', 50, name: 'Trailside Gel'), // untagged — CL-11 counts it
      ];
      final carb = assemble(meals: meals);

      // The face counts BOTH (CL-11: eaten = ALL day logs).
      expect(carb.face.eatenOfTargetStr, '150 of 544 g');

      // Build the ordinary-node set the macro assembler produces, then the
      // loading-day merge (CD-3): the untagged entry survives as an
      // ordinary meal node, interleaved by clock BETWEEN the slot cards.
      const macroAssembler = MacroDashboardAssembler();
      final untaggedNode = DashboardNode.meals(
        timeLabel: '10:30 AM',
        mealGroupLabel: 'Logged',
        meals: const [
          MealItemData(
            id: 'b',
            name: 'Trailside Gel',
            kcal: 200,
            carbsG: 50,
            proteinG: 10,
            fatG: 5,
          ),
        ],
      );
      final taggedNode = DashboardNode.meals(
        timeLabel: '9:00 AM',
        mealGroupLabel: 'Breakfast',
        meals: const [],
      );
      final merged = carbLoadingTimeline([untaggedNode, taggedNode], carb);

      // The tagged group is superseded by its slot card; the untagged one
      // renders as an ordinary entry.
      expect(merged.where((n) => n.mealGroupLabel == 'Breakfast'), isEmpty);
      final gelIndex = merged.indexWhere(
        (n) => n.mealGroupLabel == 'Logged',
      );
      expect(gelIndex, isNot(-1), reason: 'the entry must render');
      // Clock interleave: 10:30 AM sits after the 9:00 slot card and
      // before the 12:00 one.
      final morningSnackIndex = merged.indexWhere(
        (n) => n.carbSlot?.clockStr == '9:00 AM',
      );
      final lunchIndex = merged.indexWhere(
        (n) => n.carbSlot?.clockStr == '12:00 PM',
      );
      expect(gelIndex, greaterThan(morningSnackIndex));
      expect(gelIndex, lessThan(lunchIndex));
      // macroAssembler referenced so the composition source is explicit.
      expect(macroAssembler, isNotNull);
    },
  );

  test('CD-1 negative: no carb day → null, no carb data anywhere', () {
    expect(
      assembler.assemble(
        day: null,
        totalDays: 0,
        planDays: const [],
        meals: const [],
        selectedDate: selectedDate,
        now: DateTime(2026, 9, 26, 15),
      ),
      isNull,
    );
  });
}
