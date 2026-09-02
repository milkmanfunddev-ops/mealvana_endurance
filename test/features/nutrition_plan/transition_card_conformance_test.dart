// Design conformance — transition card + drawer.
// SSOT: docs/ssot/spec/design/components/transition-card.md (RATIFIED v1,
// Xuan 2026-09-01); manifest: docs/ssot/conformance/design/transition-card.yaml
// (run via qa/conformance/run_dart.sh transition-card).
//
//   TC-1 — positional title on a bike→run brick (the D-008 order)
//   TC-2 — stat trio CARBS · FLUIDS · SODIUM: carbs delivered/target with
//          band [0,30]; fluids + sodium plain tallies; protein dropped
//   TC-4 — drawer numbers/formulas equal the ratified math for a known
//          input; fluid/sodium sections carry no formula implying a target
//   TC-5 — copy sport-pair-aware or neutral (no swim/wetsuit references on
//          a non-swim brick); carb cue agrees with the target
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/brick_nutrition_sections.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/macro_summary_row.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';

/// A bike→run brick's MacroTargets with one transition (T1) carrying the
/// W1-shaped T-1 dose: rate 52.5 g/h × gap 33 min ÷ 60 = 28.875 → 29 g.
MacroTargets bikeRunMacroTargets({double doseG = 29}) => MacroTargets(
  id: 'qa-brick',
  activityType: ActivityType.brick,
  preRun: const PreRunMacros(
    carbsG: 60,
    proteinG: 15,
    fatCapG: 10,
    fluidsMl: 500,
  ),
  duringRun: const DuringRunMacros(
    carbRateGPerH: 52.5,
    carbTotalG: 90,
    fluidRateMlPerH: 700,
    fluidTotalMl: 1500,
    sodiumRateMgPerH: 550,
    sodiumTotalMg: 1200,
    massNormRateGPerH: 0.7,
  ),
  postRun: const PostRunMacros(
    carbsG: 70,
    proteinG: 25,
    fluidsMl: 900,
    sodiumMg: 800,
  ),
  metrics: const RunMetrics(
    distanceMi: 30,
    distanceKm: 48,
    durationH: 1.75,
    durationMin: 105,
    speedMph: 17,
    caloriesGrossKcal: 1100,
    caloriesNetKcal: 900,
    met: 8,
  ),
  calculationRule: 'v4',
  timestamp: DateTime(2026, 9, 1),
  isUserModified: false,
  brickSegments: const [
    BrickSegment(
      sport: 'cycling',
      order: 1,
      durationMinutes: 60,
      intensity: 'moderate',
    ),
    BrickSegment(
      sport: 'running',
      order: 2,
      durationMinutes: 45,
      intensity: 'moderate',
    ),
  ],
  brickPhaseTargets: BrickPhaseTargets(
    duringSegments: const [],
    transitions: [
      BrickTransitionMacroTarget(
        transitionName: 'T1',
        carbsG: doseG,
        carbsLowG: 0,
        carbsHighG: 30,
        sodiumMg: 248,
        waterMl: 300,
        sodiumConcMgPerL: 825,
        carbsRateGPerH: 52.5,
        effectiveGapMin: 33,
        transitionMin: 3,
        sportPair: 'cycling→running',
      ),
    ],
  ),
);

