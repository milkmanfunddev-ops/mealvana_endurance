/// Pre-workout food-composition suitability — the published entry point for
/// `docs/ssot/spec/fueling/pre-workout-food-composition.md` **v3** (RATIFIED
/// Xuan, 2026-08-05), built by the food-recommendation@v1 bundle (deferred
/// ledger item P10: the long-deferred composition runner).
///
/// Layer A (the §3 food groups + the §3.10 tier matrix) is the primary
/// recommendation; Layer B (the §5 hard gates) operationalises it for foods
/// the groups don't name. Precedence: if Layer B rejects a food Layer A rates
/// acceptable for the tier, Layer A wins and Layer B has a bug (§0).
///
/// Contract notes carried from the spec:
/// * Gates evaluate the FEEDING as assembled (summed macros), never per item (§4).
/// * `<=` is inclusive; gram-vs-ceiling comparisons carry a 0.001 g tolerance.
/// * Soft scores (§6 S1–S6) never reject — deliberately not implemented as
///   gates here. No percentage is evaluated at all (S2 stays advisory), so the
///   §4 "no percentage under 50 kcal" floor is honoured by construction.
/// * Gate evaluation ORDER is the oracle convention from the ratified vector
///   file (no order is specified by the SSOT): matrix → H4 → H5 → H6 → H1 →
///   H2 → H3 → H7.
/// * The H4 soft-solid allowance (t−30 to ~t−20, "not in the last 15 minutes")
///   is encoded as `leadTimeMin >= 20` — both vector pins (t−25 pass, t−10
///   fail) sit inside that reading. When the allowance waives H2's top-off
///   fibre line (the t−25 banana, §7 row 10) the assessment flags it as the
///   documented exception rather than passing silently (§11 check 1).
library;

/// The three feeding tiers (§2). Wire names: `meal` / `snack` / `top-off`.
enum FeedingTier {
  meal,
  snack,
  topOff;

  static FeedingTier fromWire(String wire) => switch (wire) {
        'meal' => FeedingTier.meal,
        'snack' => FeedingTier.snack,
        'top-off' || 'top_off' || 'top_up' => FeedingTier.topOff,
        _ => throw ArgumentError.value(wire, 'wire', 'unknown feeding tier'),
      };

  String get wireName =>
      switch (this) { meal => 'meal', snack => 'snack', topOff => 'top-off' };
}

/// Gut tolerance (§3.10). `unknown` resolves to `moderate` — the source
/// caution is conditional on frequent stomach problems, and absent evidence
/// of them the restrictive branch is not licensed.
enum GutTolerance {
  low,
  moderate,
  high,
  unknown;

  static GutTolerance fromWire(String wire) => switch (wire) {
        'low' => GutTolerance.low,
        'moderate' => GutTolerance.moderate,
        'high' => GutTolerance.high,
        'unknown' => GutTolerance.unknown,
        _ => throw ArgumentError.value(wire, 'wire', 'unknown gut tolerance'),
      };

  GutTolerance get resolved => this == unknown ? moderate : this;
}

/// The nine §3 food groups. Wire names match the `template_foods.food_group`
/// CHECK constraint (`G1`…`G9`, with `G4a`/`G4b`).
enum FoodGroup {
  g1,
  g2,
  g3,
  g4a,
  g4b,
  g5,
  g6,
  g7,
  g8,
  g9;

  static FoodGroup fromWire(String wire) => switch (wire) {
        'G1' => g1,
        'G2' => g2,
        'G3' => g3,
        'G4a' => g4a,
        'G4b' => g4b,
        'G5' => g5,
        'G6' => g6,
        'G7' => g7,
        'G8' => g8,
        'G9' => g9,
        _ => throw ArgumentError.value(wire, 'wire', 'unknown food group'),
      };

  String get wireName => switch (this) {
        g1 => 'G1',
        g2 => 'G2',
        g3 => 'G3',
        g4a => 'G4a',
        g4b => 'G4b',
        g5 => 'G5',
        g6 => 'G6',
        g7 => 'G7',
        g8 => 'G8',
        g9 => 'G9',
      };
}

