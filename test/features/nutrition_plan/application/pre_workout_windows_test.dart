// Verifies pre-workout fluid + sodium transparency data renders the right
// copy / formula / calculation for each observable state.
//
// The states are now named by the hydration v6 regime rather than an integer
// tier (PW-013):
//
//   1. Gate fired   — `gated`: short, mild session; NO target is set at all
//   2. Too late     — legacy plans with no regime and 0 ml; nothing absorbs now
//   3. Short window — `extrapolated` / `clearance_bound`: sub-2 h partial dose
//   4. Full protocol— `cited`: >= 2 h, body-weight-scaled
//
// (The former state 5, fasted, is retired with the fasted product state —
// food-recommendation §7 / D-001, Xuan 2026-09-03.)
//
// States 1 and 2 both show "nothing" and MUST NOT read alike — see the
// `two ways of showing nothing` group, which is the only thing keeping that
// true.
//
// Sodium is **v3**: Mealvana sets no pre-workout sodium target. There is no
// 450 mg midpoint, no 300–600 mg band, no 150 mg tier-2 figure and no formula
// lines. The assertions below state that positively rather than by omission.
//
// Spec: docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md §1 (hydration v6), §3 (sodium v3)

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  const service = MacroExplanationService();
  const bodyWeightKg = 65.0;

  // Engine-real v6 output for a 65 kg athlete, so the cards are exercised with
  // the numbers they will actually receive.
  //   t = 180 (cited):       487.5 ml, band [325, 780]   → display 500, [325, 800]
  //   t =  90 (extrapolated): 428.125 ml, band [0, 650]  → display 425, [0, 650]
  // Display rounding lives in the card: round25 on the target, floor25/ceil25
  // on the band.

  // ── 1. Gate fired ─────────────────────────────────────────────────────────
  group('Pre-workout — gate fired (short, mild workout)', () {
    final targets = _preTargets(
      fluidsMl: 0,
      carbsG: 0,
      durationMin: 45,
      tempC: 22,
      hydrationRegime: PreRunHydrationRegime.gated,
      fluidTargetBasis: PreRunTargetBasis.none,
    );

    test('fluid blurb says no plan needed, not "too late"', () {
      final data = _fluid(service, targets, bodyWeightKg);

      expect(data.tldrBody, isNotNull);
      expect(data.tldrBody, contains('No structured pre-hydration needed'));
      expect(data.tldrBody, isNot(contains('Too late')));
      expect(data.tldrLines, isEmpty);
      expect(data.tldrTip, isNull, reason: 'urine tip is full-protocol-only');
    });

    test('sodium blurb says no plan either — and sets no target or band', () {
      final data = _sodium(service, targets, bodyWeightKg);

      expect(data.tldrBody, contains('no pre-workout hydration plan'));
      expect(data.tldrBody, contains('no sodium plan either'));
      _expectNoSodiumTargetOrBand(data);
    });

    test('fluid calc accordion shows gate condition, not "<10 min"', () {
      final flat = _flattenFormula(
        _fluid(service, targets, bodyWeightKg).calculationSections,
      );
      expect(flat, contains('workout < 60 min'));
      expect(flat, contains('temp < 30'));
      expect(flat, isNot(contains('< 10 min pre-start')));
    });
  });

  // ── 2. Too late (legacy plans: no regime, 0 ml) ───────────────────────────
  group('Pre-workout — too late (< 10 min before workout)', () {
    // No regime (a legacy cached plan) + long hot workout + 0 ml fluid → not
    // the gate, so the too-late branch. New plans carry a regime and reach this
    // branch only through `gated`; this fixture pins the back-compatibility
    // path deliberately.
    final targets = _preTargets(
      fluidsMl: 0,
      carbsG: 0,
      durationMin: 180,
      tempC: 32,
    );

    test('fluid blurb says "Too late" and points to during-workout', () {
      final data = _fluid(service, targets, bodyWeightKg);

      expect(data.tldrBody, contains('Too late for structured pre-hydration'));
      expect(data.tldrBody, contains('during-workout plan'));
      expect(data.tldrLines, isEmpty);
      expect(data.tldrTip, isNull);
    });

    test('fluid calc accordion shows < 10 min, not gate language', () {
      final flat = _flattenFormula(
        _fluid(service, targets, bodyWeightKg).calculationSections,
      );
      expect(flat, contains('< 10 min pre-start'));
      expect(flat, isNot(contains('workout < 60 min')));
    });

    test('Full Story skips the body-weight-scaled Q', () {
      final questions = _fluid(
        service,
        targets,
        bodyWeightKg,
      ).storySections.map((s) => s.question).toList();
      expect(
        questions.any((q) => q.contains('Where does 5')),
        isFalse,
        reason:
            'body-weight-scaled Q is irrelevant when no protocol is delivered',
      );
    });
  });

  // ── 3. Short window (extrapolated) ────────────────────────────────────────
  group('Pre-workout — short window (sub-2 h, extrapolated)', () {
    final targets = _preTargets(
      fluidsMl: 428.125,
      fluidsLowMl: 0,
      fluidsHighMl: 650,
      carbsG: 48.75,
      durationMin: 90,
      tempC: 22,
      hydrationRegime: PreRunHydrationRegime.extrapolated,
    );

    test(
      'fluid blurb uses the short-window wording and the rounded target',
      () {
        final data = _fluid(service, targets, bodyWeightKg);

        expect(
          data.tldrBody,
          contains('Not enough time for the full protocol'),
        );
        // round25(428.125) = 425 — the card rounds, the engine never does.
        expect(data.tldrBody, contains('425 mL'));
        expect(
          data.tldrBody,
          isNot(contains('428')),
          reason:
              'a raw engine value on screen reads as though it were measured',
        );
      },
    );

    test('fluid formula shows the window label, not "Tier 2"', () {
      final data = _fluid(service, targets, bodyWeightKg);
      final flat =
          _flattenFormula(data.calculationSections) +
          _flattenLines(data.tldrLines);
      expect(flat, contains('10–120 min window'));
      expect(flat.toLowerCase(), isNot(contains('tier')));
    });

    test('clearance_bound renders as the same short window', () {
      // A second regime maps to the same observable state; a card that
      // branched on only one of them would silently fall through to the full
      // protocol for an athlete standing on the start line.
      final clearanceTargets = _preTargets(
        fluidsMl: 312.5,
        fluidsLowMl: 0,
        fluidsHighMl: 890.216,
        carbsG: 16.25,
        durationMin: 90,
        tempC: 22,
        hydrationRegime: PreRunHydrationRegime.clearanceBound,
      );
      final data = _fluid(service, clearanceTargets, bodyWeightKg);
      expect(data.tldrBody, contains('Not enough time for the full protocol'));
      expect(_flattenLines(data.tldrLines), contains('10–120 min window'));
    });

    test('sodium sets no target and no band in the short window either', () {
      final data = _sodium(service, targets, bodyWeightKg);

      // v3: the retired figures must not come back in any form.
      final flat = _flattenLines(data.tldrLines);
      expect(flat, isEmpty, reason: 'there is no pre-workout sodium formula');
      expect(data.tldrBody, isNot(contains('150 mg')));
      expect(data.tldrBody, isNot(contains('100–200 mg')));
      _expectNoSodiumTargetOrBand(data);
    });

    test('no urine tip in the short window', () {
      expect(_fluid(service, targets, bodyWeightKg).tldrTip, isNull);
    });
  });

  // ── 4. Full protocol (cited) ──────────────────────────────────────────────
  group('Pre-workout — full protocol (cited, >= 2 h)', () {
    final targets = _preTargets(
      fluidsMl: 487.5, // 7.5 ml/kg
      fluidsLowMl: 325, // 5 ml/kg
      fluidsHighMl: 780, // 12 ml/kg
      carbsG: 195, // 3 h × 65 kg → back-derives "3 hours"
      durationMin: 120,
      tempC: 22,
      hydrationRegime: PreRunHydrationRegime.cited,
    );

    test('fluid blurb mentions the back-derived hours and rounded target', () {
      final data = _fluid(service, targets, bodyWeightKg);

      expect(data.tldrBody, contains('euhydrated'));
      // round25(487.5) = 500.
      expect(data.tldrBody, contains('500 mL'));
      expect(data.tldrBody, contains('3 hours available'));
      expect(data.tldrBody, contains('full protocol'));
    });

    test('fluid formula uses the inline kg × ml/kg form', () {
      final flat = _flattenLines(
        _fluid(service, targets, bodyWeightKg).tldrLines,
      );
      expect(flat, contains('65 kg'));
      expect(flat, contains('7.5 ml/kg'));
      expect(flat, contains('500 mL'));
      expect(flat, contains('floor'));
      expect(flat, contains('325 mL'));
      expect(flat, contains('ceiling'));
      expect(flat, contains('800 mL')); // ceil25(780)
      expect(flat, contains('325–800 mL'));
    });

    test('the band is read off the engine, not a restated constant', () {
      // The card used to hardcode 5–7 ml/kg, which under v6 quoted a ceiling
      // ~40 % below the engine's own. Assert the per-kg ends match the plan.
      final flat = _flattenLines(
        _fluid(service, targets, bodyWeightKg).tldrLines,
      );
      expect(flat, contains('(5 ml/kg)'));
      expect(flat, contains('(12 ml/kg)'));
      expect(flat, isNot(contains('5–7 ml/kg')));
      expect(
        flat,
        isNot(contains('7 ml/kg')),
        reason: 'the retired v1 ceiling must not reappear',
      );
    });

    test('urine tip is present', () {
      final data = _fluid(service, targets, bodyWeightKg);
      expect(data.tldrTip, isNotNull);
      expect(data.tldrTip, contains('pale yellow'));
      expect(data.tldrTip, contains('3–5 ml/kg'));
    });

    test('sodium states the v3 position: no target, no band, no formula', () {
      final data = _sodium(service, targets, bodyWeightKg);

      expect(data.tldrBody, contains('don\'t set a pre-workout sodium target'));
      expect(
        data.tldrBody,
        contains('what your food delivers'),
        reason: 'the surviving figure is an observation, not a goal',
      );
      _expectNoSodiumTargetOrBand(data);

      // The retired v1 numbers, in every form they appeared.
      final flat = _flattenLines(data.tldrLines);
      for (final retired in const [
        '450 mg',
        '300–600 mg',
        '150 mg',
        '100–200 mg',
        '≥ 2 hr window',
        'sipped with fluid',
      ]) {
        expect(flat, isNot(contains(retired)), reason: 'retired: $retired');
        expect(
          data.tldrBody,
          isNot(contains(retired)),
          reason: 'retired: $retired',
        );
      }
    });

    test('the qualitative retention copy is not quantified', () {
      // Digest §3: the retention studies used 77 mmol/L, three to seven times a
      // sports drink — so the effect is stated in words and never in a number.
      final data = _sodium(service, targets, bodyWeightKg);

      expect(
        data.tldrBody,
        isNot(matches(RegExp(r'\d'))),
        reason: 'the athlete-facing sodium summary must quantify nothing',
      );

      final retention = data.storySections.firstWhere(
        (s) => s.question.contains('Does sodium still help'),
        orElse: () => const StorySection(question: 'MISSING', answer: ''),
      );
      expect(retention.question, isNot('MISSING'));
      expect(retention.answer, contains('stay in your body'));
      expect(
        retention.answer,
        isNot(matches(RegExp(r'\d'))),
        reason: 'no number may attach to the retention claim',
      );
    });

    test('Full Story includes all four hydration Qs', () {
      final questions = _fluid(
        service,
        targets,
        bodyWeightKg,
      ).storySections.map((s) => s.question).toList();
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

    test('Full Story answers the three v3 sodium questions', () {
      final questions = _sodium(
        service,
        targets,
        bodyWeightKg,
      ).storySections.map((s) => s.question).toList();

      expect(questions, contains('Why is there no pre-workout sodium target?'));
      expect(questions, contains('Does sodium still help before a workout?'));
      expect(
        questions,
        contains('Then what is the sodium number on this screen?'),
      );
      // The v1 Qs rested on a target that no longer exists.
      expect(questions, isNot(contains('How does sodium help retain fluid?')));
      expect(questions, isNot(contains('Where does 300–600 mg come from?')));
    });

    test('the removal is explained, not silently absent', () {
      // A deleted target with no explanation reads as a bug to the athlete.
      final removalQ = _sodium(service, targets, bodyWeightKg).storySections
          .firstWhere(
            (s) => s.question.contains('no pre-workout sodium target'),
          );
      expect(removalQ.answer, contains('We used to set one'));
      expect(removalQ.answer, contains('during-workout plan'));
      expect(removalQ.citation, isNotNull);
    });
  });

  // ── The two ways of showing nothing ───────────────────────────────────────
  // (Narrowed from three: the fasted "no recommendation at all" state is
  // retired — food-recommendation §7 / D-001.)
  group('two ways of showing nothing must never read alike', () {
    // Digest §5 and sodium v3 both make this a hard requirement: a number that
    // is zero · no target set (gated).
    final realZero = _preTargets(
      fluidsMl: 487.5,
      fluidsLowMl: 325,
      fluidsHighMl: 780,
      sodiumMg: 0, // the food chosen simply delivers no sodium
      carbsG: 195,
      durationMin: 120,
      tempC: 22,
      hydrationRegime: PreRunHydrationRegime.cited,
    );
    final noTargetSet = _preTargets(
      fluidsMl: 0,
      carbsG: 0,
      durationMin: 45,
      tempC: 22,
      hydrationRegime: PreRunHydrationRegime.gated,
      fluidTargetBasis: PreRunTargetBasis.none,
    );
    test('the sodium card renders two distinct blurbs', () {
      final bodies = <String, String?>{
        'real zero': _sodium(service, realZero, bodyWeightKg).tldrBody,
        'no target set': _sodium(service, noTargetSet, bodyWeightKg).tldrBody,
      };

      for (final body in bodies.values) {
        expect(body, isNotNull);
        expect(body, isNotEmpty);
      }
      expect(
        bodies.values.toSet(),
        hasLength(2),
        reason:
            'a consumer that collapses these two misreports both of them: '
            '${bodies.entries.map((e) => '${e.key}=${e.value}').join(' | ')}',
      );
    });

    test('only the gated state claims there is no plan', () {
      expect(
        _sodium(service, noTargetSet, bodyWeightKg).tldrBody,
        contains('no sodium plan either'),
      );
      expect(
        _sodium(service, realZero, bodyWeightKg).tldrBody,
        isNot(contains('no sodium plan either')),
      );
    });

    test('the fluid card separates gated from too-late', () {
      final legacyTooLate = _preTargets(
        fluidsMl: 0,
        carbsG: 0,
        durationMin: 180,
        tempC: 32,
      );
      final gatedBody = _fluid(service, noTargetSet, bodyWeightKg).tldrBody;
      final tooLateBody = _fluid(service, legacyTooLate, bodyWeightKg).tldrBody;

      expect(gatedBody, isNot(tooLateBody));
      expect(gatedBody, contains('short and mild'));
      expect(tooLateBody, contains('Too late'));
    });

    test('neither of the two sets a sodium target or band', () {
      for (final targets in [realZero, noTargetSet]) {
        _expectNoSodiumTargetOrBand(_sodium(service, targets, bodyWeightKg));
      }
    });
  });

  // ── No internal terminology leaks anywhere user-facing ────────────────────
  group('Pre-workout — no internal terminology in any state', () {
    final samples = <String, MacroTargets>{
      'gated': _preTargets(
        fluidsMl: 0,
        carbsG: 0,
        durationMin: 45,
        tempC: 20,
        hydrationRegime: PreRunHydrationRegime.gated,
        fluidTargetBasis: PreRunTargetBasis.none,
      ),
      'extrapolated': _preTargets(
        fluidsMl: 428.125,
        fluidsLowMl: 0,
        fluidsHighMl: 650,
        carbsG: 48.75,
        durationMin: 90,
        tempC: 25,
        hydrationRegime: PreRunHydrationRegime.extrapolated,
      ),
      'clearance_bound': _preTargets(
        fluidsMl: 312.5,
        fluidsLowMl: 0,
        fluidsHighMl: 890.216,
        carbsG: 16.25,
        durationMin: 90,
        tempC: 25,
        hydrationRegime: PreRunHydrationRegime.clearanceBound,
      ),
      'cited': _preTargets(
        fluidsMl: 487.5,
        fluidsLowMl: 325,
        fluidsHighMl: 780,
        carbsG: 195,
        durationMin: 120,
        tempC: 25,
        hydrationRegime: PreRunHydrationRegime.cited,
      ),
    };

    samples.forEach((label, sample) {
      test('fluid + sodium copy is free of internal vocabulary ($label)', () {
        final cards = <NutrientTransparencyData>[
          _fluid(service, sample, bodyWeightKg),
          _sodium(service, sample, bodyWeightKg),
        ];

        for (final data in cards) {
          final allText = _allUserFacingText(data);

          // Guard against the whole check passing vacuously on empty copy —
          // an absent card would satisfy every `isNot(contains(...))` below.
          expect(
            allText.length,
            greaterThan(200),
            reason: '$label: no copy to check, so the check proves nothing',
          );

          // The retired integer tier.
          expect(allText, isNot(contains('tier 1')));
          expect(allText, isNot(contains('tier 2')));
          expect(allText, isNot(contains('tier 3')));
          expect(allText, isNot(contains('pre-workout tier')));

          // The regime strings that replaced it are just as internal. Matched
          // on word boundaries so ordinary prose ("excited", "elicited") can't
          // trip the check.
          for (final wire in const [
            'cited',
            'extrapolated',
            'clearance_bound',
            'clearance bound',
            'gated',
            'evidenced_band',
            'design_choice',
            'top_off',
          ]) {
            expect(
              allText,
              isNot(matches(RegExp('\\b${RegExp.escape(wire)}\\b'))),
              reason: '$label: wire value "$wire" leaked into athlete copy',
            );
          }
        }
      });
    });
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

NutrientTransparencyData _fluid(
  MacroExplanationService service,
  MacroTargets targets,
  double bodyWeightKg,
) {
  return service.getFluidTransparencyData(
    phase: ExplanationPhase.before,
    macroTargets: targets,
    bodyWeightKg: bodyWeightKg,
  )![Scenario.singleSport]!;
}

NutrientTransparencyData _sodium(
  MacroExplanationService service,
  MacroTargets targets,
  double bodyWeightKg,
) {
  return service.getSodiumTransparencyData(
    phase: ExplanationPhase.before,
    macroTargets: targets,
    bodyWeightKg: bodyWeightKg,
  )![Scenario.singleSport]!;
}

/// Sodium v3, asserted positively: no target, no band, no formula, no
/// calculation. `null` here is the whole position — a `0` would be the
/// recommendation "consume no sodium".
void _expectNoSodiumTargetOrBand(NutrientTransparencyData data) {
  expect(data.targetGrams, isNull, reason: 'v3 sets no sodium target');
  expect(data.rangeLow, isNull, reason: 'v3 has no sodium band');
  expect(data.rangeHigh, isNull, reason: 'v3 has no sodium band');
  expect(data.tldrLines, isEmpty, reason: 'v3 has no sodium formula');
  expect(
    data.calculationSections,
    isEmpty,
    reason: 'v3 has no sodium calculation to show',
  );
}

/// Everything on the card an athlete can read.
String _allUserFacingText(NutrientTransparencyData data) {
  return [
    data.tldrBody ?? '',
    data.tldrTip ?? '',
    for (final line in data.tldrLines)
      for (final seg in line.segments) seg.text,
    for (final s in data.storySections) s.question,
    for (final s in data.storySections) s.answer,
    for (final s in data.calculationSections) s.header,
    for (final s in data.calculationSections)
      for (final line in s.lines)
        for (final seg in line.segments) seg.text,
  ].join(' ').toLowerCase();
}

MacroTargets _preTargets({
  required double fluidsMl,
  required double carbsG,
  required double durationMin,
  required double tempC,
  double? sodiumMg,
  double? fluidsLowMl,
  double? fluidsHighMl,
  String? hydrationRegime,
  String? fluidTargetBasis,
  String? carbTargetBasis,
  List<PreRunCarbTier>? carbTiers,
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
      // Sodium v3: new plans carry no engine sodium figure. A delivered
      // observation may still be threaded through, which is what a non-null
      // value here represents.
      sodiumMg: sodiumMg,
      fluidsLowMl: fluidsLowMl,
      fluidsHighMl: fluidsHighMl,
      hydrationRegime: hydrationRegime,
      fluidTargetBasis: fluidTargetBasis,
      carbTargetBasis: carbTargetBasis,
      carbTiers: carbTiers,
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
