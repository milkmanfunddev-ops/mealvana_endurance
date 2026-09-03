import 'dart:math';

import '../../../../shared/domain/activity_type.dart';
import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';
import 'electrolyte_source_policy.dart';

// ---------------------------------------------------------------------------
// Category types (mirrors during-utils.ts ProductCategory)
// ---------------------------------------------------------------------------

enum _DuringCategory {
  primaryCarb, // gel, chew, drink_mix
  sportsDrink, // sports_drink (liquid with carbs)
  bikeSolid, // bar + other bike solids
  hydration, // water / low-carb beverage
  electrolyte, // supplement / electrolyte tablet
}

// ---------------------------------------------------------------------------
// Gut training level caps
//
// The server applies max-serving caps via `gut_training_levels` on each
// template food row — a DB column not mirrored on SolverFood. Instead we
// derive a coarse serving multiplier from the level and apply it as a cap
// on top of each food's existing `maxServings`.
//
// Levels map to a fraction of the food's per-phase maxServings:
//   low      → 0.5  (sensitive gut; conservative quantities)
//   moderate → 1.0  (default; use food's published maxServings)
//   high     → 1.5  (trained gut; allow up to 50% more servings)
//
// Capped by the food's absolute maxServings to avoid unrealistic quantities.
// ---------------------------------------------------------------------------

double _gutTrainingServingMultiplier(String? gutTrainingLevel) {
  switch (gutTrainingLevel) {
    case 'low':
      return 0.5;
    case 'high':
      return 1.5;
    default:
      return 1.0;
  }
}

/// Maximum servings for a food given the gut training level.
/// Always at least 1 so no food is completely blocked.
double _maxServingsForGut(SolverFood food, String? gutTrainingLevel) {
  final multiplier = _gutTrainingServingMultiplier(gutTrainingLevel);
  return max(1.0, food.maxServings.toDouble() * multiplier);
}

// ---------------------------------------------------------------------------
// Food categorisation (mirrors categorizeFood() in during-utils.ts)
// ---------------------------------------------------------------------------

_DuringCategory _categorizeFood(SolverFood food) {
  final pt = food.productType;

  // Explicit product_type mapping
  if (pt == 'gel' || pt == 'chew' || pt == 'drink_mix') {
    return _DuringCategory.primaryCarb;
  }
  if (pt == 'sports_drink') return _DuringCategory.sportsDrink;
  if (pt == 'bar') return _DuringCategory.bikeSolid;
  if (pt == 'beverage') return _DuringCategory.hydration;
  if (pt == 'supplement') return _DuringCategory.electrolyte;

  // Derived: liquid with significant carbs → sports drink
  if (food.isLiquid && food.carbsG > 5) return _DuringCategory.sportsDrink;

  // Derived: liquid with no/low carbs → hydration
  if (food.isLiquid) return _DuringCategory.hydration;

  // Derived: electrolyte → electrolyte
  if (food.isElectrolyte) return _DuringCategory.electrolyte;

  // Solid food → bike solid
  return _DuringCategory.bikeSolid;
}

class _CategorizedFoods {
  final List<SolverFood> primaryCarb;
  final List<SolverFood> sportsDrink;
  final List<SolverFood> bikeSolid;
  final List<SolverFood> hydration;
  final List<SolverFood> electrolyte;

  const _CategorizedFoods({
    required this.primaryCarb,
    required this.sportsDrink,
    required this.bikeSolid,
    required this.hydration,
    required this.electrolyte,
  });
}

_CategorizedFoods _categorizeFoods(List<SolverFood> foods) {
  final primaryCarb = <SolverFood>[];
  final sportsDrink = <SolverFood>[];
  final bikeSolid = <SolverFood>[];
  final hydration = <SolverFood>[];
  final electrolyte = <SolverFood>[];

  for (final food in foods) {
    switch (_categorizeFood(food)) {
      case _DuringCategory.primaryCarb:
        primaryCarb.add(food);
      case _DuringCategory.sportsDrink:
        sportsDrink.add(food);
      case _DuringCategory.bikeSolid:
        bikeSolid.add(food);
      case _DuringCategory.hydration:
        hydration.add(food);
      case _DuringCategory.electrolyte:
        electrolyte.add(food);
    }
  }

  return _CategorizedFoods(
    primaryCarb: primaryCarb,
    sportsDrink: sportsDrink,
    bikeSolid: bikeSolid,
    hydration: hydration,
    electrolyte: electrolyte,
  );
}