/// Physical form of the feeding, for the H4 top-off form gate.
enum FeedingForm {
  solid,
  liquid,
  gel,
  chew;

  static FeedingForm fromWire(String wire) => switch (wire) {
        'solid' => solid,
        'liquid' => liquid,
        'gel' => gel,
        'chew' => chew,
        _ => throw ArgumentError.value(wire, 'wire', 'unknown feeding form'),
      };
}

/// §3.10 matrix ratings.
enum GroupRating { free, limited, avoid }

/// The seven §5 hard gates.
enum HardGate { h1, h2, h3, h4, h5, h6, h7 }

/// Everything the evaluator needs about one assembled feeding.
class FeedingInput {
  const FeedingInput({
    required this.tier,
    required this.bodyWeightKg,
    required this.gutTolerance,
    required this.fatG,
    required this.fibreG,
    required this.proteinG,
    required this.carbG,
    this.foodGroup,
    this.form = FeedingForm.solid,
    this.drinkCarbPct,
    this.practised = true,
    this.isBolus = false,
    this.withChaseWater = false,
    this.volumeMl,
    this.softLowResidue = false,
    this.leadTimeMin,
  });

  final FeedingTier tier;
  final double bodyWeightKg;
  final GutTolerance gutTolerance;
  final double fatG;
  final double fibreG;
  final double proteinG;
  final double carbG;

  /// The feeding's dominant §3 group; null when unclassified (Layer B only).
  final FoodGroup? foodGroup;
  final FeedingForm form;

  /// Carbohydrate concentration of a drink, % w/v — as mixed in the stomach
  /// for a gel-plus-chase bolus. Null when the feeding carries no drink.
  final double? drinkCarbPct;
  final bool practised;

  /// H6 single-bolus exemption inputs.
  final bool isBolus;
  final bool withChaseWater;
  final double? volumeMl;

  /// H4 soft-solid allowance inputs (ripe banana, applesauce pouch).
  final bool softLowResidue;
  final double? leadTimeMin;
}

/// The evaluator's verdict.
class FeedingAssessment {
  const FeedingAssessment._({
    required this.passes,
    this.failedGate,
    this.failedMatrix = false,
    this.fibreWaivedBySoftSolidAllowance = false,
  });

  const FeedingAssessment.pass({bool fibreWaived = false})
      : this._(passes: true, fibreWaivedBySoftSolidAllowance: fibreWaived);

  const FeedingAssessment.failGate(HardGate gate)
      : this._(passes: false, failedGate: gate);

  const FeedingAssessment.failMatrix()
      : this._(passes: false, failedMatrix: true);

  final bool passes;

  /// The first failing §5 gate under the oracle order, or null.
  final HardGate? failedGate;

  /// True when the rejection is the §3.10 tier matrix (a Layer A membership
  /// rule — it carries no H-number).
  final bool failedMatrix;

  /// True when the feeding passed only because the H4 soft-solid allowance
  /// waived H2's top-off fibre line (§11 check 1's documented banana case).
  /// A consumer must surface such a pass as a documented exception, never a
  /// silent one.
  final bool fibreWaivedBySoftSolidAllowance;
}

/// Gram tolerance for gram-vs-ceiling comparisons (`<=` is inclusive).
const double kCompositionToleranceG = 0.001;

/// H4 soft-solid allowance window: permitted from t−30 to about t−20,
/// explicitly "not in the last 15 minutes". Encoded as >= this many minutes
/// of lead time (the spec's tighter "to about t−20" reading).
const double kSoftSolidMinLeadMin = 20.0;

/// H6 sustained-drinking ceiling (top-off only), % carbohydrate.
const double kDrinkSustainedMaxPct = 8.0;

/// H6 single-bolus exemption: up to ~12 %, one serving <= 300 ml, with chase
/// water.
const double kDrinkBolusMaxPct = 12.0;
const double kDrinkBolusMaxVolumeMl = 300.0;

