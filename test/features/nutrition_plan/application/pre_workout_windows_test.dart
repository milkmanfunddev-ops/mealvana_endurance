// Verifies pre-workout fluid + sodium transparency data renders the right
// copy / formula / calculation for each of the four observable states:
//
//   1. Gate fired       — short, mild workout: no plan needed
//   2. Too late          — < 10 min before workout, fluidsMl = 0
//   3. Short window      — 10–120 min before, fixed top-up
//   4. Full protocol     — ≥ 120 min before, body-weight-scaled
//
// Spec: docs/features/sodium_hydration/transparency_pre_hydration.md
//       docs/features/sodium_hydration/transparency_pre_sodium.md

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  const service = MacroExplanationService();
  const bodyWeightKg = 65.0;

  // ── Gate-fired ────────────────────────────────────────────────────────────
  group('Pre-workout — gate fired (short, mild workout)', () {
    final targets = _preTargets(
      fluidsMl: 0,
      sodiumMg: 0,
      carbsG: 0,
      durationMin: 45,
      tempC: 22,
    );

    test('fluid blurb says no plan needed, not "too late"', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrBody, isNotNull);
      expect(data.tldrBody, contains('No structured pre-hydration needed'));
      expect(data.tldrBody, isNot(contains('Too late')));
      expect(data.tldrLines, isEmpty);
      expect(data.tldrTip, isNull, reason: 'urine tip is full-protocol-only');
    });

    test('sodium blurb references gate, not the standard retention copy', () {
      final data = service.getSodiumTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrBody, contains('No structured pre-hydration sodium'));
      expect(data.tldrLines, isEmpty);
    });

    test('fluid calc accordion shows gate condition, not "<10 min"', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final flat = _flattenFormula(data.calculationSections);
      expect(flat, contains('workout < 60 min'));
      expect(flat, contains('temp < 30'));
      expect(flat, isNot(contains('< 10 min pre-start')));
    });
  });

  // ── Too late (< 10 min before workout) ────────────────────────────────────
  group('Pre-workout — too late (< 10 min before workout)', () {
    // Long hot workout + 0 ml fluid → not the gate, must be too-late case.
    final targets = _preTargets(
      fluidsMl: 0,
      sodiumMg: 0,
      carbsG: 0,
      durationMin: 180,
      tempC: 32,
    );

    test('fluid blurb says "Too late" and points to during-workout', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrBody, contains('Too late for structured pre-hydration'));
      expect(data.tldrBody, contains('during-workout plan'));
      expect(data.tldrLines, isEmpty);
      expect(data.tldrTip, isNull);
    });

    test('fluid calc accordion shows < 10 min, not gate language', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final flat = _flattenFormula(data.calculationSections);
      expect(flat, contains('< 10 min pre-start'));
      expect(flat, isNot(contains('workout < 60 min')));
    });

    test('Full Story skips "Where does 5–7 ml/kg come from?" Q', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final questions = data.storySections.map((s) => s.question).toList();
      expect(
        questions.any((q) => q.contains('Where does 5')),
        isFalse,
        reason:
            'body-weight-scaled Q is irrelevant when no protocol is delivered',
      );
    });
  });

  // ── Short window (10–120 min) ─────────────────────────────────────────────
  group('Pre-workout — short window (10–120 min)', () {
    // ~30 minutes before workout: carbs ≈ 0.5 g/kg → 32g for 65kg.
    // Fluid = 250 ml fixed, sodium = 150 mg fixed per spec.
    final targets = _preTargets(
      fluidsMl: 250,
      fluidsLowMl: 200,
      fluidsHighMl: 300,
      sodiumMg: 150,
      sodiumLowMg: 100,
      sodiumHighMg: 200,
      carbsG: 33,
      durationMin: 90,
      tempC: 22,
    );

    test('fluid blurb uses spec wording for the short window', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrBody, contains('Not enough time for the full protocol'));
      expect(data.tldrBody, contains('250 mL'));
    });

    test('fluid formula shows "10–120 min window" not "Tier 2"', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final flat =
          _flattenFormula(data.calculationSections) +
          _flattenLines(data.tldrLines);
      expect(flat, contains('10–120 min window'));
      expect(flat.toLowerCase(), isNot(contains('tier')));
    });

    test(
      'sodium formula shows "10–120 min window" with the right midpoint',
      () {
        final data = service.getSodiumTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: targets,
          bodyWeightKg: bodyWeightKg,
        )![Scenario.singleSport]!;

        final flat = _flattenLines(data.tldrLines);
        expect(flat, contains('10–120 min window'));
        expect(flat, contains('150 mg'));
        expect(flat, contains('100–200 mg'));
      },
    );

    test('no urine tip in the short window', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrTip, isNull);
    });
  });

  // ── Full protocol (≥ 120 min) ─────────────────────────────────────────────
  group('Pre-workout — full protocol (≥ 2 hr)', () {
    // 3 hours before, 65 kg athlete → 195 g carbs, 390 ml fluid, 450 mg
    // sodium per the algorithm.
    final targets = _preTargets(
      fluidsMl: 390,
      fluidsLowMl: 325,
      fluidsHighMl: 455,
      sodiumMg: 450,
      sodiumLowMg: 300,
      sodiumHighMg: 600,
      carbsG: 195, // 3 hr × 65 kg × 1 g/kg/hr
      durationMin: 120,
      tempC: 22,
    );

    test('fluid blurb mentions the back-derived hours and target ml', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrBody, contains('euhydrated'));
      expect(data.tldrBody, contains('390 mL'));
      // hoursBefore is clamped at 4.0; for 195g/65kg = 3.0 hours.
      expect(data.tldrBody, contains('3 hours available'));
      expect(data.tldrBody, contains('full protocol'));
    });

    test('fluid formula uses the inline kg × ml/kg form', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final flat = _flattenLines(data.tldrLines);
      expect(flat, contains('65 kg'));
      expect(flat, contains('6 ml/kg'));
      expect(flat, contains('390 mL'));
      expect(flat, contains('floor'));
      expect(flat, contains('325 mL'));
      expect(flat, contains('ceiling'));
      expect(flat, contains('455 mL'));
      expect(flat, contains('325–455 mL'));
    });

    test('urine tip is present', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      expect(data.tldrTip, isNotNull);
      expect(data.tldrTip, contains('pale yellow'));
      expect(data.tldrTip, contains('3–5 ml/kg'));
    });

    test('sodium formula uses "≥ 2 hr window" with 450 mg midpoint', () {
      final data = service.getSodiumTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final flat = _flattenLines(data.tldrLines);
      expect(flat, contains('≥ 2 hr window'));
      expect(flat, contains('450 mg'));
      expect(flat, contains('300–600 mg'));
      expect(flat, contains('sipped with fluid'));
    });

    test('Full Story includes all four hydration Qs', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final questions = data.storySections.map((s) => s.question).toList();
      expect(
        questions,
        contains('What is euhydration and why does it matter?'),
      );
      expect(questions, contains('Where does 5–7 ml/kg come from?'));
      expect(
        questions,
        contains('Why does the recommendation change with time available?'),
      );
      expect(questions, contains('What about early morning workouts?'));
    });

    test('Full Story includes all four sodium Qs', () {
      final data = service.getSodiumTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: bodyWeightKg,
      )![Scenario.singleSport]!;

      final questions = data.storySections.map((s) => s.question).toList();
      expect(questions, contains('How does sodium help retain fluid?'));
      expect(questions, contains('Where does 300–600 mg come from?'));
      expect(
        questions.any((q) => q.contains("isn't sodium scaled to body weight")),
        isTrue,
      );
      expect(questions, contains('Is this the same as sodium loading?'));
    });
  });

  // ── No "Tier" terminology leaks anywhere user-facing ─────────────────────
  group('Pre-workout — no internal tier terminology in any window', () {
    for (final sample in [
      _preTargets(
        fluidsMl: 0,
        sodiumMg: 0,
        carbsG: 0,
        durationMin: 45,
        tempC: 20,
      ),
      _preTargets(
        fluidsMl: 250,
        sodiumMg: 150,
        carbsG: 33,
        durationMin: 90,
        tempC: 25,
      ),
      _preTargets(
        fluidsMl: 390,
        sodiumMg: 450,
        carbsG: 195,
        durationMin: 120,
        tempC: 25,
      ),
    ]) {
      test('fluid + sodium copy free of "Tier 1/2/3" '
          '(fluidsMl=${sample.preRun.fluidsMl})', () {
        final fluid = service.getFluidTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: sample,
          bodyWeightKg: bodyWeightKg,
        )![Scenario.singleSport]!;
        final sodium = service.getSodiumTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: sample,
          bodyWeightKg: bodyWeightKg,
        )![Scenario.singleSport]!;

        for (final data in [fluid, sodium]) {
          final allText = [
            data.tldrBody ?? '',
            for (final line in data.tldrLines)
              for (final seg in line.segments) seg.text,
            for (final s in data.storySections) s.question,
            for (final s in data.storySections) s.answer,
            for (final s in data.calculationSections) s.header,
            for (final s in data.calculationSections)
              for (final line in s.lines)
                for (final seg in line.segments) seg.text,
          ].join(' ').toLowerCase();
          expect(allText, isNot(contains('tier 1')));
          expect(allText, isNot(contains('tier 2')));
          expect(allText, isNot(contains('tier 3')));
          expect(allText, isNot(contains('pre-workout tier')));
        }
      });
    }
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

