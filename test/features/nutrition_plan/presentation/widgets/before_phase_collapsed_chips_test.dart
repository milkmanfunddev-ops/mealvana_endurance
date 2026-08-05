// Per-feeding figures on the BEFORE feeding cards (digest §5, revised per
// Lee's 2026-08-05 screenshot review): chips show DELIVERED values summed
// from the card's foods — so add/remove and quantity edits move them — a
// carbs chip whenever the foods deliver carbs, a fluids chip whenever they
// deliver fluids (any card, not just the meal), never a sodium chip, and a
// card delivering nothing (or with no foods) renders no chip at all.
//
// Also covers the two other review fixes: feeding titles render in Sansita
// (the in-app Compadre is a caps-only demo cut) without truncating at a
// 390 px phone width, and the summary row top-aligns its three columns so
// the sodium value sits on the same line as carbs/fluids.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/before_phase_widget.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/macro_summary_row.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

Widget _buildBeforePhase(
  PlanSection section, {
  bool useImperial = true,
  ActivityType? activityType,
  MacroTargets? macroTargets,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BeforePhaseWidget(
          section: section,
          sectionColor: Colors.orange,
          sectionTitle: 'BEFORE',
          useImperial: useImperial,
          activityType: activityType,
          macroTargets: macroTargets,
          onSwapFood: (_, __, ___) {},
          onDeleteFood: (_, __) {},
          onUpdateQuantity: (_, __, ___) {},
          onScaleSubPhase: (_, __, ___) {},
          onAddFood: (_) {},
        ),
      ),
    ),
  );
}

/// Minimal targets fixture — only needed so the ⓘ button renders at all.
MacroTargets _macroTargetsFixture() => MacroTargets(
  id: 'mt1',
  activityType: ActivityType.running,
  preRun: const PreRunMacros(
    carbsG: 60,
    proteinG: 10,
    fatCapG: 10,
    fluidsMl: 400,
  ),
  duringRun: const DuringRunMacros(
    carbRateGPerH: 60,
    carbTotalG: 60,
    fluidRateMlPerH: 500,
    fluidTotalMl: 500,
    sodiumRateMgPerH: 300,
    sodiumTotalMg: 300,
    massNormRateGPerH: 0.8,
  ),
  postRun: const PostRunMacros(
    carbsG: 60,
    proteinG: 20,
    fluidsMl: 500,
    sodiumMg: 300,
  ),
  metrics: const RunMetrics(
    distanceMi: 6.2,
    distanceKm: 10,
    durationH: 1,
    durationMin: 60,
    speedMph: 6.2,
    caloriesGrossKcal: 600,
    caloriesNetKcal: 550,
    met: 9.8,
  ),
  calculationRule: 'test',
  timestamp: DateTime(2026),
  isUserModified: false,
);

PlanSection _section(List<BeforeSubPhase> subPhases) => PlanSection(
  id: 'before_run',
  title: 'Before Run',
  foodItems: const [],
  subPhases: subPhases,
);

FoodItemData _food(
  String id, {
  int? carbs,
  double? fluidsMl,
  int? sodium,
}) => FoodItemData(
  id: id,
  name: id,
  quantity: '1',
  nutritionalInfo: NutritionalInfo(
    carbs: carbs,
    fluids: fluidsMl,
    sodium: sodium,
  ),
);

