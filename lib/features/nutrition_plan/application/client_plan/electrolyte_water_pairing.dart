/// Electrolyte <-> water pairing invariant (post-selection pass).
///
/// Product rule (Lee, 2026-07-29): **an electrolyte mix / tablet / sodium
/// supplement is never recommended on its own — water always goes with it.**
///
/// Dart mirror of
/// `supabase/functions/_shared/nutrition/electrolyte-water-pairing.ts`. The
/// client fallback solver and the edge function must agree on what a valid
/// plan looks like, so the two files are kept deliberately parallel — change
/// both or neither.
///
/// Why a separate pass and not a solver constraint: fluid is a single pooled
/// target in every solver. "Total fluid is inside the band" is not the same
/// claim as "this electrolyte item has a drink next to it" — when the fluid
/// target is already covered by other picks (whole-food water, an earlier
/// gel), a dry electrolyte supplement can be appended alone and every solver
/// considers that valid.
///
/// **Detection keys off data-model fields, never display names**:
/// [FoodItemData.timingCategory] is [TimingCategory.electrolyte], which
/// `TimingCategory.fromFoodProperties` derives from the `template_foods`
/// columns `product_type` / `is_electrolyte` / `is_liquid`. An item is
/// *unpaired* only when it also delivers essentially no fluid of its own —
/// so an electrolyte drink mix that already carries its 500ml is
/// self-satisfying and is left alone (no double-counting of fluid).
///
/// **What satisfies the pairing**: any item in the phase that is a drinkable
/// fluid ([FoodItemData.isDrink]) delivering more than
/// [kPlainFluidEpsilonMl]. Water locked inside solid food (a banana's 88ml)
/// deliberately does not count — you cannot wash a salt tablet down with a
/// banana.
///
/// **Idempotent**: the appended water item is itself a drinkable fluid
/// carrier, so a second run sees the invariant already satisfied.
library;

import '../../domain/food_item_data.dart';
import '../../domain/solver_food.dart';

/// Fluid below this is treated as "carries no fluid of its own" (ml).
const double kPlainFluidEpsilonMl = 15;

/// How much water to pair with an otherwise-dry electrolyte item (ml).
/// ~8oz — the conventional "take this with a glass of water" dose.
const double kDefaultPairingVolumeMl = 250;

/// Never pair with less than this, or the recommendation is meaningless.
const double _minPairingVolumeMl = 100;

/// Why the invariant could not be enforced.
enum ElectrolytePairingConflict {
  /// A water source existed but adding any usable amount would breach the
  /// phase fluid ceiling.
  fluidCeiling,

  /// No plain-water candidate was available in the supplied pool.
  noWaterSource,
}

/// Outcome of one pairing pass over a phase.
class ElectrolytePairingResult {
  const ElectrolytePairingResult({
    required this.items,
    required this.changed,
    this.conflict,
  });

  /// The corrected item list (a new list; the input is never mutated).
  final List<FoodItemData> items;

  /// True when a water item was appended.
  final bool changed;

  /// Non-null when the invariant could NOT be enforced.
  final ElectrolytePairingConflict? conflict;
}

double _fluidOf(FoodItemData item) => item.nutritionalInfo?.fluids ?? 0;

/// Is this an electrolyte / sodium-supplement item, per the data model?
///
/// [TimingCategory.electrolyte] is derived from `product_type == 'supplement'`
/// or `is_electrolyte` — no display-name matching anywhere.
bool isElectrolyteItem(FoodItemData item) =>
    item.timingCategory == TimingCategory.electrolyte;

/// Does this item deliver drinkable fluid? Water bound up in solid food does
/// not count.
bool deliversDrinkableFluid(FoodItemData item) =>
    item.isDrink && _fluidOf(item) > kPlainFluidEpsilonMl;