// ---------------------------------------------------------------------------
// Weighted pick (mirrors pickWeighted() in during-utils.ts)
//
// Sorts by preferenceScore descending, then picks deterministically from the
// top-scoring tier by index modulo tier size (NOT Math.random / DateTime.now).
// The server uses crypto.getRandomValues() — we use index-based selection so
// the result is reproducible in tests.
// ---------------------------------------------------------------------------

SolverFood? _pickWeighted(List<SolverFood> foods, {int seed = 0}) {
  if (foods.isEmpty) return null;
  if (foods.length == 1) return foods[0];

  final sorted = List<SolverFood>.from(foods)
    ..sort((a, b) => b.preferenceScore - a.preferenceScore);

  final bestScore = sorted[0].preferenceScore;
  final topTier = sorted.where((f) => f.preferenceScore == bestScore).toList();

  return topTier[seed % topTier.length];
}

// ---------------------------------------------------------------------------
// Serving arithmetic helpers
// ---------------------------------------------------------------------------

/// Round to nearest 0.5, minimum 0.5 (mirrors roundToIncrement).
double _roundToHalf(double v) {
  if (v <= 0) return 0;
  return max(0.5, (v * 2).round() / 2.0);
}

/// Clamp servings for indivisible vs. divisible foods, respecting [maxCap].
double _clampServings(SolverFood food, double servings, double maxCap) {
  final hardMax = min(maxCap, food.maxServings.toDouble());
  final clamped = servings.clamp(0.0, hardMax);
  if (food.isIndivisible) {
    return max(1.0, clamped.roundToDouble());
  }
  return _roundToHalf(clamped);
}

/// Derive effective upper bound for a single macro, given currently assigned
/// amount and a multiplier on the target (mirrors capServingsByUpperBounds).
double _maxServingsByMacro({
  required double perServing,
  required double assigned,
  required double target,
  required double upperMultiplier,
}) {
  if (perServing <= 0 || target <= 0) return double.infinity;
  return (target * upperMultiplier - assigned) / perServing;
}

/// Calculate servings for [food] capped to stay within macro upper bounds.
/// Returns 0 if the food cannot contribute without overshooting.
double _cappedServings({
  required SolverFood food,
  required double requested,
  required double carbsAssigned,
  required double sodiumAssigned,
  required double fluidAssigned,
  required double carbTarget,
  required double sodiumTarget,
  required double fluidTarget,
  required String? gutTrainingLevel,
  // Upper bound multipliers
  double carbUpperMultiplier = 1.1,
  double sodiumUpperMultiplier = 1.1,
  double fluidUpperMultiplier = 1.1,
}) {
  final gutMax = _maxServingsForGut(food, gutTrainingLevel);

  var cap = min(requested, gutMax);

  final byCarbUpper = _maxServingsByMacro(
    perServing: food.carbsG,
    assigned: carbsAssigned,
    target: carbTarget,
    upperMultiplier: carbUpperMultiplier,
  );
  final bySodiumUpper = _maxServingsByMacro(
    perServing: food.sodiumMg,
    assigned: sodiumAssigned,
    target: sodiumTarget,
    upperMultiplier: sodiumUpperMultiplier,
  );
  final byFluidUpper = _maxServingsByMacro(
    perServing: food.fluidMl,
    assigned: fluidAssigned,
    target: fluidTarget,
    upperMultiplier: fluidUpperMultiplier,
  );

  if (byCarbUpper.isFinite) cap = min(cap, byCarbUpper);
  if (bySodiumUpper.isFinite) cap = min(cap, bySodiumUpper);
  if (byFluidUpper.isFinite) cap = min(cap, byFluidUpper);

  return _clampServings(food, cap, gutMax);
}

// ---------------------------------------------------------------------------
// Electrolyte fill (mirrors fillElectrolytes() in during-utils.ts)
//
// Two-pass penalty-scored approach. Penalty = sodium gap + fluid overshoot +
// carb overshoot. Pick the best candidate in pass 1; if sodium is still below
// the lower bound after pass 1, pick a different candidate in pass 2.
// ---------------------------------------------------------------------------