/// §5 H1 fat ceilings per feeding. Scale up only: `max(floor, per-kg)`.
double h1FatCapG(FeedingTier tier, double bodyWeightKg) => switch (tier) {
      FeedingTier.meal => _maxD(15.0, 0.22 * bodyWeightKg),
      FeedingTier.snack => _maxD(7.0, 0.10 * bodyWeightKg),
      FeedingTier.topOff => 2.0,
    };

/// §5 H2 fibre ceilings per feeding.
double h2FibreCapG(FeedingTier tier, double bodyWeightKg) => switch (tier) {
      FeedingTier.meal => _maxD(8.0, 0.12 * bodyWeightKg),
      FeedingTier.snack => _maxD(4.0, 0.06 * bodyWeightKg),
      FeedingTier.topOff => 2.0,
    };

/// §5 H3 protein ceilings per feeding. The top-off row reads "≈ 0", which is
/// not a gateable number — the ratified worked examples pass a top-off banana
/// (1.3 g) and applesauce pouch (0.2 g), so H3 is NOT evaluated at the
/// top-off: that tier's protein control is Layer A's (G5 = AVOID) plus H4/H5.
/// Returns null for the ungated tier.
double? h3ProteinCapG(FeedingTier tier, double bodyWeightKg) => switch (tier) {
      FeedingTier.meal => 0.4 * bodyWeightKg,
      FeedingTier.snack => 0.2 * bodyWeightKg,
      FeedingTier.topOff => null,
    };

double _maxD(double a, double b) => a > b ? a : b;

/// §3.10 — the tier matrix. G6's meal/snack cells are LIMITED but AVOID when
/// `gutTolerance == low` (`unknown` behaves as `moderate`).
GroupRating matrixRating(
  FoodGroup group,
  FeedingTier tier,
  GutTolerance gutTolerance,
) {
  final gut = gutTolerance.resolved;
  switch (group) {
    case FoodGroup.g1:
      return switch (tier) {
        FeedingTier.meal || FeedingTier.snack => GroupRating.free,
        FeedingTier.topOff => GroupRating.avoid, // solid, needs trituration
      };
    case FoodGroup.g2:
      return switch (tier) {
        FeedingTier.meal => GroupRating.free,
        FeedingTier.snack => GroupRating.limited,
        FeedingTier.topOff => GroupRating.avoid,
      };
    case FoodGroup.g3:
      return switch (tier) {
        FeedingTier.meal || FeedingTier.snack => GroupRating.free,
        FeedingTier.topOff => GroupRating.limited, // banana/purée to ~t−20
      };
    case FoodGroup.g4a:
    case FoodGroup.g4b:
      return GroupRating.free; // v3: permitted in every tier (§3.4)
    case FoodGroup.g5:
      return switch (tier) {
        FeedingTier.meal || FeedingTier.snack => GroupRating.limited,
        FeedingTier.topOff => GroupRating.avoid,
      };
    case FoodGroup.g6:
      return switch (tier) {
        FeedingTier.meal || FeedingTier.snack => gut == GutTolerance.low
            ? GroupRating.avoid
            : GroupRating.limited,
        FeedingTier.topOff => GroupRating.avoid,
      };
    case FoodGroup.g7:
      return switch (tier) {
        FeedingTier.meal => GroupRating.limited,
        _ => GroupRating.avoid,
      };
    case FoodGroup.g8:
    case FoodGroup.g9:
      return switch (tier) {
        FeedingTier.meal => GroupRating.limited,
        _ => GroupRating.avoid,
      };
  }
}

/// Whether the matrix makes the group selectable at all for the tier.
bool matrixAvailable(
  FoodGroup group,
  FeedingTier tier,
  GutTolerance gutTolerance,
) =>
    matrixRating(group, tier, gutTolerance) != GroupRating.avoid;

/// §11 check 9, first half: every group has a rating for all three tiers.
/// True by construction (the switch above is exhaustive); exposed so the
/// conformance suite asserts the property rather than trusting it.
bool get everyGroupRatedInEveryTier {
  for (final g in FoodGroup.values) {
    for (final t in FeedingTier.values) {
      matrixRating(g, t, GutTolerance.moderate);
    }
  }
  return true;
}

