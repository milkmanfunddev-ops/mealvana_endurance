// GESTURE / BEHAVIOUR TESTS for the pre-workout BEFORE card — one test per
// row of docs/ssot/conformance/design/pre-workout-before-card.gestures.yaml
// (17), plus the four the pre-workout-macros@v2 handoff adds:
// h_suppressed_when_gated (P1), s_fine_print_absent (P9), fc_stepper_clamp,
// and the R-01 oz pairs (in pre_workout_display_units_test.dart; the golden is
// in pre_workout_before_card_goldens_test.dart).
//
// Every test executes the REAL code path: the assembler builds the card data
// from engine-derived targets (63-kg canonical mock), and the hydration-check
// write goes through PreWorkoutHydrationCheckService — the same service the
// ActivityDetailController commits. A stateful host applies each emission
// and rebuilds, so "same frame" assertions pump once.
//
// Contract source: spec/design/{surfaces/pre-workout-before-card.md,
// components/{hydration-check,feeding-card,fuel-stat}.md} v1 (RATIFIED Xuan
// 2026-08-26); behaviour authority pre-workout-hydration.md v6 + PW-021.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_before_card_assembler.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_hydration_check_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_display_units.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/pre_workout_before_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/feeding_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/fuel_stat.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/hydration_check_control.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import 'pre_workout_before_card_fixtures.dart';

/// A host that owns plan + targets and applies every card emission through
/// the real write paths, then rebuilds — the controller's role, minus I/O.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.t,
    required this.plan,
    required this.targets,
    this.expanded = const {'meal', 'snack', 'top_off'},
    this.checkExpanded = true,
    this.bodyWeightKg = kMockBodyWeightKg,
  });

  final double t;
  final NutritionPlan plan;
  final MacroTargets targets;
  final Set<String> expanded;
  final bool checkExpanded;
  final double? bodyWeightKg;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late NutritionPlan plan = widget.plan;
  late MacroTargets targets = widget.targets;
  int addFoodCalls = 0;
  final List<(String, double)> steps = [];
  int idSeq = 0;

  PreWorkoutBeforeCardData get data => PreWorkoutBeforeCardAssembler.assemble(
    preRun: targets.preRun,
    subPhases: plan.sections.first.subPhases!,
    timeBeforeWorkoutMin: widget.t,
    bodyWeightKg: widget.bodyWeightKg,
    hydrationCheck: plan.preWorkoutHydrationCheck,
  );

  void _step(FeedingFoodRow row, double qty) {
    steps.add((row.id, qty));
    setState(() {
      plan = plan.copyWith(
        sections: plan.sections.map((s) {
          if (!s.hasSubPhases) return s;
          return s.copyWith(
            subPhases: s.subPhases!
                .map(
                  (sp) => sp.copyWith(
                    foodItems: qty <= 0
                        ? sp.foodItems.where((f) => f.id != row.id).toList()
                        : sp.foodItems
                              .map((f) => f.id == row.id ? _scaled(f, qty) : f)
                              .toList(),
                  ),
                )
                .toList(),
          );
        }).toList(),
      );
    });
  }

  FoodItemData _scaled(FoodItemData f, double qty) {
    final cur =
        double.tryParse(RegExp(r'^[\d.]+').stringMatch(f.quantity) ?? '') ?? 1;
    final k = qty / cur;
    final n = f.nutritionalInfo!;
    return FoodItemData(
      id: f.id,
      name: f.name,
      quantity: '$qty ${f.quantity.split(' ').skip(1).join(' ')}',
      isDrink: f.isDrink,
      isIndivisible: f.isIndivisible,
      origin: f.origin,
      nutritionalInfo: NutritionalInfo(
        carbs: ((n.carbs ?? 0) * k).round(),
        sodium: ((n.sodium ?? 0) * k).round(),
        fluids: (n.fluids ?? 0) * k,
      ),
    );
  }

  void _answer(HydrationCheckAnswer a) {
    final w = PreWorkoutHydrationCheckService.answer(
      plan: plan,
      targets: targets,
      answer: a,
      bodyWeightKg: widget.bodyWeightKg ?? kMockBodyWeightKg,
      workoutDurationMin: kMockDurationMin,
      timeBeforeWorkoutMin: widget.t,
      tempC: 22,
      newFoodId: () => 'hwat-${idSeq++}',
    );
    setState(() {
      plan = w.plan;
      targets = w.targets;
    });
  }

  void _revert() {
    final w = PreWorkoutHydrationCheckService.revert(
      plan: plan,
      targets: targets,
    );
    setState(() {
      plan = w.plan;
      targets = w.targets;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PreWorkoutBeforeCard(
      data: data,
      initiallyExpandedTiers: widget.expanded,
      hydrationCheckInitiallyExpanded: widget.checkExpanded,
      onStep: _step,
      onAddFood: (_) => addFoodCalls++,
      onAnswerHydrationCheck: _answer,
      onChangeHydrationAnswer: _revert,
    );
  }
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route route, Route? previousRoute) => pushes++;
}

