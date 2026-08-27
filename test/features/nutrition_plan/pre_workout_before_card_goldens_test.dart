// GOLDENS for the pre-workout BEFORE card — one PNG per row of
// docs/ssot/conformance/design/pre-workout-before-card.goldens.yaml (the design
// analogue of a vectors file), plus the R-01 oz-conversion golden the
// pre-workout-macros@v2 handoff adds. `before_fine_print` is DEFERRED (S-G4,
// Xuan 2026-08-26) and deliberately has no golden here.
//
// Every golden renders from the CANONICAL 63-kg MOCK
// (pre_workout_before_card_fixtures.dart) with NUMBERS FROM THE ENGINE at
// token-resolved colors and the real app fonts. Blessed 2026-08-26 from the
// first rendering that passed the side-by-side against
// spec/design/renderings/pre-workout@v2.html (prototypes/pre-workout/v4.html
// @ d6b2de4).
//
// RULE (component specs): a golden may only be regenerated AFTER the design
// spec changes — never to make a red test pass. Regeneration commits cite
// the spec change.
//
//   flutter test test/features/nutrition_plan/pre_workout_before_card_goldens_test.dart \
//     --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_before_card_assembler.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_hydration_check_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/pre_workout_before_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/feeding_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/fuel_stat.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/hydration_check_control.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import 'pre_workout_before_card_fixtures.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await loader.load();
}

/// The rendering's phone frame: 428 px wide, 17 px side padding on the
/// blackberry ground (`rgb(56,22,51)`), card 394 px wide.
Widget _frame(Widget child, {double height = 1180}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: AppColors.blackberry,
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 428,
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 24, 17, 40),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  ),
);

PreWorkoutBeforeCardData _data(
  double t, {
  bool gated = false,
  bool fasted = false,
  PreWorkoutHydrationCheckRecord? record,
  List<dynamic>? subPhases,
}) => PreWorkoutBeforeCardAssembler.assemble(
  preRun: mockPreRun(t: t, gated: gated, fasted: fasted),
  subPhases: subPhases?.cast() ?? mockSubPhases(t),
  timeBeforeWorkoutMin: t,
  bodyWeightKg: kMockBodyWeightKg,
  hydrationCheck: record,
);

Widget _card(
  PreWorkoutBeforeCardData data, {
  Set<String> expanded = const {},
  bool checkExpanded = false,
}) => PreWorkoutBeforeCard(
  data: data,
  initiallyExpandedTiers: expanded,
  hydrationCheckInitiallyExpanded: checkExpanded,
  onStep: (_, __) {},
  onAddFood: (_) {},
  onAnswerHydrationCheck: (_) {},
  onChangeHydrationAnswer: () {},
);

/// Apply an answer through the REAL write path (the service the controller
/// uses) and return the re-assembled card data.
({PreWorkoutBeforeCardData data, HydrationCheckWrite write}) _answered(
  HydrationCheckAnswer answer, {
  double t = 180,
  double mealWaterCups = 2,
}) {
  final plan = mockPlan(mockSubPhases(t, mealWaterCups: mealWaterCups));
  final targets = mockMacroTargets(mockPreRun(t: t));
  final write = PreWorkoutHydrationCheckService.answer(
    plan: plan,
    targets: targets,
    answer: answer,
    bodyWeightKg: kMockBodyWeightKg,
    workoutDurationMin: kMockDurationMin,
    timeBeforeWorkoutMin: t,
    tempC: 22,
    newFoodId: () => 'hwat',
  );
  final section = write.plan.sections.first;
  return (
    data: PreWorkoutBeforeCardAssembler.assemble(
      preRun: write.targets.preRun,
      subPhases: section.subPhases!,
      timeBeforeWorkoutMin: t,
      bodyWeightKg: kMockBodyWeightKg,
      hydrationCheck: write.plan.preWorkoutHydrationCheck,
    ),
    write: write,
  );
}

