import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Regression for milkmanfunddev-ops/mealvana_endurance#16:
///
/// For a low-bodyweight athlete (47.6 kg ≈ 105 lb) scheduled with a 4 h
/// pre-workout window, the engine emits the full cited protocol but a small
/// absolute dose. Before the fix, the Flutter explanation service inferred the
/// window from the *magnitude* (`fluidsMl <= 300`) and rendered short-window
/// copy against full-protocol numbers.
///
/// The fix threads an explicit signal through [PreRunMacros] and branches the
/// explanation on it rather than on the number. **That premise is unchanged.**
/// What changed is the signal itself: hydration v6 retired the integer
/// `hydrationTier` in favour of the [PreRunHydrationRegime] string
/// (`cited` | `extrapolated` | `clearance_bound` | `gated`) — see PW-013 in
/// `docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md`. These tests pin the boundary case
/// so a regression to the old magnitude heuristic surfaces in CI.
///
/// Tier headers were replaced with user-facing window language (no internal
/// "Tier n" terminology may leak — see `pre_workout_windows_test.dart`), so the
/// tests discriminate by formula *content*:
///   * `cited`                        → 'full ACSM protocol'
///   * `extrapolated`/`clearance_bound` → '10–120 min window'
///   * `gated`                        → 'no structured intake'
void main() {
  group(
    'PreWorkout fluid transparency — explicit regime beats the heuristic',
    () {
      final service = MacroExplanationService();

      test('47.6 kg, regime=cited, fluidsMl=286 renders the full protocol '
          '(not the short window)', () {
        final macroTargets = _sampleMacroTargetsWithPreRun(
          preRun: const PreRunMacros(
            carbsG: 190,
            proteinG: 10,
            fatCapG: 10,
            fluidsMl: 286,
            sodiumMg: 450,
            fluidsLowMl: 238,
            fluidsHighMl: 333,
            hydrationRegime: PreRunHydrationRegime.cited,
          ),
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: macroTargets,
          bodyWeightKg: 47.6,
        );

        expect(map, isNotNull);
        final data = map![Scenario.singleSport]!;

        final formulaText = _allFormulaText(data.calculationSections);
        expect(
          formulaText,
          contains('full ACSM protocol'),
          reason:
              'An explicit cited regime must drive the full-protocol '
              'calculation copy even when fluidsMl ≤ 300 (the old '
              'fluid-magnitude heuristic).',
        );
        expect(
          formulaText,
          isNot(contains('10–120 min window')),
          reason:
              'Short-window markup would mislabel a body-weight-scaled '
              'full-protocol recommendation for low-bodyweight athletes.',
        );
      });

      test(
        'regime=extrapolated with fluidsMl=250 renders the short window',
        () {
          final formulaText = _formulaTextFor(
            service,
            const PreRunMacros(
              carbsG: 0,
              proteinG: 0,
              fatCapG: 0,
              fluidsMl: 250,
              fluidsLowMl: 0,
              fluidsHighMl: 300,
              hydrationRegime: PreRunHydrationRegime.extrapolated,
            ),
          );
          expect(formulaText, contains('10–120 min window'));
          expect(formulaText, isNot(contains('full ACSM protocol')));
        },
      );

      test(
        'regime=clearance_bound renders the short window too — it is a sub-2 h '
        'regime, and a large dose must not flip it to the full protocol',
        () {
          // The mirror of #16: a heavy athlete very close to the start gets a
          // clearance-capped dose well over 300 ml. Magnitude would say "full
          // protocol"; the regime says otherwise, and the regime wins.
          final formulaText = _formulaTextFor(
            service,
            const PreRunMacros(
              carbsG: 0,
              proteinG: 0,
              fatCapG: 0,
              fluidsMl: 400,
              fluidsLowMl: 0,
              fluidsHighMl: 890,
              hydrationRegime: PreRunHydrationRegime.clearanceBound,
            ),
            bodyWeightKg: 100,
          );
          expect(formulaText, contains('10–120 min window'));
          expect(formulaText, isNot(contains('full ACSM protocol')));
        },
      );

      test('regime=gated renders no structured intake', () {
        final formulaText = _formulaTextFor(
          service,
          const PreRunMacros(
            carbsG: 0,
            proteinG: 0,
            fatCapG: 0,
            // The gate path sets no target at all; the domain collapses it to 0
            // for the legacy field, which is exactly why the regime — not the
            // number — has to be what the copy branches on.
            fluidsMl: 0,
            hydrationRegime: PreRunHydrationRegime.gated,
          ),
        );
        expect(formulaText, contains('no structured intake'));
        expect(formulaText, isNot(contains('full ACSM protocol')));
        expect(formulaText, isNot(contains('10–120 min window')));
      });

      test(
        'legacy plan without a regime still falls back to the fluid heuristic',
        () {
          // Older cached plans carry no regime — the service must stay backwards
          // compatible and use the historical fluid-magnitude heuristic.
          final formulaText = _formulaTextFor(
            service,
            const PreRunMacros(
              carbsG: 280,
              proteinG: 14,
              fatCapG: 14,
              fluidsMl: 420,
              sodiumMg: 450,
              fluidsLowMl: 350,
              fluidsHighMl: 490,
              // hydrationRegime intentionally null
            ),
          );
          // 420 ml > 300 → legacy heuristic resolves to the full protocol.
          expect(formulaText, contains('full ACSM protocol'));
        },
      );

      test('the regime, not the magnitude, decides: identical fluidsMl renders '
          'different copy under different regimes', () {
        // The whole point of #16 in one assertion. Same number, same athlete,
        // opposite copy — impossible under a magnitude heuristic.
        const fluidsMl = 286.0;
        final cited = _formulaTextFor(
          service,
          const PreRunMacros(
            carbsG: 0,
            proteinG: 0,
            fatCapG: 0,
            fluidsMl: fluidsMl,
            hydrationRegime: PreRunHydrationRegime.cited,
          ),
          bodyWeightKg: 47.6,
        );
        final extrapolated = _formulaTextFor(
          service,
          const PreRunMacros(
            carbsG: 0,
            proteinG: 0,
            fatCapG: 0,
            fluidsMl: fluidsMl,
            hydrationRegime: PreRunHydrationRegime.extrapolated,
          ),
          bodyWeightKg: 47.6,
        );

        expect(cited, contains('full ACSM protocol'));
        expect(extrapolated, contains('10–120 min window'));
        expect(cited, isNot(extrapolated));
      });
    },
  );
}