/// Named foods of §3.1–§3.9 → the group(s) that name them. §3.9 overlaps G8
/// and G3 deliberately ("a different axis, not a different shelf"), so a food
/// can carry more than one group — `apple juice` is the documented case
/// (pulp-free juice, G3; excess fructose, G9). §11 check 9's second half
/// ("belongs to exactly one group") is therefore unsatisfiable as written —
/// recorded as a spec defect by the ratified vector file's characterization
/// row, which this register reproduces truthfully.
const Map<String, Set<FoodGroup>> kNamedFoodGroups = {
  // G1 — refined starches
  'white rice': {FoodGroup.g1},
  'white bread': {FoodGroup.g1},
  'white toast': {FoodGroup.g1},
  'bagel': {FoodGroup.g1},
  'plain pasta': {FoodGroup.g1},
  'low-fibre cereal': {FoodGroup.g1},
  'rice cake': {FoodGroup.g1},
  'pretzels': {FoodGroup.g1},
  'plain crackers': {FoodGroup.g1},
  'flour tortilla': {FoodGroup.g1},
  'english muffin': {FoodGroup.g1},
  'plain pancakes': {FoodGroup.g1},
  'plain waffles': {FoodGroup.g1},
  // G2 — cooked starchy vegetables
  'potato': {FoodGroup.g2},
  'sweet potato': {FoodGroup.g2},
  'cooked seedless vegetables': {FoodGroup.g2},
  // G3 — low-residue fruit
  'ripe banana': {FoodGroup.g3},
  'applesauce': {FoodGroup.g3},
  'fruit puree': {FoodGroup.g3},
  'canned fruit': {FoodGroup.g3},
  'pulp-free juice': {FoodGroup.g3},
  'melon': {FoodGroup.g3},
  // deliberate G3×G9 overlap (§3.9 names apple/pear as excess-fructose while
  // §3.3 admits pulp-free juice):
  'apple juice': {FoodGroup.g3, FoodGroup.g9},
  // G4a — sugars & syrups
  'honey': {FoodGroup.g4a},
  'jam': {FoodGroup.g4a},
  'jelly': {FoodGroup.g4a},
  'maple syrup': {FoodGroup.g4a},
  'table sugar': {FoodGroup.g4a},
  // G4b — engineered sports carbohydrate
  'sports drink': {FoodGroup.g4b},
  'sports drink powder': {FoodGroup.g4b},
  'energy gel': {FoodGroup.g4b},
  'energy chews': {FoodGroup.g4b},
  // G5 — lean protein
  'egg white': {FoodGroup.g5},
  'skinless poultry': {FoodGroup.g5},
  'white fish': {FoodGroup.g5},
  'lean deli turkey': {FoodGroup.g5},
  'whey isolate': {FoodGroup.g5},
  'plant protein isolate': {FoodGroup.g5},
  // G6 — dairy & alternatives
  'skim milk': {FoodGroup.g6},
  'low-fat yoghurt': {FoodGroup.g6},
  'lactose-free milk': {FoodGroup.g6},
  'fortified plant milk': {FoodGroup.g6},
  // G7 — added fats
  'butter': {FoodGroup.g7},
  'oil': {FoodGroup.g7},
  'cream cheese': {FoodGroup.g7},
  'nut butter': {FoodGroup.g7},
  'peanut butter': {FoodGroup.g7},
  'avocado': {FoodGroup.g7},
  'cheese': {FoodGroup.g7},
  'full-fat dairy': {FoodGroup.g7},
  'fatty meat': {FoodGroup.g7},
  'fried food': {FoodGroup.g7},
  'chocolate spread': {FoodGroup.g7},
  // G8 — high-residue whole foods
  'whole-grain bread': {FoodGroup.g8},
  'bran cereal': {FoodGroup.g8},
  'brown rice': {FoodGroup.g8},
  'legumes': {FoodGroup.g8, FoodGroup.g9}, // §3.9 GOS names legumes too
  'raw vegetables': {FoodGroup.g8},
  'raw berries': {FoodGroup.g8},
  'popcorn': {FoodGroup.g8},
  'whole nuts': {FoodGroup.g7, FoodGroup.g8}, // named by both §3.7 and §3.8
  // G9 — high-FODMAP
  'onion': {FoodGroup.g9},
  'garlic': {FoodGroup.g9},
  'apple': {FoodGroup.g3, FoodGroup.g9},
  'mango': {FoodGroup.g9},
  'pear': {FoodGroup.g9},
  'stone fruit': {FoodGroup.g9},
  'dried fruit': {FoodGroup.g9},
  'sorbitol': {FoodGroup.g9},
  'high-fructose corn syrup': {FoodGroup.g9},
};

