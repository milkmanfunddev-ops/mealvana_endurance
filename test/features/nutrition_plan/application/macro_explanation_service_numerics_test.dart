// Numeric regression tests for the fluid & sodium transparency services.
//
// These complement `macro_explanation_service_test.dart` (which only asserts
// scenario-map shape and copy routing) by locking in the numeric field
// contracts that drive the Calculation / TL;DR / Full Story rendering:
//
//   • mL → oz conversion for targetGrams / rangeLow / rangeHigh (G7 U1)
//   • ConfidenceLevel.high/medium/low propagation to the right Qs
//   • During-sodium sports-drink comparison chip (C25)
//   • Salt-type Q with percentile annotations in chips (C23)
//   • Blue inherited-note `footerNote` on during-sodium FLOOR & CEILING (C21)
//   • Redistribution purple-variant `footerNote` on brick redistribution

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  final service = MacroExplanationService();

  group('Fluid transparency — mL → oz conversion (G7 U1)', () {
    test('useImperial=false leaves mL values untouched', () {
      final targets = _sampleTargets(durationH: 1.5);
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.during,
        macroTargets: targets,
        bodyWeightKg: 70,
      )![Scenario.singleSport]!;
      expect(
        data.targetGrams,
        closeTo(750.0, 0.5),
        reason: '1.5h × 500 mL/hr = 750 mL',
      );
      expect(data.primaryUnit, 'mL/hr');
    });

    test(
      'useImperial=true pre-converts targetGrams / rangeLow / rangeHigh',
      () {
        final targets = _sampleTargets(durationH: 1.5);
        final data = service.getFluidTransparencyData(
          phase: ExplanationPhase.during,
          macroTargets: targets,
          bodyWeightKg: 70,
          useImperial: true,
        )![Scenario.singleSport]!;
        // 750 mL × 0.033814 = ~25 oz (values are whole-number rounded)
        expect(
          data.targetGrams,
          closeTo(25.0, 1.0),
          reason: 'mL pre-converted to oz',
        );
        expect(data.primaryUnit, 'oz/hr');
      },
    );

    test('pre-workout fluid target converts symmetrically', () {
      final targets = _sampleTargets(durationH: 1.5, preFluidsMl: 420);
      final imperial = service.getFluidTransparencyData(
        phase: ExplanationPhase.before,
        macroTargets: targets,
        bodyWeightKg: 70,
        useImperial: true,
      )![Scenario.singleSport]!;
      expect(
        imperial.targetGrams,
        closeTo(14.0, 1.0),
        reason: '420 mL × 0.033814 ≈ 14 oz',
      );
    });
  });

  group('Fluid transparency — ConfidenceLevel propagation (G4)', () {
    test('during-fluid story sections have HIGH on sweat-rate + EAH Qs', () {
      final data = service.getFluidTransparencyData(
        phase: ExplanationPhase.during,
        macroTargets: _sampleTargets(durationH: 2.0),
        bodyWeightKg: 70,
      )![Scenario.singleSport]!;

      final highs = data.storySections
          .where((s) => s.confidence == ConfidenceLevel.high)
          .toList();
      expect(
        highs,
        isNotEmpty,
        reason: 'at least sweat-rate, EAH, and warning Qs are HIGH',
      );

      final eah = data.storySections.firstWhere(
        (s) => s.question.contains('too much water'),
      );
      expect(
        eah.confidence,
        ConfidenceLevel.high,
        reason: 'EAH/hyponatremia Q is safety-critical HIGH confidence',
      );
    });

    test(
      'humidity and indoor Qs carry transparencyNote + MEDIUM/LOW pills',
      () {
        final data = service.getFluidTransparencyData(
          phase: ExplanationPhase.during,
          macroTargets: _sampleTargets(durationH: 2.0),
          bodyWeightKg: 70,
        )![Scenario.singleSport]!;

        final humidity = data.storySections.firstWhere(
          (s) => s.question.contains('humidity'),
        );
        expect(
          humidity.transparencyNote,
          isNotNull,
          reason: 'humidity Q has transparencyNote about Mealvana estimate',
        );
        expect(humidity.confidence, ConfidenceLevel.medium);

        final indoor = data.storySections.firstWhere(
          (s) => s.question.contains('indoors'),
        );
        expect(
          indoor.transparencyNote,
          isNotNull,
          reason: 'indoor Q has transparencyNote about unquantified 1.30×',
        );
        expect(indoor.confidence, ConfidenceLevel.low);
      },
    );
  });

  group('Sodium transparency — during-workout spec parity', () {
    test('sodium rate × duration round-trip matches sodiumTotalMg', () {
      final targets = _sampleTargets(durationH: 1.5);
      final data = service.getSodiumTransparencyData(
        bodyWeightKg: 70,
        phase: ExplanationPhase.during,
        macroTargets: targets,
      )![Scenario.singleSport]!;
      // 600 mg/hr × 1.5 hr = 900 mg total (set on the fixture).
      expect(data.targetGrams, 900.0, reason: 'sodium total = rate × duration');
    });

    test('salt-type Q chips carry percentile annotations (C23)', () {
      final data = service.getSodiumTransparencyData(
        bodyWeightKg: 70,
        phase: ExplanationPhase.during,
        macroTargets: _sampleTargets(durationH: 2.0),
      )![Scenario.singleSport]!;

      final saltQ = data.storySections.firstWhere(
        (s) => s.question.contains('sweat sodium concentration'),
      );
      expect(saltQ.dataChips.any((c) => c.contains('25th pct')), isTrue);
      expect(saltQ.dataChips.any((c) => c.contains('50th pct')), isTrue);
      expect(saltQ.dataChips.any((c) => c.contains('75th pct')), isTrue);
    });

    test('"Why isn\'t a standard sports drink enough?" Q is present (C25)', () {
      final data = service.getSodiumTransparencyData(
        bodyWeightKg: 70,
        phase: ExplanationPhase.during,
        macroTargets: _sampleTargets(durationH: 2.0),
      )![Scenario.singleSport]!;

      final standardDrinkQ = data.storySections.firstWhere(
        (s) => s.question.contains('standard sports drink'),
        orElse: () => const StorySection(question: 'MISSING', answer: ''),
      );
      expect(
        standardDrinkQ.question,
        isNot('MISSING'),
        reason: 'spec\'s most actionable sodium Q must be present',
      );
      expect(
        standardDrinkQ.dataChips,
        isNotEmpty,
        reason: 'comparison chips showing % of target coverage',
      );
      expect(
        standardDrinkQ.answer,
        contains('54%'),
        reason: 'spec callout: standard drink delivers ~54% of target',
      );
    });

    test('salt-type indicators Q has 4 qualitative bullets (C24)', () {
      final data = service.getSodiumTransparencyData(
        bodyWeightKg: 70,
        phase: ExplanationPhase.during,
        macroTargets: _sampleTargets(durationH: 2.0),
      )![Scenario.singleSport]!;

      final indicatorQ = data.storySections.firstWhere(
        (s) => s.question.contains('which type I am'),
      );
      // Spec lists 4 qualitative indicators.
      expect(indicatorQ.answer, contains('White salt residue'));
      expect(indicatorQ.answer, contains('Eyes sting'));
      expect(indicatorQ.answer, contains('craving for salty food'));
      expect(indicatorQ.answer, contains('Sweat tastes'));
      expect(indicatorQ.confidence, ConfidenceLevel.medium);
    });

    test('FLOOR & CEILING section has blue info footerNote (C21)', () {
      final data = service.getSodiumTransparencyData(
        bodyWeightKg: 70,
        phase: ExplanationPhase.during,
        macroTargets: _sampleTargetsWithDerivation(),
      )![Scenario.singleSport]!;

      final floorCeil = data.calculationSections.firstWhere(
        (s) => s.header == 'FLOOR & CEILING',
        orElse: () => const CalculationSection(header: 'MISSING', lines: []),
      );
      expect(floorCeil.header, 'FLOOR & CEILING');
      expect(
        floorCeil.footerNote,
        isNotNull,
        reason: 'inherited-note prose below floor/ceiling',
      );
      expect(floorCeil.footerNote, contains('Fluids section'));
      expect(
        floorCeil.footerNoteVariant,
        CalcNoteVariant.info,
        reason: 'blue info variant per Figma',
      );
    });
  });

  // Sodium v3 replaced the C9–C12 pre-sodium question set wholesale. There is
  // no target, so the Qs that explained one (C9's kidney-excretion framing
  // attached to a 450 mg dose, C10's "where does 300–600 mg come from", C12's
  // sodium-loading distinction) went with it. What replaces them has to carry
  // more weight, not less: a deleted number with no explanation reads to the
  // athlete as a bug.
  // SSOT: docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md §3.
  group('Pre-sodium Full Story — sodium v3', () {
    NutrientTransparencyData preSodium() => service.getSodiumTransparencyData(
      bodyWeightKg: 70,
      phase: ExplanationPhase.before,
      // A delivered figure may still be threaded through — it is an
      // observation, never a target.
      macroTargets: _sampleTargets(durationH: 1.5, preSodiumMg: 450),
    )![Scenario.singleSport]!;

    test('the card sets no target and no band', () {
      final data = preSodium();
      expect(data.targetGrams, isNull);
      expect(data.rangeLow, isNull);
      expect(data.rangeHigh, isNull);
      expect(data.tldrLines, isEmpty);
      expect(data.calculationSections, isEmpty);
    });

    test('all three v3 questions are present', () {
      final questions = preSodium().storySections
          .map((s) => s.question)
          .toList();
      expect(questions, contains('Why is there no pre-workout sodium target?'));
      expect(questions, contains('Does sodium still help before a workout?'));
      expect(
        questions,
        contains('Then what is the sodium number on this screen?'),
      );
    });

    test('the removal is explained and cited, not silently absent', () {
      final removal = preSodium().storySections.firstWhere(
        (s) => s.question.contains('no pre-workout sodium target'),
        orElse: () => const StorySection(question: 'MISSING', answer: ''),
      );
      expect(removal.question, isNot('MISSING'));
      // D-007: the retired band only held for ~65–163 kg, so it silently
      // over-concentrated every lighter athlete.
      expect(removal.answer, contains('65 kg'));
      expect(removal.answer, contains('163 kg'));
      expect(
        removal.answer,
        contains('during-workout plan'),
        reason: 'sodium individualisation moved, it did not disappear',
      );
      expect(removal.citation, contains('Sawka'));
      expect(removal.confidence, ConfidenceLevel.high);
    });

    test('the retention effect is kept qualitatively and never quantified', () {
      final retention = preSodium().storySections.firstWhere(
        (s) => s.question.contains('Does sodium still help'),
        orElse: () => const StorySection(question: 'MISSING', answer: ''),
      );
      expect(retention.question, isNot('MISSING'));
      // The mechanism survives — it is the number attached to it that does not.
      expect(retention.answer, contains('excreted'));
      expect(
        retention.answer,
        isNot(matches(RegExp(r'\d'))),
        reason:
            'the retention studies used 77 mmol/L, several times a sports '
            'drink, so the effect must never be given a number to aim at',
      );
      expect(retention.citation, contains('Maughan'));
    });

    test('the surviving figure is framed as an observation, not a goal', () {
      final observed = preSodium().storySections.firstWhere(
        (s) => s.question.contains('what is the sodium number'),
        orElse: () => const StorySection(question: 'MISSING', answer: ''),
      );
      expect(observed.question, isNot('MISSING'));
      expect(observed.answer, contains('observation, not a goal'));
      expect(observed.answer, contains('no range'));
    });

    test('the retired v1 questions are gone', () {
      final questions = preSodium().storySections
          .map((s) => s.question)
          .toList();
      expect(questions, isNot(contains('How does sodium help retain fluid?')));
      expect(questions, isNot(contains('Where does 300–600 mg come from?')));
      expect(
        questions.any((q) => q.contains('sodium loading')),
        isFalse,
        reason:
            'the loading distinction explained a target that no longer '
            'exists; if copy wants it back it needs re-deriving under v3',
      );
    });
  });
}