class _ElecPick {
  final SolverFood food;
  final double servings;
  final double sodiumAfter;
  final double fluidAfter;
  final double carbsAfter;
  final double score;

  const _ElecPick({
    required this.food,
    required this.servings,
    required this.sodiumAfter,
    required this.fluidAfter,
    required this.carbsAfter,
    required this.score,
  });
}

// RULED food-recommendation §4 (Xuan, 2026-09-03): the picker itself lives in
// electrolyte_source_policy.dart — the Dart twin of the server's
// pickBestElectrolyte — so the conformance harness and the solver drive the
// same code. This adapter only converts the pick shape. The old inline picker
// (asymmetric baseline, capsulePenalty steer, floor-rescue accepting an
// in-range score-worsening pick, no min_servings) was the F-22/46/47 half of
// the divergence the ruling closes.
_ElecPick? _pickBestElectrolyte(
  List<SolverFood> pool,
  double currentSodium,
  double currentFluid,
  double currentCarbs,
  double sodiumTarget,
  double sodiumLower,
  double sodiumUpper,
  double fluidTarget,
  double fluidUpper,
  double carbTarget,
  double carbUpper,
  String? gutTrainingLevel,
) {
  final pick = pickBestElectrolyteSource(
    pool,
    currentSodium,
    currentFluid,
    currentCarbs,
    ElectrolyteSourceBounds(
      sodiumTarget: sodiumTarget,
      sodiumLower: sodiumLower,
      sodiumUpper: sodiumUpper,
      fluidTarget: fluidTarget,
      fluidUpper: fluidUpper,
      carbTarget: carbTarget,
      carbUpper: carbUpper,
      gutLevel: gutTrainingLevel,
    ),
  );
  if (pick == null) return null;
  return _ElecPick(
    food: pick.food,
    servings: pick.servings,
    sodiumAfter: pick.sodiumAfter,
    fluidAfter: pick.fluidAfter,
    carbsAfter: pick.carbsAfter,
    score: pick.score,
  );
}

// ---------------------------------------------------------------------------
// Main solver
// ---------------------------------------------------------------------------

/// Result of the during-phase solver for a single food item.
class DuringSolverItem {
  final String foodId;
  final double quantity;

  const DuringSolverItem({required this.foodId, required this.quantity});
}

/// Client-side during-phase solver that mirrors the server's 5-step rule-based
/// algorithm (`during-rule-solver.ts`).
///
/// Step 1 — Select primary carb source (gel/chew/drink_mix).
/// Step 2 — Add sports drink for remaining carbs + fluid.
/// Step 2.5 — Carb-deficit recovery from a second primary carb source.
/// Step 3 — Bike solids (cycling only).
/// Step 4 — Water to fill fluid target.
/// Step 5 — Two-pass electrolyte fill.
///
/// Running enforces a single primary carb type (no mixing); cycling may combine.
///
/// Selection within a tier is deterministic (preference-score sort + index 0
/// of the top-score tier) so the solver is predictable in tests.
///
/// Gut training level adjusts each food's effective max servings (low = 0.5×,
/// moderate = 1.0×, high = 1.5×) using the food's existing [SolverFood.maxServings].
class ClientDuringPhaseSolver {
  const ClientDuringPhaseSolver();