/// C2 (docs/ssot/spec/domain/catalog-conventions.md, RULED Xuan 2026-09-01):
/// the pairing invariant covers every DRY item that requires water to
/// consume, not only electrolyte-flagged ones — the C1 zero-fluid set
/// includes carb drink mixes (nobody chews drink mix). Derivation is
/// app-side (no `requires_water` column): an electrolyte item, or any
/// drink-shaped item — [FoodItemData.isDrink], or a timing category the
/// catalog derives from liquid/drink product types. Twin:
/// `requiresWaterWhenDry` in electrolyte-water-pairing.ts.
bool _requiresWaterWhenDry(FoodItemData item) =>
    isElectrolyteItem(item) ||
    item.isDrink ||
    item.timingCategory == TimingCategory.fuelDrink ||
    item.timingCategory == TimingCategory.sipThroughout;

/// Requires-water items carrying essentially no fluid of their own (C2 —
/// name kept from the electrolyte-only era; scope is the full dry
/// requires-water set since catalog-conventions v1).
List<FoodItemData> unpairedElectrolyteItems(List<FoodItemData> items) => items
    .where(
      (i) => _requiresWaterWhenDry(i) && _fluidOf(i) <= kPlainFluidEpsilonMl,
    )
    .toList();

/// Catalog-conventions v1.1 / food-recommendation §6(e) (RULED Xuan,
/// 2026-09-03): the phase's plain-water requirement from solvent
/// dependencies. A row with a declared per-serving solvent minimum needs that
/// much water PER SERVING (label dilution — supersedes C2's flat constant);
/// an undeclared dry requires-water row falls back to
/// [kDefaultPairingVolumeMl] per serving. TS twin: `solventRequirementMl` in
/// electrolyte-water-pairing.ts.
double solventRequirementMl(List<FoodItemData> items) {
  var total = 0.0;
  for (final i in items) {
    final qty = i.numericQuantity ?? 1.0;
    if (qty <= 0) continue;
    final declared = i.solventMinMlPerServing;
    if (declared != null && declared > 0) {
      total += declared * qty;
    } else if (_requiresWaterWhenDry(i) &&
        _fluidOf(i) <= kPlainFluidEpsilonMl) {
      total += kDefaultPairingVolumeMl * qty;
    }
  }
  return total;
}

/// Plain drinkable water already on the plate (no carbs, no sodium). Counts
/// toward the solvent requirement — solvent water IS hydration water
/// (§6(e): no double demand).
double plainWaterMl(List<FoodItemData> items) {
  var total = 0.0;
  for (final i in items) {
    if (!deliversDrinkableFluid(i)) continue;
    final info = i.nutritionalInfo;
    if ((info?.carbs ?? 0) <= 0 && (info?.sodium ?? 0) <= 0) {
      total += _fluidOf(i);
    }
  }
  return total;
}

/// Cheap gate so callers can skip building a water pool when nothing is
/// wrong. True on the legacy C2 gate (dry requires-water item, no drink
/// alongside) OR when declared solvent minima exceed the plain water present.
bool needsWaterPairing(List<FoodItemData> items) {
  final hasDeclared = items.any(
    (i) =>
        (i.solventMinMlPerServing ?? 0) > 0 && (i.numericQuantity ?? 1) > 0,
  );
  if (hasDeclared) return solventRequirementMl(items) > plainWaterMl(items);
  if (unpairedElectrolyteItems(items).isEmpty) return false;
  return !items.any(deliversDrinkableFluid);
}

double _totalFluidMl(List<FoodItemData> items) =>
    items.fold(0.0, (sum, i) => sum + _fluidOf(i));

/// Round servings up / down to a 0.5 step.
double _ceilHalf(double v) => (v * 2).ceil() / 2;
double _floorHalf(double v) => (v * 2).floor() / 2;

/// Best plain-water candidate: fluid-bearing, no carbs, no sodium.
SolverFood? _pickWaterSource(List<SolverFood> pool) {
  final candidates =
      pool
          .where(
            (f) =>
                f.fluidMl > kPlainFluidEpsilonMl &&
                f.carbsG <= 0 &&
                f.sodiumMg <= 0,
          )
          .toList()
        ..sort((a, b) => b.fluidMl.compareTo(a.fluidMl));
  return candidates.isEmpty ? null : candidates.first;
}