MacroTargets _preTargets({
  required double fluidsMl,
  required double sodiumMg,
  required double carbsG,
  required double durationMin,
  required double tempC,
  double? fluidsLowMl,
  double? fluidsHighMl,
  double? sodiumLowMg,
  double? sodiumHighMg,
}) {
  final durationH = durationMin / 60.0;
  return MacroTargets(
    id: 'sample',
    activityType: ActivityType.running,
    preRun: PreRunMacros(
      carbsG: carbsG,
      proteinG: 20,
      fatCapG: 10,
      fluidsMl: fluidsMl,
      sodiumMg: sodiumMg,
      fluidsLowMl: fluidsLowMl,
      fluidsHighMl: fluidsHighMl,
      sodiumLowMg: sodiumLowMg,
      sodiumHighMg: sodiumHighMg,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: 70,
      carbTotalG: 70 * durationH,
      fluidRateMlPerH: 500,
      fluidTotalMl: 500 * durationH,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 600 * durationH,
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: const [60, 90],
      carbsLowG: 60 * durationH,
      carbsHighG: 90 * durationH,
      rawBandLowGPerH: 60,
      rawBandHighGPerH: 90,
      gutMultiplier: 1.0,
      sportCeilingGPerH: 70,
      isTested: false,
      tempC: tempC,
    ),
    postRun: const PostRunMacros(
      carbsG: 60,
      proteinG: 25,
      fluidsMl: 400,
      sodiumMg: 500,
    ),
    metrics: RunMetrics(
      distanceMi: 6.0,
      distanceKm: 10.0,
      durationH: durationH,
      durationMin: durationMin,
      paceMinPerMile: 8.0,
      speedMph: 7.5,
      caloriesGrossKcal: 800,
      caloriesNetKcal: 700,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 1, 1),
    isUserModified: false,
  );
}

String _flattenLines(List<FormulaLine> lines) {
  return lines.expand((l) => l.segments.map((s) => s.text)).join('');
}

String _flattenFormula(List<CalculationSection> sections) {
  return sections
      .expand((s) => s.lines)
      .expand((l) => l.segments.map((s) => s.text))
      .join('');
}