void main() {
  setUpAll(() async {
    await _loadFont('Sansita', [
      'assets/fonts/Sansita/Sansita-Regular.otf',
      'assets/fonts/Sansita/Sansita-Bold.ttf',
    ]);
    await _loadFont('Apercu', [
      'assets/fonts/Apercu/Apercu Pro Regular.otf',
      'assets/fonts/Apercu/Apercu Pro Medium.otf',
      'assets/fonts/Apercu/Apercu Pro Bold.otf',
    ]);
    await _loadFont('Apercu Mono', ['assets/fonts/Apercu/Apercu Pro Mono.otf']);
    await _loadFont('Compadre', [
      'assets/fonts/Compadre/Compadre-Demo-Regular.otf',
    ]);
  });

  Future<void> golden(
    WidgetTester tester,
    Widget child,
    String name, {
    double height = 1180,
  }) async {
    tester.view.physicalSize = Size(428, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_frame(child, height: height));
    await tester.pump();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('surface: the five feeding-membership scenarios (B-2)', () {
    testWidgets('before_3h_targets_set', (tester) async {
      await golden(
        tester,
        _card(_data(180)),
        'before_3h_targets_set',
        height: 720,
      );
    });

    testWidgets('before_2h15_meal_15min_window', (tester) async {
      await golden(
        tester,
        _card(_data(135)),
        'before_2h15_meal_15min_window',
        height: 720,
      );
    });

    // Also the hydration-check SUPPRESSION golden: no control on a 90-min plan.
    testWidgets('before_90min', (tester) async {
      await golden(tester, _card(_data(90)), 'before_90min', height: 620);
    });

    testWidgets('before_20min', (tester) async {
      await golden(tester, _card(_data(20)), 'before_20min', height: 520);
    });

    // 0 g carbs + fluid, card KEPT; NO carbs band (fuel-stat carbs [0,0]).
    testWidgets('before_start_line', (tester) async {
      await golden(tester, _card(_data(0)), 'before_start_line', height: 520);
    });
  });

  group('fuel-stat: the three no-number states (F-1) + overshoot (M-2)', () {
    testWidgets('fuelstat_gated', (tester) async {
      await golden(
        tester,
        _card(_data(180, gated: true)),
        'fuelstat_gated',
        height: 720,
      );
    });

    testWidgets('fuelstat_fasted', (tester) async {
      await golden(
        tester,
        _card(_data(180, fasted: true)),
        'fuelstat_fasted',
        height: 720,
      );
    });

    // Delivered above the ceiling recolours (dragonfruit, Q-D9); a short fill
    // (0 oz) shown beside it does NOT (one-way signalling).
    testWidgets('fuelstat_fluid_overshoot', (tester) async {
      final base = _data(180).fluids;
      final over = FuelStatData(
        quantity: FuelQuantity.fluids,
        mode: FuelStatMode.targeted,
        delivered: base.bandHigh! * 2,
        target: base.target,
        bandLow: base.bandLow,
        bandHigh: base.bandHigh,
      );
      final short = FuelStatData(
        quantity: FuelQuantity.fluids,
        mode: FuelStatMode.targeted,
        delivered: 0,
        target: base.target,
        bandLow: base.bandLow,
        bandHigh: base.bandHigh,
      );
      await golden(
        tester,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FuelStat(data: over)),
            const SizedBox(width: 10),
            Expanded(child: FuelStat(data: short)),
          ],
        ),
        'fuelstat_fluid_overshoot',
        height: 200,
      );
    });
  });

  group('feeding-card', () {
    // MEAL expanded: food rows with steppers; header "52g · carbs" (FC-2).
    // The hydration-check row lives in the SNACK card (FC-6) — not here.
    testWidgets('feeding_meal_expanded', (tester) async {
      final meal = _data(180).feedings.first;
      await golden(
        tester,
        FeedingCard(
          data: meal,
          initiallyExpanded: true,
          onStep: (_, __) {},
          onAddFood: (_) {},
        ),
        'feeding_meal_expanded',
        height: 360,
      );
    });

    // aim >= LIGHT_MEAL_G_PER_KG*BW -> "Light Meal" (t = 240: 75.6 g >= 63 g).
    testWidgets('feeding_snack_light_meal', (tester) async {
      final snack = _data(240).feedings[1];
      await golden(
        tester,
        FeedingCard(data: snack, onStep: (_, __) {}, onAddFood: (_) {}),
        'feeding_snack_light_meal',
        height: 160,
      );
    });

    // Zero-carb card kept because it carries fluid (FC-4).
    testWidgets('feeding_topoff_zero_carb', (tester) async {
      final topOff = _data(0).feedings.single;
      await golden(
        tester,
        FeedingCard(data: topOff, onStep: (_, __) {}, onAddFood: (_) {}),
        'feeding_topoff_zero_carb',
        height: 160,
      );
    });
  });

  group('hydration-check (one golden per state row)', () {
    Widget control(HydrationCheckViewState state, {bool expanded = false}) =>
        HydrationCheckControl(
          state: state,
          initiallyExpanded: expanded,
          onAnswer: (_) {},
          onChangeAnswer: () {},
        );

    testWidgets('check_todo', (tester) async {
      await golden(
        tester,
        control(_data(180).hydrationCheck!),
        'check_todo',
        height: 140,
      );
    });

    testWidgets('check_expanded', (tester) async {
      await golden(
        tester,
        control(_data(180).hydrationCheck!, expanded: true),
        'check_expanded',
        height: 360,
      );
    });

    testWidgets('check_pale', (tester) async {
      final r = _answered(HydrationCheckAnswer.pale);
      await golden(
        tester,
        control(r.data.hydrationCheck!, expanded: true),
        'check_pale',
        height: 260,
      );
    });

    // DARK: status "target raised", the tagged 8 oz water row in the SNACK
    // card, target triangle moved, band unchanged — the whole card.
    testWidgets('check_dark', (tester) async {
      final r = _answered(HydrationCheckAnswer.dark);
      await golden(
        tester,
        _card(r.data, expanded: const {'snack'}, checkExpanded: true),
        'check_dark',
        height: 1180,
      );
    });

    // NOT_YET with delivered already >= the raised target: target rose, NO
    // row added.
    testWidgets('check_not_yet_covered', (tester) async {
      final r = _answered(HydrationCheckAnswer.notYet, mealWaterCups: 6);
      await golden(
        tester,
        _card(r.data, expanded: const {'snack'}, checkExpanded: true),
        'check_not_yet_covered',
        height: 1100,
      );
    });

    testWidgets('check_not_sure', (tester) async {
      final r = _answered(HydrationCheckAnswer.notSure);
      await golden(
        tester,
        control(r.data.hydrationCheck!, expanded: true),
        'check_not_sure',
        height: 260,
      );
    });
  });

  group('R-01 oz conversion (handoff addition)', () {
    // 487.5 ml -> 16 oz target; 756 ml -> 26 oz ceiling; floor of 315 -> 10.
    testWidgets('oz_conversion', (tester) async {
      const stat = FuelStatData(
        quantity: FuelQuantity.fluids,
        mode: FuelStatMode.targeted,
        delivered: 16,
        target: 16, // round(487.5 / 29.5735) = round(16.48)
        bandLow: 10, // floor(315 / 29.5735) = floor(10.65)
        bandHigh: 26, // ceil(756 / 29.5735) = ceil(25.56)
      );
      await golden(
        tester,
        const SizedBox(width: 120, child: FuelStat(data: stat)),
        'oz_conversion',
        height: 200,
      );
    });
  });
}
