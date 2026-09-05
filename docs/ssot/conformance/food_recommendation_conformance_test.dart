// QA conformance — food-recommendation (selection contract), 26 vectors.
//
// Runs via:  qa/conformance/run_dart.sh food-recommendation
// (copied into the app checkout as test/_qa_conformance_tmp_test.dart and run
// with --dart-define=QA_VECTORS=<abs path>; the runner also sets
// --dart-define=QA_DIFF_OUT=<path> so this harness emits the canonical
// selection results the §8 twin differential byte-compares against the Deno
// runner `supabase/functions/tests/food_recommendation_vectors.test.ts`).
//
// The harness exposes the SELECTION RESULT — which source, how many servings,
// which window and tiers — because these vectors assert POLICY, not macro
// arithmetic. Engine entry points driven (the same code the production
// solvers call):
//   §3/§3a  resolveFuelingWindow          (domain/fueling_window_authority.dart)
//   §4      pickBestElectrolyteSource      (client_plan/electrolyte_source_policy.dart)
//   §4.5    sortSodiumBackfillCandidates   (same file)
//   §6(a)   mealTierCandidateCheck         (domain/selection_practicality.dart)
//   §6(e)   solventRequirementMl / solventConstraintApplies
//   §1/§1a  resolveSelectionStep / scalePinnedServings /
//           pinConflictLabelRequired / unrenderablePinDowngrade
//           (domain/selection_precedence.dart)
//
// Harness conventions (per the vector file's note): electrolyte pool items
// are whole-unit (catalog C3: capsules/shots/sticks are indivisible,
// min_servings 1); `carryable:false` maps to a liquid supplement (the §4.3
// derivation is `supplement && !is_liquid` — the pickle shot is a liquid,
// catalog v1.1 data correction); the band floor defaults to target×0.9 (the
// engines' shared bounds fallback) when a vector names only the upper bound;
// the backfill serving count follows the backfill's ceil-to-cover rule for
// indivisible essentials; W1's catalog fixture: Oatmeal 27 g carbs/serving,
// allergens [gluten].

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/electrolyte_source_policy.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fueling_window_authority.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/selection_practicality.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/selection_precedence.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_food.dart';

// W1 catalog fixture (the spec's worked-example rows, verified 2026-09-02).
const double kOatmealCarbsPerServing = 27.0;
const List<String> kOatmealAllergens = ['gluten'];

String _fmtNum(num v) {
  final r = v.roundToDouble();
  if ((v - r).abs() < 1e-9) return r.toInt().toString();
  return v.toStringAsFixed(1);
}