Future<_HostState> _pump(
  WidgetTester tester, {
  double t = 180,
  bool gated = false,
  double mealWaterCups = 2,
  Set<String> expanded = const {'meal', 'snack', 'top_off'},
  bool checkExpanded = true,
  _Observer? observer,
  double? bodyWeightKg = kMockBodyWeightKg,
}) async {
  tester.view.physicalSize = const Size(428, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final preRun = mockPreRun(t: t, gated: gated);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [if (observer != null) observer],
      home: Scaffold(
        backgroundColor: AppColors.blackberry,
        body: SingleChildScrollView(
          child: _Host(
            // A fresh State per scenario — otherwise Flutter reuses the host
            // (same type, same slot) and its plan carries over.
            key: UniqueKey(),
            t: t,
            plan: mockPlan(mockSubPhases(t, mealWaterCups: mealWaterCups)),
            targets: mockMacroTargets(preRun, gated: gated),
            expanded: expanded,
            checkExpanded: checkExpanded,
            bodyWeightKg: bodyWeightKg,
          ),
        ),
      ),
    ),
  );
  return tester.state<_HostState>(find.byType(_Host));
}

String _text(WidgetTester tester, Key key) =>
    (tester.widget<Text>(find.byKey(key))).data!;

/// A marker's x position on screen (works for both the suggested triangle and
/// the delivered diamond, whatever widget carries the key).
double _markerLeft(WidgetTester tester, Key key) =>
    tester.getTopLeft(find.byKey(key)).dx;

Color _deliveredColor(WidgetTester tester, FuelQuantity q) => tester
    .widget<FuelStatDeliveredMarker>(find.byKey(FuelStat.deliveredMarkerKey(q)))
    .color;

