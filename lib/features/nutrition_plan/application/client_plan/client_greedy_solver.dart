import 'dart:math';

import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';
import '../../domain/sport_config.dart';

/// Client-side greedy solver for all nutrition plan phases.
///
/// Intentionally simpler than the V3 edge function — this is a "good enough"
/// fallback that produces real food selections when the server is unreachable.
/// The plan is regenerated when connectivity returns.
///
/// Based on the server's `greedy-fallback.ts` algorithm, adapted for Dart.
class ClientGreedySolver {
  const ClientGreedySolver();

  /// Solve for a single phase: select foods from [foods] to approximate [targets].
  ///
  /// [phase] is one of: 'before', 'during', 'after'.
  /// [config] controls max foods and servings per food.
  List<SolverSelection> solve({
    required List<SolverFood> foods,
    required SolverTargets targets,
    required String phase,
    required SportPhaseConfig config,
  }) {
    if (foods.isEmpty) return [];

    final selections = <SolverSelection>[];
    final totals = _RunningTotals();

    // Sort: preference desc, then macro efficiency
    final sorted = List<SolverFood>.from(foods)
      ..sort((a, b) => _compareFoods(a, b, phase));

    final carbsTarget = targets.carbsG;
    final proteinTarget = targets.proteinG;
    final waterTarget = targets.fluidMl;

    for (final food in sorted) {
      if (selections.length >= config.maxFoods) break;

      // Skip foods that would overshoot already-met targets
      if (_wouldOvershoot(food, totals, targets, phase)) continue;

      // Calculate needed servings based on primary deficit
      var neededServings = _calcNeededServings(
        food: food,
        totals: totals,
        targets: targets,
        phase: phase,
      );

      if (neededServings <= 0) continue;

      // Cap servings to avoid overshoots
      neededServings = _capServings(
        food: food,
        neededServings: neededServings,
        totals: totals,
        targets: targets,
        phase: phase,
      );

      // Apply limits
      neededServings = min(
        neededServings.toDouble(),
        min(config.maxServingsPerFood.toDouble(), food.maxServings.toDouble()),
      );

      // Round: indivisible → whole numbers, divisible → nearest 0.5
      neededServings = food.isIndivisible
          ? max(1, neededServings.roundToDouble())
          : _roundToHalf(neededServings);

      if (neededServings <= 0) continue;

      selections.add(
        SolverSelection(
          foodId: food.id,
          foodName: food.name,
          quantity: neededServings,
          carbsG: food.carbsG * neededServings,
          proteinG: food.proteinG * neededServings,
          fatG: food.fatG * neededServings,
          sodiumMg: food.sodiumMg * neededServings,
          fluidMl: food.fluidMl * neededServings,
          calories: (food.calories * neededServings).round(),
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
        ),
      );

      totals.carbsG += food.carbsG * neededServings;
      totals.proteinG += food.proteinG * neededServings;
      totals.fatG += food.fatG * neededServings;
      totals.sodiumMg += food.sodiumMg * neededServings;
      totals.fluidMl += food.fluidMl * neededServings;

      // Stop if targets approximately met
      final carbsMet = carbsTarget <= 0 || totals.carbsG >= carbsTarget * 0.9;
      final proteinMet =
          proteinTarget <= 0 || totals.proteinG >= proteinTarget * 0.7;
      final waterMet = waterTarget <= 0 || totals.fluidMl >= waterTarget * 0.7;
      final sodiumTarget = targets.sodiumMg;
      final sodiumMet =
          sodiumTarget <= 0 || totals.sodiumMg >= sodiumTarget * 0.9;
      if (carbsMet && proteinMet && waterMet && sodiumMet) break;
    }

    return selections;
  }

  /// Sort foods by preference and macro efficiency.
  int _compareFoods(SolverFood a, SolverFood b, String phase) {
    // Primary: preference score descending
    if (a.preferenceScore != b.preferenceScore) {
      return b.preferenceScore - a.preferenceScore;
    }
    // Secondary: macro efficiency
    if (phase == 'after') {
      return (b.carbsG + b.proteinG).compareTo(a.carbsG + a.proteinG);
    }
    return b.carbsG.compareTo(a.carbsG);
  }