void main() {
  const service = MacroExplanationService();

  group('TC-1 — positional title on a bike→run brick (the D-008 order)', () {
    testWidgets('the single gap renders TRANSITION 1 with its subtitle', (
      tester,
    ) async {
      final brick = Activity(
        id: 'b1',
        userId: 'u1',
        title: 'Brick',
        activityType: ActivityType.brick,
        scheduledDateTime: DateTime(2026, 9, 1, 8),
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      const plan = NutritionPlan(
        id: 'p1',
        name: 'Brick plan',
        sections: [
          PlanSection(
            id: 'T1',
            title: 'Transition (T1)',
            subtitle: 'Quick refuel between segments',
            foodItems: [],
            carbsTarget: 29,
            carbsLowTarget: 0,
            carbsHighTarget: 30,
            sodiumTarget: 248,
            fluidsTarget: 300,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BrickNutritionSections(
                brick: brick,
                planData: plan,
                macroTargets: bikeRunMacroTargets(),
                onAddFood: (_) {},
                onSwapFood: (_, _, _) {},
                onDeleteFood: (_, _) {},
                onUpdateQuantity: (_, _, _) {},
              ),
            ),
          ),
        ),
      );
      // TC-1: positional, never sport-pair; uppercased on the card.
      expect(find.text('TRANSITION 1'), findsOneWidget);
      expect(find.text('Quick refuel between segments'), findsOneWidget);
      expect(find.textContaining('BIKE→RUN'), findsNothing);
    });
  });

  group('TC-2 — stat trio on the transition card', () {
    Future<void> pumpRow(WidgetTester tester) async {
      const section = PlanSection(
        id: 'T1',
        title: 'Transition (T1)',
        foodItems: [],
        carbsTarget: 29,
        carbsLowTarget: 0,
        carbsHighTarget: 30,
        sodiumTarget: 248,
        fluidsTarget: 300,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: MacroSummaryRow(
              foods: [],
              section: section,
              category: 'transition',
              carbsLow: 0,
              carbsHigh: 30,
            ),
          ),
        ),
      );
    }

    testWidgets('CARBS · FLUIDS · SODIUM — protein dropped', (tester) async {
      await pumpRow(tester);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FLUIDS'), findsOneWidget);
      expect(find.text('SODIUM'), findsOneWidget);
      expect(find.text('PROTEIN'), findsNothing);
    });

    testWidgets('carbs renders delivered/target over the [0,30] band rail', (
      tester,
    ) async {
      await pumpRow(tester);
      // Delivered/target pair (RichText: '0' + '/29g').
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '0/29g',
        ),
        findsOneWidget,
        reason: 'TC-2: the only stat with a target renders delivered/target',
      );
      // Band rail end labels.
      expect(find.text('0'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('fluids and sodium are plain tallies — no /target half', (
      tester,
    ) async {
      await pumpRow(tester);
      // Delivered-only figures (empty plate ⇒ 0), never paired with the
      // as-built 300 mL / 248 mg pseudo-targets.
      expect(find.text('0mL'), findsOneWidget);
      expect(find.text('0mg'), findsOneWidget);
      expect(find.textContaining('/300'), findsNothing);
      expect(find.textContaining('/248'), findsNothing);
    });
  });

  group('TC-4 — drawer numbers equal the ratified math', () {
    test('carb section carries the T-1 formula with engine numbers', () {
      final data = service.getCarbTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: bikeRunMacroTargets(),
        bodyWeightKg: 72,
        gutTrainingLabel: 'MODERATE',
        gutMultiplier: 1.0,
        isBrick: true,
      );
      expect(data.targetGrams, 29);
      expect(data.rangeLow, 0);
      expect(data.rangeHigh, 30);
      final formula = data.tldrLines
          .map((l) => l.segments.map((s) => s.text).join())
          .join('\n');
      expect(formula, contains('52.5 g/h'));
      expect(formula, contains('33 min'));
      expect(formula, contains('clamp [0, 30]'));
      expect(formula, contains('29g'));
    });

    test('fluid section: delivered-only, no target, no formula', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: bikeRunMacroTargets(),
        bodyWeightKg: 72,
      )![Scenario.t1t2]!;
      expect(data.targetGrams, isNull, reason: 'T-5: tally, never a target');
      expect(data.tldrLines, isEmpty, reason: 'no formula implying a target');
      expect(data.calculationSections, isEmpty);
      expect(data.tldrBody, contains('no transition-specific fluid target'));
    });

    test('sodium section: delivered-only, no target, no formula', () {
      final data = service.getSodiumTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: bikeRunMacroTargets(),
        bodyWeightKg: 72,
      )![Scenario.t1t2]!;
      expect(data.targetGrams, isNull, reason: 'T-5: tally, never a target');
      expect(data.tldrLines, isEmpty, reason: 'no formula implying a target');
      expect(data.calculationSections, isEmpty);
      expect(data.tldrBody, contains('no transition-specific sodium target'));
    });
  });

  group('TC-5 — copy register', () {
    test('no swim/wetsuit references anywhere on a bike→run brick', () {
      final targets = bikeRunMacroTargets();
      final texts = <String>[];
      final carb = service.getCarbTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: targets,
        bodyWeightKg: 72,
        gutTrainingLabel: 'MODERATE',
        gutMultiplier: 1.0,
        isBrick: true,
      );
      final fluid = service.getFluidTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: targets,
        bodyWeightKg: 72,
      )![Scenario.t1t2]!;
      final sodium = service.getSodiumTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: targets,
        bodyWeightKg: 72,
      )![Scenario.t1t2]!;
      for (final d in [carb, fluid, sodium]) {
        texts.add(d.tldrBody ?? '');
        for (final s in d.storySections) {
          texts.add('${s.question} ${s.answer}');
        }
      }
      final all = texts.join('\n').toLowerCase();
      expect(all, isNot(contains('swim')), reason: 'F-D fixed');
      expect(all, isNot(contains('wetsuit')), reason: 'F-D fixed');
    });

    test('carb copy is sport-pair-aware and agrees with a nonzero target', () {
      final data = service.getCarbTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: bikeRunMacroTargets(),
        bodyWeightKg: 72,
        gutTrainingLabel: 'MODERATE',
        gutMultiplier: 1.0,
        isBrick: true,
      );
      expect(data.tldrBody, contains('between the bike and run segments'));
      expect(
        data.tldrBody,
        contains('quick-digesting carbs'),
        reason: 'F-C: the cue stands when the target is nonzero',
      );
    });

    test('a 0 g dose gets honest copy, not a fuelling cue (F-C)', () {
      final data = service.getCarbTransparencyData(
        phase: ExplanationPhase.transition1,
        macroTargets: bikeRunMacroTargets(doseG: 0),
        bodyWeightKg: 72,
        gutTrainingLabel: 'MODERATE',
        gutMultiplier: 1.0,
        isBrick: true,
      );
      expect(data.tldrBody, contains('0 g is a legitimate dose'));
      expect(data.tldrBody, isNot(contains('quick-digesting carbs')));
    });
  });
}