void main() {
  // ------------------------------------------------------------------------
  // hydration-check component (H-1..H-5)
  // ------------------------------------------------------------------------
  group('hydration-check', () {
    testWidgets(
      'h1_expand: tap the TO-DO chip -> question in place, no navigation',
      (tester) async {
        final observer = _Observer();
        await _pump(tester, checkExpanded: false, observer: observer);
        final pushesBefore = observer.pushes;
        expect(find.byKey(HydrationCheckControl.todoKey), findsOneWidget);
        expect(find.byKey(HydrationCheckControl.questionKey), findsNothing);

        await tester.tap(find.byKey(HydrationCheckControl.headerKey));
        await tester.pump();

        expect(find.text(HydrationCheckCopy.question), findsOneWidget);
        expect(find.text(HydrationCheckCopy.timing), findsOneWidget);
        expect(find.text(HydrationCheckCopy.caveat), findsOneWidget);
        for (final a in [
          HydrationCheckAnswer.pale,
          HydrationCheckAnswer.dark,
          HydrationCheckAnswer.notYet,
          HydrationCheckAnswer.notSure,
        ]) {
          expect(
            find.byKey(HydrationCheckControl.optionKey(a)),
            findsOneWidget,
          );
        }
        expect(observer.pushes, pushesBefore, reason: 'H-1: never navigates');
      },
    );

    testWidgets(
      'h2_answer_writes_target: DARK/NOT_YET raise fluidMl by TOPUP_ML_KG*BW; PALE/NOT_SURE unchanged; band byte-identical',
      (tester) async {
        for (final answer in [
          HydrationCheckAnswer.dark,
          HydrationCheckAnswer.notYet,
          HydrationCheckAnswer.pale,
          HydrationCheckAnswer.notSure,
        ]) {
          final host = await _pump(tester);
          final before = host.targets.preRun;
          final baseTargetOz = flOzTarget(before.fluidsMl!);
          expect(
            _markerLeft(
              tester,
              FuelStat.suggestedMarkerKey(FuelQuantity.fluids),
            ),
            isNotNull,
          );
          final tBefore = _markerLeft(
            tester,
            FuelStat.suggestedMarkerKey(FuelQuantity.fluids),
          );

          await tester.tap(find.byKey(HydrationCheckControl.optionKey(answer)));
          await tester.pump();
          // The data write lands in this frame; the marker's 220 ms slide
          // (rendering: `transition: left .22s`) needs the clock advanced.
          await tester.pump(const Duration(milliseconds: 300));
          final after = host.targets.preRun;

          if (answer.raisesTarget) {
            // +4 ml/kg (63 kg -> +252 ml): 472.5 -> 724.5 ml, 16 -> 24 oz.
            expect(after.fluidsMl, closeTo(before.fluidsMl! + 4 * 63, 1e-6));
            expect(flOzTarget(after.fluidsMl!), baseTargetOz + 8);
            expect(
              _markerLeft(
                tester,
                FuelStat.suggestedMarkerKey(FuelQuantity.fluids),
              ),
              greaterThan(tBefore),
              reason: 'the target marker MOVES',
            );
            expect(after.hydrationCheckUsed, 'dark');
          } else {
            expect(after.fluidsMl, before.fluidsMl);
            expect(
              _markerLeft(
                tester,
                FuelStat.suggestedMarkerKey(FuelQuantity.fluids),
              ),
              tBefore,
            );
          }
          // inv. 8b: the band never moves; carbs, sodium and tiers untouched.
          expect(after.fluidsLowMl, before.fluidsLowMl);
          expect(after.fluidsHighMl, before.fluidsHighMl);
          expect(after.carbsG, before.carbsG);
          expect(after.carbsLowG, before.carbsLowG);
          expect(after.carbsHighG, before.carbsHighG);
          expect(after.carbTiers, before.carbTiers);
          expect(after.sodiumMg, before.sodiumMg);
          expect(
            after.fluidTiers!.map((t) => t.tier),
            before.fluidTiers!.map((t) => t.tier),
            reason: 'tier structure stable',
          );
          expect(
            _text(tester, FuelStat.figureKey(FuelQuantity.sodium)),
            '310mg',
          );
        }
      },
    );

    testWidgets(
      'h2_already_covered: delivered >= raised target -> target rises, NO row',
      (tester) async {
        // 6 cups in the meal = 1419 ml >= 724.5 ml raised target.
        final host = await _pump(tester, mealWaterCups: 6);
        final before = host.targets.preRun.fluidsMl!;
        final rowsBefore = host.data.feedings[1].rows.length;

        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump();

        expect(host.targets.preRun.fluidsMl, closeTo(before + 252, 1e-6));
        expect(host.data.feedings[1].rows.length, rowsBefore);
        expect(host.plan.preWorkoutHydrationCheck!.addedWaterFoodId, isNull);
        expect(find.textContaining('already covered'), findsWidgets);
        expect(
          _text(tester, HydrationCheckControl.statusKey),
          'Dark · target 24 oz, already covered',
        );
      },
    );

    testWidgets(
      'h3_change_answer_reverts: target back, tagged row gone, answer NONE',
      (tester) async {
        final host = await _pump(tester);
        final baseline = host.targets.preRun.fluidsMl;
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump();
        expect(find.text(HydrationCheckCopy.addedRowNote), findsOneWidget);
        expect(host.targets.preRun.fluidsMl, isNot(baseline));

        // Edit the tagged row first (P3: still removed on revert).
        final addedId = host.plan.preWorkoutHydrationCheck!.addedWaterFoodId!;
        await tester.tap(find.byKey(FeedingCard.incKey(addedId)));
        await tester.pump();

        await tester.tap(find.byKey(HydrationCheckControl.changeAnswerKey));
        await tester.pump();

        expect(host.plan.preWorkoutHydrationCheck, isNull);
        expect(host.targets.preRun.fluidsMl, baseline);
        expect(find.text(HydrationCheckCopy.addedRowNote), findsNothing);
        expect(find.byKey(FeedingCard.rowKey(addedId)), findsNothing);
        expect(find.byKey(HydrationCheckControl.todoKey), findsOneWidget);
        expect(find.text(HydrationCheckCopy.question), findsOneWidget);
      },
    );

    testWidgets(
      'h_suppressed_below_2h: t < T_REF -> NO control node; no inline cue',
      (tester) async {
        for (final t in [90.0, 105.0, 20.0, 0.0]) {
          await _pump(tester, t: t);
          expect(find.byType(HydrationCheckControl), findsNothing);
          expect(find.byKey(HydrationCheckControl.rootKey), findsNothing);
          expect(find.text(HydrationCheckCopy.title), findsNothing);
          expect(find.textContaining('pale'), findsNothing);
        }
        // ...and present at exactly T_REF.
        await _pump(tester, t: 120);
        expect(find.byType(HydrationCheckControl), findsOneWidget);
      },
    );

    testWidgets(
      'h_no_live_clock: no NOW/PASSED indicator; membership from lead time only',
      (tester) async {
        for (final t in [180.0, 90.0, 20.0]) {
          final host = await _pump(tester, t: t);
          expect(find.text('NOW'), findsNothing);
          expect(find.text('PASSED'), findsNothing);
          expect(find.byKey(const Key('live_window')), findsNothing);
          final expected = t >= 120 ? 3 : (t >= 30 ? 2 : 1);
          expect(host.data.feedings.length, expected);
          expect(find.byType(FeedingCard), findsNWidgets(expected));
          // The check exists on every >= 2h plan regardless of any clock.
          expect(
            find.byType(HydrationCheckControl),
            t >= 120 ? findsOneWidget : findsNothing,
          );
        }
      },
    );

    // Deferred-ledger P1 (handoff addition).
    testWidgets(
      'h_suppressed_when_gated: regime == gated -> NO control even at t >= T_REF',
      (tester) async {
        final host = await _pump(tester, gated: true);
        expect(host.targets.preRun.isHydrationGated, isTrue);
        expect(host.targets.preRun.fluidsMl, isNull);
        expect(find.byType(HydrationCheckControl), findsNothing);
        expect(
          find.byType(FeedingCard),
          findsNWidgets(3),
          reason: 'feedings intact',
        );
      },
    );
  });

  // ------------------------------------------------------------------------
  // feeding-card component (FC-*)
  // ------------------------------------------------------------------------
  group('feeding-card', () {
    testWidgets(
      'fc_naming_threshold: snack flips at LIGHT_MEAL_G_PER_KG*BW; MEAL never renamed',
      (tester) async {
        await _pump(tester, t: 180); // snack aim 56.7 g < 63 g
        expect(
          _text(tester, FeedingCard.titleKey('snack')),
          'Pre-Workout Snack',
        );
        expect(_text(tester, FeedingCard.titleKey('meal')), 'Pre-Run Meal');

        await _pump(tester, t: 240); // snack aim 75.6 g >= 63 g
        expect(_text(tester, FeedingCard.titleKey('snack')), 'Light Meal');
        expect(_text(tester, FeedingCard.titleKey('meal')), 'Pre-Run Meal');

        // Lower body weight: 180-min snack (56.7 g) crosses 1.0 g/kg at 56 kg.
        await _pump(tester, t: 180, bodyWeightKg: 56);
        expect(_text(tester, FeedingCard.titleKey('snack')), 'Light Meal');
      },
    );

    testWidgets(
      'fc_header_delivered_only: "52g" moves with the stepper; no aim, no DONE/AIM, no ±12.5%',
      (tester) async {
        await _pump(tester);
        expect(find.byKey(FeedingCard.carbsKey('meal')), findsOneWidget);
        expect(find.text('52g'), findsOneWidget);
        expect(find.text('CARBS'), findsWidgets);

        await tester.tap(find.byKey(FeedingCard.incKey('oat')));
        await tester.pump();
        expect(find.text('104g'), findsOneWidget);

        expect(find.textContaining('AIM'), findsNothing);
        expect(find.textContaining('DONE'), findsNothing);
        expect(find.textContaining('12.5'), findsNothing);
        expect(
          find.textContaining('–'),
          findsNothing,
          reason: 'no per-tier window',
        );
        // The tier aim (113.4 g for the meal at 3 h) appears nowhere.
        expect(find.textContaining('113'), findsNothing);
      },
    );

    testWidgets(
      'fc_hydration_row_placement: first row of the SNACK card on >= 2h; DARK adds the tagged row there',
      (tester) async {
        final host = await _pump(tester);
        final snack = find.byKey(FeedingCard.cardKey('snack'));
        expect(
          find.descendant(
            of: snack,
            matching: find.byType(HydrationCheckControl),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(FeedingCard.cardKey('meal')),
            matching: find.byType(HydrationCheckControl),
          ),
          findsNothing,
        );
        // First row: the control sits above the first food row.
        final checkTop = tester
            .getTopLeft(find.byType(HydrationCheckControl))
            .dy;
        final rxTop = tester
            .getTopLeft(find.byKey(FeedingCard.rowKey('rx')))
            .dy;
        expect(checkTop, lessThan(rxTop));

        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump();
        final addedId = host.plan.preWorkoutHydrationCheck!.addedWaterFoodId!;
        expect(
          find.descendant(
            of: snack,
            matching: find.byKey(FeedingCard.rowKey(addedId)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: snack,
            matching: find.text(HydrationCheckCopy.addedRowNote),
          ),
          findsOneWidget,
        );
        expect(find.text(HydrationCheckCopy.addedRowName), findsOneWidget);

        await _pump(tester, t: 90);
        expect(find.byType(HydrationCheckControl), findsNothing);
      },
    );

    // Handoff addition: FC-5 / FC-G2 — the row's own step and cap.
    testWidgets(
      'fc_stepper_clamp: chews step 0.5, cap at 8, 0 removes the row (P3)',
      (tester) async {
        final host = await _pump(tester);
        expect(_text(tester, FeedingCard.qtyKey('chew')), '0.5');
        await tester.tap(find.byKey(FeedingCard.incKey('chew')));
        await tester.pump();
        expect(_text(tester, FeedingCard.qtyKey('chew')), '1');
        expect(host.steps.last, ('chew', 1.0));

        // Indivisible rows step by 1.
        await tester.tap(find.byKey(FeedingCard.incKey('oat')));
        await tester.pump();
        expect(host.steps.last, ('oat', 2.0));
        expect(_text(tester, FeedingCard.qtyKey('oat')), '2');

        // Cap: 8 stays 8.
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.byKey(FeedingCard.incKey('oat')));
          await tester.pump();
        }
        expect(_text(tester, FeedingCard.qtyKey('oat')), '8');
        expect(host.steps.where((s) => s.$2 > 8), isEmpty);

        // Stepping the chews back to 0 removes the row.
        await tester.tap(find.byKey(FeedingCard.decKey('chew')));
        await tester.pump();
        expect(_text(tester, FeedingCard.qtyKey('chew')), '0.5');
        await tester.tap(find.byKey(FeedingCard.decKey('chew')));
        await tester.pump();
        expect(host.steps.last, ('chew', 0.0));
        expect(find.byKey(FeedingCard.rowKey('chew')), findsNothing);
      },
    );
  });

  // ------------------------------------------------------------------------
  // fuel-stat component (F-*, M-*)
  // ------------------------------------------------------------------------
  group('fuel-stat', () {
    // F-1 as amended by AMENDMENT A1 (Xuan, 2026-09-03): the fasted state is
    // retired, so the trio narrows to the remaining PAIR — the gate ("we're
    // not stating a target") vs the start-line real 0g ("we recommend
    // none"). The distinctness rule is unchanged for the remaining pair.
    testWidgets(
      'fs_two_no_number_states: gated and start line are two distinct trees',
      (tester) async {
        await _pump(tester, gated: true);
        expect(find.text('No fluid target for this session'), findsOneWidget);
        expect(
          find.byKey(FuelStat.figureKey(FuelQuantity.fluids)),
          findsNothing,
        );
        expect(find.byKey(FuelStat.bandKey(FuelQuantity.fluids)), findsNothing);
        expect(find.text('0oz'), findsNothing, reason: 'a gate is never 0 oz');
        expect(
          find.byKey(FuelStat.bandKey(FuelQuantity.carbs)),
          findsOneWidget,
        );
        expect(find.byType(FeedingCard), findsNWidgets(3));

        await _pump(tester, t: 0);
        expect(_text(tester, FuelStat.figureKey(FuelQuantity.carbs)), '0g');
        expect(find.byKey(FuelStat.bandKey(FuelQuantity.carbs)), findsNothing);
        expect(find.text('No carbs this session'), findsNothing);
        expect(find.text('No fluid target for this session'), findsNothing);
        expect(
          find.byType(FeedingCard),
          findsOneWidget,
          reason: 'top-off kept',
        );
      },
    );

    testWidgets(
      'fs_fluid_one_way_carbs_two_way: fluid recolours above only; carbs both ways',
      (tester) async {
        final base = PreWorkoutBeforeCardAssembler.assemble(
          preRun: mockPreRun(t: 180),
          subPhases: mockSubPhases(180),
          timeBeforeWorkoutMin: 180,
          bodyWeightKg: 63,
          hydrationCheck: null,
        );
        Future<Color> colorFor(FuelStatData stat) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 120, child: FuelStat(data: stat)),
              ),
            ),
          );
          return _deliveredColor(tester, stat.quantity);
        }

        FuelStatData drive(FuelStatData s, int delivered) => FuelStatData(
          quantity: s.quantity,
          mode: s.mode,
          delivered: delivered,
          target: s.target,
          bandLow: s.bandLow,
          bandHigh: s.bandHigh,
        );

        final f = base.fluids;
        expect(await colorFor(drive(f, 0)), AppColors.electrolyte);
        expect(
          await colorFor(drive(f, f.bandHigh! * 2)),
          AppColors.dragonfruit,
        );

        final c = base.carbs;
        expect(await colorFor(drive(c, c.bandLow! - 1)), AppColors.dragonfruit);
        expect(
          await colorFor(drive(c, c.bandHigh! + 1)),
          AppColors.dragonfruit,
        );
        expect(await colorFor(drive(c, c.target!)), AppColors.electrolyte);
      },
    );

    testWidgets(
      'fs_two_markers: delivered moves on a row change, suggested does not; suggested on a band end is not an alarm',
      (tester) async {
        await _pump(tester);
        final dBefore = _markerLeft(
          tester,
          FuelStat.deliveredMarkerKey(FuelQuantity.carbs),
        );
        final tBefore = _markerLeft(
          tester,
          FuelStat.suggestedMarkerKey(FuelQuantity.carbs),
        );
        await tester.tap(find.byKey(FeedingCard.incKey('rx')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // marker slide
        expect(
          _markerLeft(tester, FuelStat.deliveredMarkerKey(FuelQuantity.carbs)),
          isNot(dBefore),
        );
        expect(
          _markerLeft(tester, FuelStat.suggestedMarkerKey(FuelQuantity.carbs)),
          tBefore,
        );

        // M-3: target exactly on the ceiling, delivered in band -> no alarm.
        const onEdge = FuelStatData(
          quantity: FuelQuantity.fluids,
          mode: FuelStatMode.targeted,
          delivered: 20,
          target: 26,
          bandLow: 10,
          bandHigh: 26,
        );
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 120, child: FuelStat(data: onEdge)),
            ),
          ),
        );
        expect(
          _deliveredColor(tester, FuelQuantity.fluids),
          AppColors.electrolyte,
        );
        expect(onEdge.deliveredOutOfBand, isFalse);
      },
    );

    testWidgets(
      'fs_sodium_never_banded: no band, marker or range node under SODIUM in any state',
      (tester) async {
        for (final (t, gated) in [
          (180.0, false),
          (180.0, true),
          (90.0, false),
          (0.0, false),
        ]) {
          final host = await _pump(tester, t: t, gated: gated);
          expect(
            find.byKey(FuelStat.bandKey(FuelQuantity.sodium)),
            findsNothing,
          );
          expect(
            find.byKey(FuelStat.deliveredMarkerKey(FuelQuantity.sodium)),
            findsNothing,
          );
          expect(
            find.byKey(FuelStat.suggestedMarkerKey(FuelQuantity.sodium)),
            findsNothing,
          );
          expect(host.data.sodium.showBand, isFalse);
          expect(host.data.sodium.target, isNull);
          // Σ rows, never the legacy map: the mock plan carries no sodiumMg target.
          expect(host.targets.preRun.sodiumMg, isNull);
        }
      },
    );

    testWidgets(
      'fs_no_basis_signifier: no caption, solid rails, bands identical across targetBasis',
      (tester) async {
        final hostA = await _pump(tester, t: 180); // evidenced_band
        expect(hostA.targets.preRun.fluidTargetBasis, 'evidenced_band');
        expect(find.textContaining('guideline'), findsNothing);
        expect(find.textContaining('our estimate'), findsNothing);
        expect(find.textContaining('evidenced'), findsNothing);
        expect(find.textContaining('design'), findsNothing);
        final bandA = tester.widget<Column>(
          find.byKey(FuelStat.bandKey(FuelQuantity.fluids)),
        );

        final hostB = await _pump(tester, t: 90); // design_choice
        expect(hostB.targets.preRun.fluidTargetBasis, 'design_choice');
        expect(find.textContaining('guideline'), findsNothing);
        expect(find.textContaining('our estimate'), findsNothing);
        final bandB = tester.widget<Column>(
          find.byKey(FuelStat.bandKey(FuelQuantity.fluids)),
        );
        // Same widget structure (rail + labels), i.e. no extra caption node.
        expect(bandB.children.length, bandA.children.length);
        expect(bandB.children.runtimeType, bandA.children.runtimeType);
      },
    );
  });

  // ------------------------------------------------------------------------
  // surface (B-*)
  // ------------------------------------------------------------------------
  group('surface', () {
    testWidgets(
      's_delivered_is_surface_sum: figure = Σ rows; a stepper re-totals in the same frame',
      (tester) async {
        final host = await _pump(tester);
        final rows = host.data.feedings.expand((f) => f.rows).toList();
        final sumCarbs = rows.fold<double>(0, (a, r) => a + r.carbsG).round();
        final sumSodium = rows
            .fold<double>(0, (a, r) => a + r.sodiumMg)
            .round();
        final sumFluidMl = rows.fold<double>(0, (a, r) => a + r.fluidMl);
        expect(
          _text(tester, FuelStat.figureKey(FuelQuantity.carbs)),
          '${sumCarbs}g',
        );
        expect(
          _text(tester, FuelStat.figureKey(FuelQuantity.sodium)),
          '${sumSodium}mg',
        );
        expect(
          _text(tester, FuelStat.figureKey(FuelQuantity.fluids)),
          '${flOzDelivered(sumFluidMl)}oz',
        );
        expect(sumCarbs, 89); // 52 + 24 + 13
        expect(sumSodium, 310); // 120 + 150 + 40

        await tester.tap(find.byKey(FeedingCard.incKey('rx')));
        await tester.pump(); // ONE frame
        expect(
          _text(tester, FuelStat.figureKey(FuelQuantity.carbs)),
          '${sumCarbs + 24}g',
        );
        expect(
          _text(tester, FuelStat.figureKey(FuelQuantity.sodium)),
          '${sumSodium + 150}mg',
        );
      },
    );

    testWidgets(
      's_answer_propagates: DARK re-totals FLUIDS + inserts the row in ONE frame; band unchanged; revert reverses',
      (tester) async {
        final host = await _pump(tester);
        final fluidsBefore = _text(
          tester,
          FuelStat.figureKey(FuelQuantity.fluids),
        );
        final bandLow = host.data.fluids.bandLow;
        final bandHigh = host.data.fluids.bandHigh;
        final rowsBefore = find.byType(FeedingCard).evaluate().length;

        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump(); // ONE frame
        expect(_text(tester, FuelStat.figureKey(FuelQuantity.fluids)), '24oz');
        expect(fluidsBefore, '16oz');
        expect(find.text(HydrationCheckCopy.addedRowNote), findsOneWidget);
        expect(host.data.fluids.bandLow, bandLow);
        expect(host.data.fluids.bandHigh, bandHigh);
        expect(host.data.fluids.target, 24);
        expect(find.byType(FeedingCard).evaluate().length, rowsBefore);

        await tester.tap(find.byKey(HydrationCheckControl.changeAnswerKey));
        await tester.pump(); // ONE frame
        expect(_text(tester, FuelStat.figureKey(FuelQuantity.fluids)), '16oz');
        expect(find.text(HydrationCheckCopy.addedRowNote), findsNothing);
        expect(host.data.fluids.target, 16);
      },
    );

    testWidgets(
      's_copy_registers: the check strings match components/hydration-check.md',
      (tester) async {
        await _pump(tester);
        expect(
          find.text('Is your urine pale yellow right now?'),
          findsOneWidget,
        );
        expect(
          find.text(
            "Do this about two hours before you start, once you've finished your pre-run meal.",
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            "On a multivitamin or B-complex? It turns urine yellow on its own — don't read that as dark — choose Not sure.",
          ),
          findsOneWidget,
        );
        expect(find.text('Hydration check'), findsOneWidget);
        expect(find.text('adjusts your fluid target'), findsOneWidget);
        expect(find.text('TO-DO'), findsOneWidget);
        expect(find.text('Pale yellow'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text("Haven't gone yet"), findsOneWidget);
        expect(find.text('Not sure'), findsOneWidget);

        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.pale),
          ),
        );
        await tester.pump();
        expect(find.text('Pale yellow · target unchanged'), findsOneWidget);
        expect(
          find.text("You're hydrated. Your fluid target is unchanged."),
          findsOneWidget,
        );
        expect(find.text('Change answer'), findsOneWidget);

        await _pump(tester);
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump();
        // Real copy interpolates round(fluidMl / 29.5735): 724.5 ml -> 24 oz.
        expect(find.text('Dark · target raised to 24 oz'), findsOneWidget);
        expect(
          find.text(
            'Your fluid target rises to 24 oz. An 8 oz water entry was added to help you get there — adjust it like any other item.',
          ),
          findsOneWidget,
        );

        await _pump(tester, mealWaterCups: 6);
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.notYet),
          ),
        );
        await tester.pump();
        expect(
          find.text('Not yet · target 24 oz, already covered'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Treated as dark for now — update after you go. Your fluid target rises to 24 oz. What you already have planned covers it, so nothing was added.',
          ),
          findsOneWidget,
        );

        await _pump(tester);
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.notSure),
          ),
        );
        await tester.pump();
        expect(
          find.text('Not sure · no change to your target'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Recorded with no change to your target. Check when you can and update your answer.',
          ),
          findsOneWidget,
        );
        // DEFERRED (S-G4): the ?-fine-print-matches-notes-§7 clause — see
        // s_fine_print_absent below.
      },
    );

    // N3 — ops bug 2026-08-26-hydration-check-result-copy-stale-after-edits:
    // the result line is derived from CURRENT state, never stored at answer time.
    testWidgets(
      'N3: result copy re-derives after a row edit (covered → shortfall; added → removed)',
      (tester) async {
        // (a) covered: 6 cups in the meal → DARK adds nothing.
        final host = await _pump(tester, mealWaterCups: 6);
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump();
        expect(find.textContaining('already covered'), findsWidgets);

        // Step the meal water down until delivered < the raised target (24 oz):
        // 6 cups (48 oz) → 2 cups (16 oz).
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(FeedingCard.decKey('wat')));
          await tester.pump();
        }
        expect(host.data.fluids.delivered, lessThan(host.data.fluids.target!));
        expect(find.textContaining('already covered'), findsNothing);
        expect(find.textContaining('was added'), findsNothing);
        expect(
          _text(tester, HydrationCheckControl.statusKey),
          'Dark · target raised to 24 oz',
        );
        expect(
          _text(tester, HydrationCheckControl.bodyKey),
          'Your fluid target rises to 24 oz.',
        );

        // (b) added: 2 cups → DARK adds the tagged row; step it to 0 (removed).
        final host2 = await _pump(tester);
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.dark),
          ),
        );
        await tester.pump();
        expect(find.textContaining('was added'), findsOneWidget);
        final addedId = host2.plan.preWorkoutHydrationCheck!.addedWaterFoodId!;
        // The water row steps by 0.5 (divisible): 1 → 0.5 keeps the tag (N2),
        // 0.5 → 0 removes the row (P3).
        await tester.tap(find.byKey(FeedingCard.decKey(addedId)));
        await tester.pump();
        expect(find.byKey(FeedingCard.noteKey(addedId)), findsOneWidget);
        expect(find.textContaining('was added'), findsOneWidget);
        await tester.tap(find.byKey(FeedingCard.decKey(addedId)));
        await tester.pump();
        expect(find.byKey(FeedingCard.rowKey(addedId)), findsNothing);
        expect(find.textContaining('was added'), findsNothing);
        expect(
          _text(tester, HydrationCheckControl.bodyKey),
          'Your fluid target rises to 24 oz.',
        );
      },
    );

    // N5 — ops bug 2026-08-26-hydration-check-change-answer-tap-target-too-small.
    testWidgets('N5: "Change answer" hit-tests across a ≥ 44 pt band', (
      tester,
    ) async {
      final host = await _pump(tester);
      await tester.tap(
        find.byKey(HydrationCheckControl.optionKey(HydrationCheckAnswer.pale)),
      );
      await tester.pump();
      final link = find.byKey(HydrationCheckControl.changeAnswerKey);
      final box = tester.getRect(link);
      expect(box.height, greaterThanOrEqualTo(44));
      // A finger landing 18 pt above and 18 pt below the text centre both hit.
      final textCentre = tester.getCenter(
        find.text(HydrationCheckCopy.changeAnswer),
      );
      for (final dy in [-18.0, 18.0]) {
        final y = (textCentre.dy + dy).clamp(box.top + 1, box.bottom - 1);
        await tester.tapAt(Offset(textCentre.dx, y));
        await tester.pump();
        expect(
          host.plan.preWorkoutHydrationCheck,
          isNull,
          reason: 'reverted at dy=$dy',
        );
        // Re-answer for the next probe.
        await tester.tap(
          find.byKey(
            HydrationCheckControl.optionKey(HydrationCheckAnswer.pale),
          ),
        );
        await tester.pump();
      }
    });

    // F-7 — ops bug 2026-08-26-food-row-names-truncate-at-narrow-width: the
    // name wraps to a second line rather than losing its parenthetical.
    testWidgets(
      'F-7: a long food name wraps to two lines, no single-line ellipsis',
      (tester) async {
        tester.view.physicalSize = const Size(402, 2400); // iPhone 17 width
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        // Real font: the fallback test face (Ahem) is a 1 em square per glyph
        // and would overflow any width — the rule under test is the wrap.
        final loader = FontLoader('Sansita')
          ..addFont(
            Future.value(
              ByteData.view(
                Uint8List.fromList(
                  File(
                    'assets/fonts/Sansita/Sansita-Bold.ttf',
                  ).readAsBytesSync(),
                ).buffer,
              ),
            ),
          );
        await loader.load();
        final plan = mockPlan([
          BeforeSubPhase(
            subPhaseType: 'snack',
            foodItems: [
              FoodItemData(
                id: 'rc',
                name: 'Oatmeal (½ cup dry) with banana',
                quantity: '1 bowl Oatmeal (½ cup dry) with banana',
                isIndivisible: true,
                nutritionalInfo: const NutritionalInfo(
                  carbs: 14,
                  sodium: 58,
                  fluids: 0,
                ),
              ),
            ],
          ),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: _Host(
                  key: UniqueKey(),
                  t: 90,
                  plan: plan,
                  targets: mockMacroTargets(mockPreRun(t: 90)),
                  expanded: const {'snack'},
                ),
              ),
            ),
          ),
        );
        final name = find.text('Oatmeal (½ cup dry) with banana');
        final text = tester.widget<Text>(name);
        expect(text.maxLines, 2);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'no ellipsis at two lines',
        );
        // Two lines tall (15 px × 1.2 line height ≈ 18 per line).
        expect(tester.getSize(name).height, greaterThan(30));
        expect(find.textContaining('…'), findsNothing);
      },
    );

    // Deferred-ledger P9 / S-G4 (handoff addition): the `?` is ABSENT, not inert.
    testWidgets(
      's_fine_print_absent: no "?" control, no "About these numbers"',
      (tester) async {
        for (final t in [180.0, 90.0, 0.0]) {
          await _pump(tester, t: t);
          expect(find.text('?'), findsNothing);
          expect(find.byKey(const Key('fine_print')), findsNothing);
          expect(find.textContaining('About these numbers'), findsNothing);
          expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
          expect(find.byIcon(Icons.help_outline), findsNothing);
        }
      },
    );
  });
}