/// Enforce "electrolyte always goes with water" over one phase's finished item
/// list. Returns a corrected list; [items] is not mutated.
///
/// [waterPool] is the phase's own solver pool (essential foods included). Pass
/// an empty list when unavailable — the pass then reports
/// [ElectrolytePairingConflict.noWaterSource] rather than inventing a food.
///
/// [fluidCeilingMl] is the phase's `water_high_ml`. The pass never overshoots
/// it: it fills from available headroom, and gives up honestly when there is
/// none.
ElectrolytePairingResult ensureElectrolyteWaterPairing(
  List<FoodItemData> items,
  List<SolverFood> waterPool, {
  double? fluidCeilingMl,
  double pairingVolumeMl = kDefaultPairingVolumeMl,
}) {
  final noop = ElectrolytePairingResult(
    items: List<FoodItemData>.from(items),
    changed: false,
  );

  final unpaired = unpairedElectrolyteItems(items);
  // v1.1 (§6(e)): declared solvent rows demand plain water regardless of
  // other drinks on the plate; with none, the legacy C2 gate stands.
  final declared = items
      .where(
        (i) =>
            (i.solventMinMlPerServing ?? 0) > 0 &&
            (i.numericQuantity ?? 1) > 0,
      )
      .toList();
  if (declared.isEmpty) {
    if (unpaired.isEmpty) return noop;
    if (items.any(deliversDrinkableFluid)) return noop;
  }

  final water = _pickWaterSource(waterPool);
  if (water == null) {
    return ElectrolytePairingResult(
      items: noop.items,
      changed: false,
      conflict: ElectrolytePairingConflict.noWaterSource,
    );
  }

  // Session-total requirement minus plain water already scheduled (solvent
  // water counts toward the hydration total — no double demand).
  final deficitMl = solventRequirementMl(items) - plainWaterMl(items);
  if (deficitMl <= 0) return noop;
  final wantedMl = deficitMl < _minPairingVolumeMl
      ? _minPairingVolumeMl
      : deficitMl;
  final ceiling = (fluidCeilingMl != null && fluidCeilingMl > 0)
      ? fluidCeilingMl
      : null;

  final headroom = ceiling == null
      ? double.infinity
      : ceiling - _totalFluidMl(items);
  final byHeadroom = ceiling == null
      ? double.infinity
      : _floorHalf(headroom / water.fluidMl);
  final servings = [
    _ceilHalf(wantedMl / water.fluidMl),
    byHeadroom,
    water.maxServings.toDouble(),
  ].reduce((a, b) => a < b ? a : b);

  if (servings < 0.5) {
    // Refuse to breach the ceiling. Unlike the server pass there is no
    // trim-a-fluid-carrier step here: the client fallback's pools are much
    // smaller and the zero-carb non-drink fluid carrier that step targets
    // does not occur in them, so it would be untestable dead code.
    return ElectrolytePairingResult(
      items: noop.items,
      changed: false,
      conflict: ElectrolytePairingConflict.fluidCeiling,
    );
  }

  // `toFoodItemData` derives isDrink/timingCategory from the pool row, and the
  // essential water row is not reliably flagged `is_liquid`. Force the drink
  // flags on: this is what makes the pass idempotent, since the appended item
  // must itself read as a drinkable fluid on the next run.
  final base = water.toFoodItemData(servings);
  final added = FoodItemData(
    id: base.id,
    name: base.name,
    quantity: base.quantity,
    imageAddress: base.imageAddress,
    description: base.description,
    nutritionalInfo: base.nutritionalInfo,
    displayName: base.displayName,
    displayNamePlural: base.displayNamePlural,
    servingSize: base.servingSize,
    isDrink: true,
    isIndivisible: base.isIndivisible,
    timingCategory: TimingCategory.sipThroughout,
  );

  return ElectrolytePairingResult(items: [...items, added], changed: true);
}