  /// Solve the during phase and return food items as [SolverSelection]s.
  ///
  /// [foods] — pool already filtered for the during phase.
  /// [targets] — carbs/sodium/fluid targets for the during phase.
  /// [activityType] — determines running vs. cycling constraints.
  /// [gutTrainingLevel] — 'low' | 'moderate' | 'high' | null.
  /// [durationMinutes] — reserved for future per-hour serving constraints;
  ///                     not yet used by this solver.
  List<SolverSelection> solve({
    required List<SolverFood> foods,
    required SolverTargets targets,
    required ActivityType activityType,
    String? gutTrainingLevel,
    int? durationMinutes,
  }) {
    if (foods.isEmpty) return [];

    final carbTarget = targets.carbsG;
    final sodiumTarget = targets.sodiumMg;
    final fluidTarget = targets.fluidMl;

    // Bounds come from the real calculated ranges when present; the ×1.1
    // multipliers are only a fallback for callers that pass no range
    // (mirrors the server's fallback in during-template-solver.ts).
    final carbUpper = carbTarget > 0
        ? (targets.carbsHighG ?? carbTarget * 1.1)
        : double.infinity;
    final sodiumUpper = sodiumTarget > 0
        ? (targets.sodiumHighMg ?? sodiumTarget * 1.1)
        : double.infinity;
    final fluidUpper = fluidTarget > 0
        ? (targets.fluidHighMl ?? fluidTarget * 1.1)
        : double.infinity;
    final sodiumLower = sodiumTarget > 0
        ? (targets.sodiumLowMg ?? sodiumTarget * 0.9)
        : 0.0;

    final isRunning = activityType == ActivityType.running;
    final isCycling = activityType == ActivityType.cycling;

    final cat = _categorizeFoods(foods);

    final result = <SolverSelection>[];
    double carbsAssigned = 0;
    double sodiumAssigned = 0;
    double fluidAssigned = 0;

    // ---- STEP 1: Primary carb source ----
    // If carb target is < 15g, skip primary carb (even the smallest gel ~25g
    // would overshoot).
    SolverFood? primaryCarb;

    if (carbTarget >= 15 && cat.primaryCarb.isNotEmpty) {
      primaryCarb = _pickWeighted(cat.primaryCarb);
    }

    if (primaryCarb != null) {
      // If sports drink is also available, split carb share 70/30
      final sdPeek = _pickWeighted(cat.sportsDrink);
      final hasSportsDrink = sdPeek != null && sdPeek.carbsG > 0;
      final primaryShare = hasSportsDrink ? 0.7 : 1.0;

      final primaryCarbTarget = carbTarget * primaryShare;
      final rawServings = primaryCarb.carbsG > 0
          ? primaryCarbTarget / primaryCarb.carbsG
          : 0.0;

      final servings = _cappedServings(
        food: primaryCarb,
        requested: rawServings,
        carbsAssigned: carbsAssigned,
        sodiumAssigned: sodiumAssigned,
        fluidAssigned: fluidAssigned,
        carbTarget: carbTarget,
        sodiumTarget: sodiumTarget,
        fluidTarget: fluidTarget,
        gutTrainingLevel: gutTrainingLevel,
        carbUpperMultiplier: 1.1,
      );

      if (servings > 0) {
        result.add(_buildSelection(primaryCarb, servings));
        carbsAssigned += primaryCarb.carbsG * servings;
        sodiumAssigned += primaryCarb.sodiumMg * servings;
        fluidAssigned += primaryCarb.fluidMl * servings;
      }
    }

    // ---- STEP 2: Sports drink (remaining carb share + fluid) ----
    // Running: do NOT add sports drink if primary carb is a gel/chew (it would
    // introduce a second primary-carb product type). Sports drink IS a
    // different category — it's fine for running too. The mixing constraint
    // only blocks combining TWO primary-carb types (e.g. gel + chew).
    final sportsDrink = _pickWeighted(cat.sportsDrink);
    if (sportsDrink != null) {
      final remainingCarbs = max(0.0, carbTarget - carbsAssigned);

      if (remainingCarbs > 0 && sportsDrink.carbsG > 0) {
        final rawSdServings = remainingCarbs / sportsDrink.carbsG;
        final effectiveCarbUpper = carbTarget < 15
            ? double.infinity
            : carbUpper;

        var sdServings = _cappedServings(
          food: sportsDrink,
          requested: rawSdServings,
          carbsAssigned: carbsAssigned,
          sodiumAssigned: sodiumAssigned,
          fluidAssigned: fluidAssigned,
          carbTarget: carbTarget,
          sodiumTarget: sodiumTarget,
          fluidTarget: fluidTarget,
          gutTrainingLevel: gutTrainingLevel,
          carbUpperMultiplier: carbTarget < 15 ? 10.0 : 1.1,
        );

        // Guard: don't add if rounded serving would overshoot
        final sdCarbsIfAdded = carbsAssigned + sportsDrink.carbsG * sdServings;
        final sdWouldOvershoot =
            carbTarget >= 15 && sdCarbsIfAdded > effectiveCarbUpper + 1e-9;

        if (sdServings > 0 && !sdWouldOvershoot) {
          result.add(_buildSelection(sportsDrink, sdServings));
          carbsAssigned += sportsDrink.carbsG * sdServings;
          sodiumAssigned += sportsDrink.sodiumMg * sdServings;
          fluidAssigned += sportsDrink.fluidMl * sdServings;
        } else if (sdServings > 0 && sdWouldOvershoot) {
          // Fallback: try sports drink alone if primary was below lower bound
          final carbLower = carbTarget * 0.9;
          if (carbsAssigned < carbLower && sportsDrink.carbsG > 0) {
            final sdFullServings = _cappedServings(
              food: sportsDrink,
              requested: carbTarget / sportsDrink.carbsG,
              carbsAssigned: 0,
              sodiumAssigned: sodiumAssigned,
              fluidAssigned: fluidAssigned,
              carbTarget: carbTarget,
              sodiumTarget: sodiumTarget,
              fluidTarget: fluidTarget,
              gutTrainingLevel: gutTrainingLevel,
              carbUpperMultiplier: 1.1,
            );
            final sdFullCarbs = sportsDrink.carbsG * sdFullServings;
            if (sdFullServings > 0 &&
                sdFullCarbs >= carbLower - 1e-9 &&
                sdFullCarbs <= carbUpper + 1e-9) {
              // Remove primary carb and replace with sports drink alone
              if (primaryCarb != null) {
                final idx = result.indexWhere(
                  (s) => s.foodId == primaryCarb!.id,
                );
                if (idx >= 0) {
                  final removed = result.removeAt(idx);
                  carbsAssigned -= removed.carbsG;
                  sodiumAssigned -= removed.sodiumMg;
                  fluidAssigned -= removed.fluidMl;
                }
              }
              result.add(_buildSelection(sportsDrink, sdFullServings));
              carbsAssigned += sportsDrink.carbsG * sdFullServings;
              sodiumAssigned += sportsDrink.sodiumMg * sdFullServings;
              fluidAssigned += sportsDrink.fluidMl * sdFullServings;
            }
          }
        }
      }
    }

    // ---- STEP 2.5: Carb-deficit recovery ----
    {
      final carbDeficit = carbTarget - carbsAssigned;
      if (carbDeficit > carbTarget * 0.2 && cat.primaryCarb.length > 1) {
        // Exclude the already-selected primary carb
        final alternates = primaryCarb != null
            ? cat.primaryCarb.where((f) => f.id != primaryCarb!.id).toList()
            : cat.primaryCarb;

        // Running mixing constraint: if a primary carb was already selected,
        // block other primary-carb types (only allow the same product type).
        final filteredAlternates = (isRunning && primaryCarb != null)
            ? alternates
                  .where((f) => f.productType == primaryCarb!.productType)
                  .toList()
            : alternates;

        if (filteredAlternates.isNotEmpty) {
          final secondaryCarb = _pickWeighted(filteredAlternates, seed: 1);
          if (secondaryCarb != null && secondaryCarb.carbsG > 0) {
            final rawSec = carbDeficit / secondaryCarb.carbsG;
            final secServings = _cappedServings(
              food: secondaryCarb,
              requested: rawSec,
              carbsAssigned: carbsAssigned,
              sodiumAssigned: sodiumAssigned,
              fluidAssigned: fluidAssigned,
              carbTarget: carbTarget,
              sodiumTarget: sodiumTarget,
              fluidTarget: fluidTarget,
              gutTrainingLevel: gutTrainingLevel,
              carbUpperMultiplier: 1.1,
            );
            final secCarbsIfAdded =
                carbsAssigned + secondaryCarb.carbsG * secServings;
            if (secServings > 0 && secCarbsIfAdded <= carbUpper + 1e-9) {
              result.add(_buildSelection(secondaryCarb, secServings));
              carbsAssigned += secondaryCarb.carbsG * secServings;
              sodiumAssigned += secondaryCarb.sodiumMg * secServings;
              fluidAssigned += secondaryCarb.fluidMl * secServings;
            }
          }
        }
      }

      // Still in deficit >30%? Try sports drink as last resort
      if (carbTarget > 0 &&
          carbTarget - carbsAssigned > carbTarget * 0.3 &&
          sportsDrink == null &&
          cat.sportsDrink.isNotEmpty) {
        final anySd = cat.sportsDrink[0];
        if (anySd.carbsG > 0) {
          final rawRec = (carbTarget - carbsAssigned) / anySd.carbsG;
          final recServings = _cappedServings(
            food: anySd,
            requested: rawRec,
            carbsAssigned: carbsAssigned,
            sodiumAssigned: sodiumAssigned,
            fluidAssigned: fluidAssigned,
            carbTarget: carbTarget,
            sodiumTarget: sodiumTarget,
            fluidTarget: fluidTarget,
            gutTrainingLevel: gutTrainingLevel,
            carbUpperMultiplier: 1.1,
          );
          final recCarbsIfAdded = carbsAssigned + anySd.carbsG * recServings;
          if (recServings > 0 && recCarbsIfAdded <= carbUpper + 1e-9) {
            result.add(_buildSelection(anySd, recServings));
            carbsAssigned += anySd.carbsG * recServings;
            sodiumAssigned += anySd.sodiumMg * recServings;
            fluidAssigned += anySd.fluidMl * recServings;
          }
        }
      }
    }

    // ---- Running mixing constraint (applied retroactively for safety) ----
    // After all primary-carb steps, ensure running only has one product type.
    // This is the final enforcement gate — the pickers above already respect
    // it, but this guard handles any edge cases.
    if (isRunning) {
      _enforceRunningMixingConstraint(
        result,
        foods,
        carbsRef: (c) => carbsAssigned -= c,
        sodiumRef: (s) => sodiumAssigned -= s,
        fluidRef: (f) => fluidAssigned -= f,
      );
    }

    // ---- STEP 3: Bike solids (cycling only) ----
    if (isCycling && cat.bikeSolid.isNotEmpty) {
      final remainingCarbs = max(0.0, carbTarget - carbsAssigned);
      if (remainingCarbs > 10 && cat.bikeSolid.isNotEmpty) {
        final bikeSolid = _pickWeighted(cat.bikeSolid);
        if (bikeSolid != null && bikeSolid.carbsG > 0) {
          final rawBs = remainingCarbs / bikeSolid.carbsG;
          final bsServings = _cappedServings(
            food: bikeSolid,
            requested: rawBs,
            carbsAssigned: carbsAssigned,
            sodiumAssigned: sodiumAssigned,
            fluidAssigned: fluidAssigned,
            carbTarget: carbTarget,
            sodiumTarget: sodiumTarget,
            fluidTarget: fluidTarget,
            gutTrainingLevel: gutTrainingLevel,
            carbUpperMultiplier: 1.1,
          );
          if (bsServings > 0) {
            result.add(_buildSelection(bikeSolid, bsServings));
            carbsAssigned += bikeSolid.carbsG * bsServings;
            sodiumAssigned += bikeSolid.sodiumMg * bsServings;
            fluidAssigned += bikeSolid.fluidMl * bsServings;
          }
        }
      }
    }

    // ---- STEP 4: Hydration (water to fill fluid target) ----
    final remainingFluid = max(0.0, fluidTarget - fluidAssigned);
    if (remainingFluid > 0 && cat.hydration.isNotEmpty) {
      final water = _pickWeighted(cat.hydration);
      if (water != null && water.fluidMl > 0) {
        final rawW = remainingFluid / water.fluidMl;
        final waterServings = _cappedServings(
          food: water,
          requested: rawW,
          carbsAssigned: carbsAssigned,
          sodiumAssigned: sodiumAssigned,
          fluidAssigned: fluidAssigned,
          carbTarget: carbTarget,
          sodiumTarget: sodiumTarget,
          fluidTarget: fluidTarget,
          gutTrainingLevel: gutTrainingLevel,
          carbUpperMultiplier: 1.1,
          fluidUpperMultiplier: 1.1,
        );
        if (waterServings > 0) {
          result.add(_buildSelection(water, waterServings));
          fluidAssigned += water.fluidMl * waterServings;
          sodiumAssigned += water.sodiumMg * waterServings;
        }
      }
    }

    // ---- STEP 5: Two-pass electrolyte fill ----
    if (cat.electrolyte.isNotEmpty && sodiumTarget > 0) {
      final remainingSodium = max(0.0, sodiumTarget - sodiumAssigned);
      if (remainingSodium > 0) {
        final firstPick = _pickBestElectrolyte(
          cat.electrolyte,
          sodiumAssigned,
          fluidAssigned,
          carbsAssigned,
          sodiumTarget,
          sodiumLower,
          sodiumUpper,
          fluidTarget,
          fluidUpper,
          carbTarget,
          carbUpper,
          gutTrainingLevel,
        );
        if (firstPick != null) {
          result.add(_buildSelection(firstPick.food, firstPick.servings));
          sodiumAssigned = firstPick.sodiumAfter;
          fluidAssigned = firstPick.fluidAfter;
          carbsAssigned = firstPick.carbsAfter;

          // Second pass: if sodium is still below target
          if (sodiumAssigned < sodiumTarget) {
            final secondPool = cat.electrolyte
                .where((e) => e.id != firstPick.food.id)
                .toList();
            final secondPick = _pickBestElectrolyte(
              secondPool,
              sodiumAssigned,
              fluidAssigned,
              carbsAssigned,
              sodiumTarget,
              sodiumLower,
              sodiumUpper,
              fluidTarget,
              fluidUpper,
              carbTarget,
              carbUpper,
              gutTrainingLevel,
            );
            if (secondPick != null) {
              result.add(_buildSelection(secondPick.food, secondPick.servings));
              sodiumAssigned = secondPick.sodiumAfter;
              fluidAssigned = secondPick.fluidAfter;
              carbsAssigned = secondPick.carbsAfter;
            }
          }
        }
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Running mixing constraint
  // ---------------------------------------------------------------------------

  /// Running workouts may only use ONE primary-carb product type.
  ///
  /// Finds all primary-carb selections in [result], determines the dominant
  /// product type (highest total carb contribution), and removes all others.
  void _enforceRunningMixingConstraint(
    List<SolverSelection> result,
    List<SolverFood> foods, {
    required void Function(double) carbsRef,
    required void Function(double) sodiumRef,
    required void Function(double) fluidRef,
  }) {
    // Build a map from product type → (total carbs, list of indices to keep)
    final byType = <String, double>{};
    for (final sel in result) {
      final food = _findFood(foods, sel.foodId);
      if (food == null) continue;
      if (_categorizeFood(food) != _DuringCategory.primaryCarb) continue;
      final pt = food.productType ?? 'unknown';
      byType[pt] = (byType[pt] ?? 0) + sel.carbsG;
    }
    if (byType.length <= 1) return; // nothing to do

    // Find dominant type (highest carb contribution)
    String? dominant;
    double domCarbs = -1;
    for (final entry in byType.entries) {
      if (entry.value > domCarbs) {
        domCarbs = entry.value;
        dominant = entry.key;
      }
    }
    if (dominant == null) return;

    // Remove all primary-carb items that are NOT the dominant type
    final toRemove = <int>[];
    for (var i = 0; i < result.length; i++) {
      final sel = result[i];
      final food = _findFood(foods, sel.foodId);
      if (food == null) continue;
      if (_categorizeFood(food) != _DuringCategory.primaryCarb) continue;
      if ((food.productType ?? 'unknown') != dominant) {
        toRemove.add(i);
        carbsRef(sel.carbsG);
        sodiumRef(sel.sodiumMg);
        fluidRef(sel.fluidMl);
      }
    }
    // Remove in reverse order to preserve indices
    for (final idx in toRemove.reversed) {
      result.removeAt(idx);
    }
  }

  SolverFood? _findFood(List<SolverFood> foods, String id) {
    for (final f in foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build output
  // ---------------------------------------------------------------------------

  SolverSelection _buildSelection(SolverFood food, double servings) {
    return SolverSelection(
      foodId: food.id,
      foodName: food.name,
      quantity: servings,
      carbsG: food.carbsG * servings,
      proteinG: food.proteinG * servings,
      fatG: food.fatG * servings,
      sodiumMg: food.sodiumMg * servings,
      fluidMl: food.fluidMl * servings,
      calories: (food.calories * servings).round(),
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      description: food.description,
      imageAddress: food.imageAddress,
      servingSize: food.servingSize,
      servingUnit: food.servingUnit,
      isDrink: food.isLiquid,
      isIndivisible: food.isIndivisible,
      isLiquid: food.isLiquid,
      isElectrolyte: food.isElectrolyte,
      productType: food.productType,
    );
  }
}