/// The group(s) a §3-named food belongs to; empty when the spec doesn't name
/// it.
Set<FoodGroup> groupsForFood(String name) =>
    kNamedFoodGroups[name.trim().toLowerCase()] ?? const <FoodGroup>{};

/// Evaluate one assembled feeding against Layer A (§3.10) and the §5 hard
/// gates, in the oracle order: matrix → H4 → H5 → H6 → H1 → H2 → H3 → H7.
FeedingAssessment assessFeeding(FeedingInput f) {
  const tol = kCompositionToleranceG;

  // §3.10 tier matrix (Layer A membership). Unclassified feedings skip it.
  final group = f.foodGroup;
  if (group != null && !matrixAvailable(group, f.tier, f.gutTolerance)) {
    return const FeedingAssessment.failMatrix();
  }

  // H4 — top-off form gate. Liquids, gels and chews need no trituration; a
  // solid passes only as a soft low-residue item inside the allowance window.
  var fibreWaived = false;
  if (f.tier == FeedingTier.topOff && f.form == FeedingForm.solid) {
    final lead = f.leadTimeMin;
    final inWindow =
        f.softLowResidue && lead != null && lead >= kSoftSolidMinLeadMin;
    if (!inWindow) return const FeedingAssessment.failGate(HardGate.h4);
    // The allowance is made explicitly against H2's 2 g top-off line (§5 H4):
    // when the fibre exceeds it, the pass is the documented exception.
    fibreWaived = f.fibreG > h2FibreCapG(f.tier, f.bodyWeightKg) + tol;
  }

  // H5 — the top-off must deliver carbohydrate.
  if (f.tier == FeedingTier.topOff && f.carbG <= tol) {
    return const FeedingAssessment.failGate(HardGate.h5);
  }

  // H6 — drink carbohydrate concentration, scoped to the top-off tier only.
  if (f.tier == FeedingTier.topOff && f.drinkCarbPct != null) {
    final pct = f.drinkCarbPct!;
    final bolusOk = f.isBolus &&
        f.withChaseWater &&
        (f.volumeMl ?? double.infinity) <= kDrinkBolusMaxVolumeMl + tol &&
        pct <= kDrinkBolusMaxPct + tol;
    final sustainedOk = pct <= kDrinkSustainedMaxPct + tol;
    if (!bolusOk && !sustainedOk) {
      return const FeedingAssessment.failGate(HardGate.h6);
    }
  }

  // H1 — fat ceiling.
  if (f.fatG > h1FatCapG(f.tier, f.bodyWeightKg) + tol) {
    return const FeedingAssessment.failGate(HardGate.h1);
  }

  // H2 — fibre ceiling (unless the soft-solid allowance waived it above).
  if (!fibreWaived && f.fibreG > h2FibreCapG(f.tier, f.bodyWeightKg) + tol) {
    return const FeedingAssessment.failGate(HardGate.h2);
  }

  // H3 — protein ceiling (meal/snack only; the top-off's "≈ 0" is not a
  // gateable number — see [h3ProteinCapG]).
  final proteinCap = h3ProteinCapG(f.tier, f.bodyWeightKg);
  if (proteinCap != null && f.proteinG > proteinCap + tol) {
    return const FeedingAssessment.failGate(HardGate.h3);
  }

  // H7 — nothing untried.
  if (!f.practised) return const FeedingAssessment.failGate(HardGate.h7);

  return FeedingAssessment.pass(fibreWaived: fibreWaived);
}