/// Render [preRun] and flatten its pre-workout fluid calculation copy.
String _formulaTextFor(
  MacroExplanationService service,
  PreRunMacros preRun, {
  double bodyWeightKg = 70,
}) {
  final map = service.getFluidTransparencyData(
    phase: ExplanationPhase.before,
    macroTargets: _sampleMacroTargetsWithPreRun(preRun: preRun),
    bodyWeightKg: bodyWeightKg,
  )!;
  return _allFormulaText(map[Scenario.singleSport]!.calculationSections);
}

/// Flatten every formula segment across [sections] into one string so tests
/// can discriminate which window's calculation copy rendered by content.
String _allFormulaText(List<CalculationSection> sections) {
  return sections
      .expand((s) => s.lines)
      .expand((l) => l.segments)
      .map((seg) => seg.text)
      .join();
}

MacroTargets _sampleMacroTargetsWithPreRun({required PreRunMacros preRun}) {
  return MacroTargets(
    id: 'sample',
    activityType: ActivityType.running,
    preRun: preRun,
    duringRun: const DuringRunMacros(
      carbRateGPerH: 70,
      carbTotalG: 140,
      fluidRateMlPerH: 500,
      fluidTotalMl: 1000,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 1200,
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: [60, 90],
      rawBandLowGPerH: 60,
      rawBandHighGPerH: 90,
      gutMultiplier: 1.0,
      sportCeilingGPerH: 70,
      isTested: false,
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
      durationH: 2.0,
      durationMin: 120,
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