  /// Check if adding 1 serving of [food] would excessively overshoot targets.
  bool _wouldOvershoot(
    SolverFood food,
    _RunningTotals totals,
    SolverTargets targets,
    String phase,
  ) {
    final carbsTarget = targets.carbsG;
    final proteinTarget = targets.proteinG;
    final sodiumTarget = targets.sodiumMg;
    final waterTarget = targets.fluidMl;

    final wouldOvershootCarbs =
        carbsTarget > 0 && totals.carbsG + food.carbsG > carbsTarget * 1.3;
    final wouldOvershootSodium =
        sodiumTarget > 0 &&
        totals.sodiumMg + food.sodiumMg > sodiumTarget * 1.3;
    final wouldOvershootWater =
        waterTarget > 0 && totals.fluidMl + food.fluidMl > waterTarget * 1.3;
    final wouldOvershootProtein =
        proteinTarget > 0 &&
        totals.proteinG + food.proteinG > proteinTarget * 1.3;

    // Exception: when protein is critically unmet in after phase, allow
    // low-carb protein foods through
    final proteinCriticallyUnmet =
        phase == 'after' &&
        proteinTarget > 0 &&
        totals.proteinG < proteinTarget * 0.7;

    if (wouldOvershootCarbs &&
        totals.carbsG > carbsTarget * 0.7 &&
        !proteinCriticallyUnmet) {
      return true;
    }
    if (wouldOvershootSodium && totals.sodiumMg > sodiumTarget * 0.7) {
      return true;
    }
    if (wouldOvershootWater && totals.fluidMl > waterTarget * 0.7) {
      return true;
    }
    if (wouldOvershootProtein && totals.proteinG > proteinTarget * 0.9) {
      return true;
    }
    return false;
  }

  /// Calculate needed servings based on the primary deficit for this phase.
  double _calcNeededServings({
    required SolverFood food,
    required _RunningTotals totals,
    required SolverTargets targets,
    required String phase,
  }) {
    if (phase == 'after' && targets.proteinG > 0) {
      // After: prioritize protein then carbs
      final proteinDeficit = max(0.0, targets.proteinG - totals.proteinG);
      final carbsDeficit = max(0.0, targets.carbsG - totals.carbsG);

      if (proteinDeficit > 0 && food.proteinG > 0) {
        return (proteinDeficit / food.proteinG).ceilToDouble();
      } else if (carbsDeficit > 0 && food.carbsG > 0) {
        return (carbsDeficit / food.carbsG).ceilToDouble();
      }
    } else {
      // Before/during: focus on carbs
      final carbsDeficit = max(0.0, targets.carbsG - totals.carbsG);
      if (carbsDeficit > 0 && food.carbsG > 0) {
        return (carbsDeficit / food.carbsG).ceilToDouble();
      }
    }
    return 0;
  }

  /// Cap servings to prevent overshooting individual macro targets.
  double _capServings({
    required SolverFood food,
    required double neededServings,
    required _RunningTotals totals,
    required SolverTargets targets,
    required String phase,
  }) {
    var capped = neededServings;

    // Cap by carbs
    if (targets.carbsG > 0 && food.carbsG > 0) {
      final proteinCriticallyUnmet =
          phase == 'after' &&
          targets.proteinG > 0 &&
          totals.proteinG < targets.proteinG * 0.7;
      final carbMultiplier = proteinCriticallyUnmet ? 1.5 : 1.2;
      final maxCarbServings =
          (targets.carbsG * carbMultiplier - totals.carbsG) / food.carbsG;
      if (maxCarbServings <= 0) return 0;
      capped = min(capped, maxCarbServings);
    }

    // Cap by sodium
    if (targets.sodiumMg > 0 && food.sodiumMg > 0) {
      final maxSodiumServings =
          (targets.sodiumMg * 1.25 - totals.sodiumMg) / food.sodiumMg;
      capped = min(capped, max(1.0, maxSodiumServings));
    }

    // Cap by water
    if (targets.fluidMl > 0 && food.fluidMl > 0) {
      final maxWaterServings =
          (targets.fluidMl * 1.2 - totals.fluidMl) / food.fluidMl;
      capped = min(capped, max(1.0, maxWaterServings));
    }

    // Cap by protein
    if (targets.proteinG > 0 && food.proteinG > 0) {
      final maxProteinServings =
          (targets.proteinG * 1.2 - totals.proteinG) / food.proteinG;
      if (maxProteinServings <= 0) return 0;
      capped = min(capped, maxProteinServings);
    }

    return capped;
  }

  /// Round to nearest 0.5 increment (matching server's roundToIncrement).
  double _roundToHalf(double value) {
    if (value <= 0) return 0;
    final rounded = (value * 2).round() / 2;
    return max(0.5, rounded);
  }
}

/// Mutable running totals tracker used during the solve loop.
class _RunningTotals {
  double carbsG = 0;
  double proteinG = 0;
  double fatG = 0;
  double sodiumMg = 0;
  double fluidMl = 0;
}
