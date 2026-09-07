/// Preference score constants for the client-side greedy solver.
///
/// These match the server-side constants in `constants.ts` to maintain
/// consistent food selection priority between edge function and fallback.
/// Unused since the 2026-07-29 food-source policy: `user_foods` are no longer
/// a plan-generation source (see [ClientFoodPoolService]). Kept only so the
/// score ladder still reads as the server's. Do not wire it back up.
const int kPrefScoreUserFood = 300;
const int kPrefScoreLiked = 200;
const int kPrefScoreWilling = 80;
const int kPrefScoreEssential = 50;
const int kPrefScoreNeutral = 20;

/// A single food selection produced by the greedy solver.
class SolverSelection {
  const SolverSelection({
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
    required this.fluidMl,
    required this.calories,
    this.displayName,
    this.displayNamePlural,
    this.description,
    this.imageAddress,
    this.servingSize,
    this.servingUnit,
    this.isDrink = false,
    this.isIndivisible = false,
    this.isLiquid = false,
    this.isElectrolyte = false,
    this.productType,
    this.solventMinMl,
  });

  final String foodId;
  final String foodName;
  final double quantity;

  // Total nutrition (per_serving * quantity)
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double fluidMl;
  final int calories;

  // Display metadata
  final String? displayName;
  final String? displayNamePlural;
  final String? description;
  final String? imageAddress;
  final String? servingSize;
  final String? servingUnit;
  final bool isDrink;
  final bool isIndivisible;
  final bool isLiquid;
  final bool isElectrolyte;
  final String? productType;

  /// Catalog-conventions v1.1 (food-recommendation §6(e)): per-serving
  /// solvent-water minimum carried from the catalog row, so the solver's
  /// pick-time solvent accounting can read it off the pick. Null =
  /// undeclared.
  final double? solventMinMl;
}

/// Macro targets for a single phase, used by the greedy solver.
class SolverTargets {
  const SolverTargets({
    required this.carbsG,
    this.proteinG = 0,
    this.fatG = 0,
    this.sodiumMg = 0,
    this.fluidMl = 0,
    this.sodiumLowMg,
    this.sodiumHighMg,
    this.carbsLowG,
    this.carbsHighG,
    this.fluidLowMl,
    this.fluidHighMl,
  });

  final double carbsG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double fluidMl;
  final double? sodiumLowMg;
  final double? sodiumHighMg;
  final double? carbsLowG;
  final double? carbsHighG;
  final double? fluidLowMl;
  final double? fluidHighMl;
}