MacroTargets _sampleTargets({
  required double durationH,
  bool isTested = false,
  double? tempC,
  double preFluidsMl = 300,
  double preSodiumMg = 400,
}) {
  final durationMin = durationH * 60;
  return MacroTargets(
    id: 'sample',
    activityType: ActivityType.running,
    preRun: PreRunMacros(
      carbsG: 40,
      proteinG: 20,
      fatCapG: 10,
      fluidsMl: preFluidsMl,
      sodiumMg: preSodiumMg,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: 70,
      carbTotalG: 70 * durationH,
      fluidRateMlPerH: 500,
      fluidTotalMl: (500 * durationH).round().toDouble(),
      sodiumRateMgPerH: 600,
      sodiumTotalMg: (600 * durationH).round().toDouble(),
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: const [60, 90],
      isTested: isTested,
      tempC: tempC,
    ),
    postRun: const PostRunMacros(
      carbsG: 60,
      proteinG: 25,
      fluidsMl: 400,
      sodiumMg: 500,
    ),
    metrics: RunMetrics(
      distanceMi: 20,
      distanceKm: 32,
      durationH: durationH,
      durationMin: durationMin,
      paceMinPerMile: 7.75,
      speedMph: 7.7,
      caloriesGrossKcal: 1000,
      caloriesNetKcal: 900,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 1, 1),
    isUserModified: false,
  );
}

MacroTargets _sampleTargetsWithDerivation() {
  final base = _sampleTargets(durationH: 1.5);
  return base.copyWith(
    duringRun: base.duringRun.copyWith(
      effectiveSweatRateLPerH: 1.28,
      sodiumConcMgPerL: 825,
      replacementPercent: 0.60,
      floorMlPerH: 420,
      ceilingMlPerH: 800,
    ),
  );
}