void main() {
  // The truncation assertion below is only meaningful with the real Sansita
  // metrics — the default test font is a wide fixed-advance placeholder that
  // would ellipsize text the shipped font fits comfortably.
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/Sansita/Sansita-Bold.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('Sansita')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  // Foods deliver: carbs 40+22 = 62 → round5 → 60 g; fluids 236+237 =
  // 473 ml → round25 → 475 → 16 oz. Targets deliberately disagree (90 g /
  // 700 ml) to prove the chips read the foods, not the targets.
  final meal = BeforeSubPhase(
    subPhaseType: 'meal',
    foodItems: [
      _food('oatmeal', carbs: 40, fluidsMl: 236, sodium: 150),
      _food('smoothie', carbs: 22, fluidsMl: 237, sodium: 150),
    ],
    carbsTarget: 90,
    fluidsTarget: 700,
    sodiumTarget: 300, // must never surface as a chip
  );
  // Snack delivers fluids too — under the revised rule it gets a fluids chip
  // (the meal-card-only restriction is gone). 28 g → 30 g; 200 ml → 7 oz.
  final snack = BeforeSubPhase(
    subPhaseType: 'snack',
    foodItems: [
      _food('apple', carbs: 28, sodium: 5),
      _food('sports drink', fluidsMl: 200, sodium: 100),
    ],
  );
  // A card with no foods delivers nothing → no chips, even with a target set.
  const emptyTopOff = BeforeSubPhase(
    subPhaseType: 'top_up',
    foodItems: [],
    carbsTarget: 30,
  );

  // Chips live in the tappable tile header; the section-level summary row
  // above the tiles legitimately shows its own CARBS/FLUIDS/SODIUM labels,
  // so scope the label assertions to the headers.
  Finder inTileHeader(String text) =>
      find.descendant(of: find.byType(InkWell), matching: find.text(text));

  testWidgets('chips show delivered values summed from the card foods, '
      'not the sub-phase targets', (tester) async {
    await tester.pumpWidget(
      _buildBeforePhase(_section([meal, snack, emptyTopOff])),
    );

    // Meal: delivered 62 g → 60g, 473 ml → 16oz (targets 90 g / 700 ml
    // would have been 90g / 24oz — neither may appear).
    expect(find.text('60g'), findsOneWidget);
    expect(find.text('16oz'), findsOneWidget);
    expect(find.text('90g'), findsNothing);
    expect(find.text('24oz'), findsNothing);

    // Snack: delivered 28 g → 30g and — new rule — its 200 ml → 7oz.
    expect(find.text('30g'), findsOneWidget);
    expect(find.text('7oz'), findsOneWidget);
    expect(inTileHeader('FLUIDS'), findsNWidgets(2));

    // The foodless top-off renders no chip despite its 30 g target: two
    // CARBS labels, not three, and never a "0g".
    expect(inTileHeader('CARBS'), findsNWidgets(2));
    expect(find.text('0g'), findsNothing);
  });

  testWidgets('quantity changes move the chip values', (tester) async {
    await tester.pumpWidget(_buildBeforePhase(_section([meal])));
    expect(find.text('60g'), findsOneWidget);
    expect(find.text('16oz'), findsOneWidget);

    // The stepper path: the controller rescales each food's nutritionalInfo
    // and emits a rebuilt plan — model that by pumping the updated section.
    // Doubling the oatmeal: carbs 80+22 = 102 → 100g; fluids 472+237 =
    // 709 ml → 700 → 24oz.
    final doubledOatmeal = meal.copyWith(
      foodItems: [
        _food('oatmeal', carbs: 80, fluidsMl: 472, sodium: 300),
        _food('smoothie', carbs: 22, fluidsMl: 237, sodium: 150),
      ],
    );
    await tester.pumpWidget(_buildBeforePhase(_section([doubledOatmeal])));

    expect(find.text('100g'), findsOneWidget);
    expect(find.text('24oz'), findsOneWidget);
    expect(find.text('60g'), findsNothing);
    expect(find.text('16oz'), findsNothing);
  });

  testWidgets('adding and removing foods moves the chips', (tester) async {
    await tester.pumpWidget(_buildBeforePhase(_section([snack])));
    expect(find.text('30g'), findsOneWidget);
    expect(find.text('7oz'), findsOneWidget);

    // Add an apple + almond butter (12 g): 28+28+12 = 68 → 70g.
    final grownSnack = snack.copyWith(
      foodItems: [
        ...snack.foodItems,
        _food('apple 2', carbs: 28, sodium: 5),
        _food('almond butter', carbs: 12, sodium: 40),
      ],
    );
    await tester.pumpWidget(_buildBeforePhase(_section([grownSnack])));
    expect(find.text('70g'), findsOneWidget);
    expect(find.text('30g'), findsNothing);

    // Remove the drink: no delivered fluids → the fluids chip disappears.
    final drinkless = snack.copyWith(
      foodItems: [_food('apple', carbs: 28, sodium: 5)],
    );
    await tester.pumpWidget(_buildBeforePhase(_section([drinkless])));
    expect(inTileHeader('FLUIDS'), findsNothing);
    expect(find.text('7oz'), findsNothing);
  });

  testWidgets('no sodium chip ever appears in the collapsed header', (
    tester,
  ) async {
    await tester.pumpWidget(_buildBeforePhase(_section([meal, snack])));

    expect(inTileHeader('SODIUM'), findsNothing);
    // Delivered sodium (300 mg) must not surface either.
    expect(find.text('300mg'), findsNothing);
  });

  testWidgets('metric users see the fluids chip in ml', (tester) async {
    await tester.pumpWidget(
      _buildBeforePhase(_section([meal]), useImperial: false),
    );

    expect(find.text('475ml'), findsOneWidget);
  });

  testWidgets('window labels follow the SSOT derivation', (tester) async {
    await tester.pumpWidget(
      _buildBeforePhase(_section([meal, snack, emptyTopOff])),
    );

    expect(find.text('FINISH BY 2H OUT'), findsOneWidget);
    expect(find.text('2H TO 30 MIN OUT'), findsOneWidget);
    expect(find.text('LAST 30 MIN'), findsOneWidget);
  });

  testWidgets('snack window shifts to NOW when no meal tier exists', (
    tester,
  ) async {
    await tester.pumpWidget(_buildBeforePhase(_section([snack, emptyTopOff])));

    expect(find.text('NOW – 30 MIN OUT'), findsOneWidget);
    expect(find.text('2H TO 30 MIN OUT'), findsNothing);
  });

  testWidgets('header chips persist when the card is expanded, and the '
      'old expanded macro-summary row is gone', (tester) async {
    await tester.pumpWidget(_buildBeforePhase(_section([meal, snack])));

    // Expand the meal card.
    await tester.tap(find.text('Pre-Workout Meal'));
    await tester.pumpAndSettle();
    expect(find.text('ADD FOOD'), findsOneWidget); // it really expanded

    // Chips stay in the header regardless of expansion state.
    expect(find.text('60g'), findsOneWidget);
    expect(find.text('16oz'), findsOneWidget);

    // The removed per-feeding summary would have added a second SODIUM
    // label; only the section-level summary's remains.
    expect(find.text('SODIUM'), findsOneWidget);
  });

  testWidgets('sodium summary carries no "from your food" note', (
    tester,
  ) async {
    await tester.pumpWidget(_buildBeforePhase(_section([meal, snack])));

    expect(find.text('from your food'), findsNothing);
  });

  testWidgets('summary row values share top alignment (sodium has no bar '
      'but must not sink)', (tester) async {
    await tester.pumpWidget(_buildBeforePhase(_section([meal, snack])));

    final row = tester.widget<Row>(
      find
          .descendant(
            of: find.byType(MacroSummaryRow),
            matching: find.byType(Row),
          )
          .first,
    );
    expect(row.crossAxisAlignment, CrossAxisAlignment.start);

    // And the render smoke: all three columns start at the same y.
    final items = find.byType(MacroSummaryItem);
    expect(items, findsNWidgets(3));
    final tops = [
      for (int i = 0; i < 3; i++) tester.getTopLeft(items.at(i)).dy,
    ];
    expect(tops[1], tops[0]);
    expect(tops[2], tops[0]);
  });

  testWidgets('BEFORE info button renders but is a no-op', (tester) async {
    await tester.pumpWidget(
      _buildBeforePhase(
        _section([meal, snack]),
        macroTargets: _macroTargetsFixture(),
      ),
    );

    final infoButton = find.byIcon(Icons.help_outline_rounded);
    expect(infoButton, findsOneWidget);

    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    // Stale BEFORE explanation copy — the sheet must not open.
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('meal title is sport-aware', (tester) async {
    await tester.pumpWidget(
      _buildBeforePhase(
        _section([meal]),
        activityType: ActivityType.running,
      ),
    );
    expect(find.text('Pre-Run Meal'), findsOneWidget);

    await tester.pumpWidget(_buildBeforePhase(_section([meal])));
    expect(find.text('Pre-Workout Meal'), findsOneWidget);
  });

  testWidgets('feeding titles use Sansita (not the caps-only Compadre demo '
      'cut) and fit one line at a 390 px phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildBeforePhase(_section([meal, snack])));

    // "Pre-Workout Snack" is the longest generic title.
    final title = tester.widget<Text>(find.text('Pre-Workout Snack'));
    expect(title.style?.fontFamily, 'Sansita');
    expect(title.style?.fontSize, 16);
    expect(title.style?.letterSpacing, 0);
    expect(title.maxLines, 1);

    // No truncation: the paragraph's intrinsic width fits the width it got.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Pre-Workout Snack'),
    );
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width + 0.01),
    );
  });
}