SolverFood _poolFood(Map<String, dynamic> e) {
  final carryable = e['carryable'] as bool? ?? false;
  return SolverFood(
    id: e['name'] as String,
    name: e['name'] as String,
    carbsG: 0,
    proteinG: 0,
    fatG: 0,
    sodiumMg: (e['sodium_mg'] as num).toDouble(),
    fluidMl: 0,
    calories: 0,
    maxServings: (e['max_servings'] as num?)?.toInt() ?? 10,
    preferenceScore: 0,
    minServings: 1.0,
    isIndivisible: true,
    productType: 'supplement',
    isLiquid: !carryable,
  );
}

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');
  if (vectorsPath.isEmpty) {
    throw StateError(
      'QA_VECTORS not set — run via qa/conformance/run_dart.sh '
      'food-recommendation',
    );
  }
  final file = File(vectorsPath);
  if (!file.existsSync()) {
    throw StateError('QA_VECTORS file missing: $vectorsPath');
  }
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  const diffOut = String.fromEnvironment('QA_DIFF_OUT');
  final diffLines = <String>[];

  test('vector count sanity', () {
    expect(vectors.length, greaterThanOrEqualTo(26),
        reason: 'expected the full ratified vector set');
  });

  for (final v in vectors) {
    final id = v['id'] as String;
    final status = v['status'] as String? ?? 'ratified';
    final i = v['inputs'] as Map<String, dynamic>;
    final e = v['expected'] as Map<String, dynamic>;
    final why = v['why'] as String? ?? '';

    test('[$status] $id', () {
      // ── §3/§3a window authority ────────────────────────────────────────
      if (i.containsKey('session_class')) {
        final res = resolveFuelingWindow(
          sessionClass:
              FuelingSessionClass.fromWire(i['session_class'] as String),
          startHour: (i['start_hour'] as num).toInt(),
          isRace: i['race'] as bool? ?? false,
          minutesUntilStart: (i['minutes_until_start'] as num).toInt(),
        );
        expect(res.windowMin, e['default_window_min'], reason: why);
        expect(res.activePhases, (e['active_phases'] as List).cast<String>(),
            reason: why);
        diffLines.add(
          '$id|window=${_fmtNum(res.windowMin)}'
          '|phases=${res.activePhases.join(',')}',
        );
        return;
      }

      // ── §4 electrolyte source policy ───────────────────────────────────
      if (i.containsKey('pool')) {
        final pool = (i['pool'] as List)
            .cast<Map<String, dynamic>>()
            .map(_poolFood)
            .toList();
        final target = (i['sodium_target_mg'] as num).toDouble();
        final upper = (i['sodium_upper_mg'] as num).toDouble();
        final current = (i['current_sodium_mg'] as num?)?.toDouble() ?? 0;
        final pick = pickBestElectrolyteSource(
          pool,
          current,
          0,
          0,
          ElectrolyteSourceBounds(
            sodiumTarget: target,
            sodiumLower: target * 0.9, // engines' shared bounds fallback
            sodiumUpper: upper,
            fluidTarget: 0,
            fluidUpper: double.infinity,
            carbTarget: 0,
            carbUpper: double.infinity,
          ),
        );
        expect(pick, isNotNull, reason: why);
        final delivered = pick!.sodiumAfter - current;
        expect(pick.food.name, e['pick'], reason: why);
        expect(pick.servings, closeTo((e['servings'] as num).toDouble(), 1e-9),
            reason: why);
        expect(delivered, closeTo((e['delivered_mg'] as num).toDouble(), 1e-6),
            reason: why);
        diffLines.add(
          '$id|pick=${pick.food.name}|servings=${_fmtNum(pick.servings)}'
          '|delivered=${_fmtNum(delivered)}',
        );
        return;
      }

      // ── §4.5 sodium backfill preference ────────────────────────────────
      if (i.containsKey('essentials')) {
        final deficit = (i['deficit_mg'] as num).toDouble();
        final pool = (i['essentials'] as List)
            .cast<Map<String, dynamic>>()
            .map(_poolFood)
            .toList();
        final ranked = sortSodiumBackfillCandidates(
          pool.where((f) => f.sodiumMg > 0 && f.carbsG <= 0).toList(),
        );
        expect(ranked, isNotEmpty, reason: why);
        final best = ranked.first;
        // Ceil-to-cover for indivisible essentials (the backfill's rule).
        final servings = (deficit / best.sodiumMg).ceilToDouble();
        final delivered = servings * best.sodiumMg;
        expect(best.name, e['pick'], reason: why);
        expect(servings, closeTo((e['servings'] as num).toDouble(), 1e-9),
            reason: why);
        expect(delivered, closeTo((e['delivered_mg'] as num).toDouble(), 1e-6),
            reason: why);
        diffLines.add(
          '$id|pick=${best.name}|servings=${_fmtNum(servings)}'
          '|delivered=${_fmtNum(delivered)}',
        );
        return;
      }

      // ── §6(a) meal-tier practicality ───────────────────────────────────
      if (i.containsKey('candidate') && i.containsKey('tier')) {
        final c = i['candidate'] as Map<String, dynamic>;
        final check = mealTierCandidateCheck(
          componentCount: (c['components'] as num?)?.toInt() ?? 1,
          singleFoodSufficient: c['single_food_sufficient'] as bool? ?? false,
          carbsPerServingG: (c['carbs_g'] as num?)?.toDouble(),
          carbTargetG: (i['carb_target_g'] as num?)?.toDouble(),
        );
        expect(check.allowed, e['allowed'], reason: why);
        expect(check.reason?.wireName, e['reason'], reason: why);
        diffLines.add(
          '$id|allowed=${check.allowed}'
          '|reason=${check.reason?.wireName ?? 'none'}',
        );
        return;
      }

      // ── §6(e) solvent session-total ────────────────────────────────────
      if (i.containsKey('scheduled')) {
        final path = i['path'] as String?;
        final applies = solventConstraintApplies(path ?? 'template');
        if (!applies) {
          expect(e['constraint_applies'], false, reason: why);
          diffLines.add('$id|applies=false');
          return;
        }
        final scheduled = (i['scheduled'] as List).cast<Map<String, dynamic>>();
        var required = 0.0;
        for (final s in scheduled) {
          final servings = (s['servings'] as num).toDouble();
          final minMl = (s['solvent_min_ml'] as num?)?.toDouble();
          required += (minMl ?? 250.0) * servings;
        }
        final plainWater = (i['plain_water_ml'] as num?)?.toDouble() ?? 0;
        final satisfied = plainWater + 1e-9 >= required;
        expect(satisfied, e['satisfied'], reason: why);
        expect(required, closeTo((e['required_water_ml'] as num).toDouble(), 1e-6),
            reason: why);
        diffLines.add(
          '$id|applies=true|satisfied=$satisfied'
          '|required=${_fmtNum(required)}',
        );
        return;
      }

      // ── §1/§1a precedence & honesty ────────────────────────────────────
      if (i.containsKey('personal_formula')) {
        final pf = i['personal_formula'] as Map<String, dynamic>;
        final step = resolveSelectionStep(
          hasInScopePersonalFormula: pf['scope_match'] as bool? ?? false,
          hasInScopePinnedTemplate:
              (i['pinned_system_template'] as Map?)?['scope_match'] as bool? ??
                  false,
          hasEligibleTemplates: true,
        );
        final selected = step == 1
            ? pf['name'] as String
            : (i['pinned_system_template'] as Map)['name'] as String;
        expect(selected, e['selected'], reason: why);
        expect(step, e['step'], reason: why);
        diffLines.add('$id|selected=$selected|step=$step');
        return;
      }

      if (i.containsKey('pins')) {
        final pins = (i['pins'] as List).cast<Map<String, dynamic>>();
        final renderable = pins.every((p) => p['renderable'] as bool? ?? true);
        if (!renderable) {
          final downgrade = unrenderablePinDowngrade();
          expect(downgrade.usedPin, e['used_pin'], reason: why);
          expect(downgrade.fallthroughReason, e['fallthrough_reason'],
              reason: why);
          diffLines.add(
            '$id|used_pin=${downgrade.usedPin}'
            '|fallthrough=${downgrade.fallthroughReason}',
          );
          return;
        }
        // Face 2: the pin is honored unconditionally — eligible unpinned
        // templates are never substituted; servings carb-scale with the
        // 0.5 snap; conflicts label, never block (§1a).
        final pin = pins.first;
        expect(pin['scope_match'], true, reason: why);
        final selected = pin['template'] as String;
        final servings = scalePinnedServings(
          (i['meal_carb_target_g'] as num).toDouble(),
          kOatmealCarbsPerServing,
        );
        final conflict = pinConflictLabelRequired(
          kOatmealAllergens,
          (i['athlete_allergies'] as List? ?? const []).cast<String>(),
        );
        expect(selected, e['selected'], reason: why);
        expect(servings, closeTo((e['servings'] as num).toDouble(), 1e-9),
            reason: why);
        expect(conflict, e['conflict_label'], reason: why);
        diffLines.add(
          '$id|selected=$selected|servings=${_fmtNum(servings)}'
          '|conflict=$conflict',
        );
        return;
      }

      fail('unrecognized vector shape for $id — harness needs a new arm');
    });
  }

  tearDownAll(() {
    if (diffOut.isEmpty) return;
    File(diffOut).writeAsStringSync('${diffLines.join('\n')}\n');
  });
}
