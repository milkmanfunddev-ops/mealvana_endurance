/// View data for the pre-workout BEFORE card and its three components.
///
/// SSOT: `docs/ssot/spec/design/surfaces/pre-workout-before-card.md` v1 and
/// `components/{fuel-stat,feeding-card,hydration-check}.md` v1. Pure value
/// types — no widgets, no arithmetic beyond what the surface owns (B-1: the
/// delivered sum). Built by `PreWorkoutBeforeCardAssembler`.
library;

import 'pre_workout_feeding_labels.dart';
import 'pre_workout_hydration_check.dart';

/// Which summary quantity a fuel-stat shows.
enum FuelQuantity { carbs, fluids, sodium }

/// fuel-stat state model: `mode ∈ { TARGETED, NO_TARGET, NONE }`.
enum FuelStatMode {
  /// A target and (usually) a band exist.
  targeted,

  /// The gate path: `fluidMl: null`, `regime: gated` — "we're not stating a
  /// target". Renders "No fluid target for this session".
  noTarget,

  /// The fasted path: `tiers: []`, `targetBasis: none` — "there is nothing to
  /// recommend". Renders "No carbs this session".
  none,
}

/// One summary quantity with its optional band (fuel-stat v1).
///
/// All figures are already in display units (whole g / oz / mg — M-5, R-01).
/// The engine values are exact; conversion happens once, in the assembler.
class FuelStatData {
  const FuelStatData({
    required this.quantity,
    required this.mode,
    required this.delivered,
    this.target,
    this.bandLow,
    this.bandHigh,
  });

  final FuelQuantity quantity;
  final FuelStatMode mode;

  /// Σ over every feeding card's rows (surface B-1).
  final int delivered;

  /// The engine target (`carbsG` / `fluidMl`) — the *suggested* marker.
  final int? target;

  /// Band ends (`carbsLowG/HighG`, `fluidLowMl/HighMl`).
  final int? bandLow;
  final int? bandHigh;

  /// Unit suffix for the figure.
  String get unit {
    switch (quantity) {
      case FuelQuantity.carbs:
        return 'g';
      case FuelQuantity.fluids:
        return 'oz';
      case FuelQuantity.sodium:
        return 'mg';
    }
  }

  /// Uppercase column label.
  String get label {
    switch (quantity) {
      case FuelQuantity.carbs:
        return 'CARBS';
      case FuelQuantity.fluids:
        return 'FLUIDS';
      case FuelQuantity.sodium:
        return 'SODIUM';
    }
  }

  /// Whether a rail, ends and markers render. Sodium never (F-2); no-number
  /// modes never; a `[0, 0]` carb band is suppressed (carbs † rule, t = 0).
  bool get showBand {
    if (quantity == FuelQuantity.sodium) return false;
    if (mode != FuelStatMode.targeted) return false;
    if (bandLow == null || bandHigh == null || target == null) return false;
    if (bandLow == 0 && bandHigh == 0) return false;
    return true;
  }

  /// Whether the figure renders at all (the no-number modes show a line).
  bool get showFigure => mode == FuelStatMode.targeted;

  /// M-2: signalling is one-way for fluid (above the ceiling only), two-way
  /// for carbs; never for sodium. Only the DELIVERED marker signals (M-3: the
  /// suggested marker on a band end is not an out-of-band state).
  bool get deliveredOutOfBand {
    if (!showBand) return false;
    final above = delivered > bandHigh!;
    final below = delivered < bandLow!;
    switch (quantity) {
      case FuelQuantity.carbs:
        return above || below;
      case FuelQuantity.fluids:
        return above;
      case FuelQuantity.sodium:
        return false;
    }
  }

  /// The no-number line for the two absent modes (F-1).
  String? get absentLine {
    switch (mode) {
      case FuelStatMode.noTarget:
        return 'No fluid target for this session';
      case FuelStatMode.none:
        return 'No carbs this session';
      case FuelStatMode.targeted:
        return null;
    }
  }

  /// Position of [value] along the band as a fraction 0..1 (clamped).
  double bandFraction(int value) {
    if (!showBand) return 0;
    final span = (bandHigh! - bandLow!);
    if (span <= 0) return 0;
    return ((value - bandLow!) / span).clamp(0.0, 1.0);
  }
}

/// The icon family a food row uses (the rendering's four glyphs).
enum FeedingRowIcon { drop, bowl, bar, chew }

/// One food row on a feeding card (FC-5).
class FeedingFoodRow {
  const FeedingFoodRow({
    required this.id,
    required this.category,
    required this.name,
    required this.quantity,
    required this.step,
    required this.cap,
    required this.carbsG,
    required this.fluidMl,
    required this.sodiumMg,
    required this.icon,
    this.note,
  });

  /// The plan food id (what the controller edits).
  final String id;

  /// The controller category this row lives in (e.g. `before_run:snack`).
  final String category;

  final String name;

  /// Current quantity (the leading number of the plan's quantity string).
  final double quantity;

  /// Stepper increment — the row's own (0.5 for divisible items, 1 for
  /// indivisible ones).
  final double step;

  /// Stepper ceiling — the row's own.
  final double cap;

  /// Delivered macros at the current quantity (observations, FC-5).
  final double carbsG;
  final double fluidMl;
  final double sodiumMg;

  final FeedingRowIcon icon;

  /// A tag under the name ("added by hydration check").
  final String? note;

  bool get isHydrationCheckRow => note != null;
}

/// One pre-workout feeding (feeding-card v1).
class FeedingCardData {
  const FeedingCardData({
    required this.tier,
    required this.category,
    required this.title,
    required this.windowLabel,
    required this.rows,
    required this.carbsDelivered,
    required this.fluidOz,
    required this.hostsHydrationCheck,
  });

  final PreWorkoutFeedingTier tier;

  /// Controller category for add/edit callbacks (`before_run:snack`).
  final String category;

  /// "Pre-Run Meal" · "Pre-Workout Snack" / "Light Meal" · "Top-Off".
  final String title;

  /// Uppercase window line.
  final String windowLabel;

  final List<FeedingFoodRow> rows;

  /// Header DELIVERED carbs (FC-2) — Σ this card's rows; null on the fasted
  /// path (the card carries no carb figure, FC-4).
  final int? carbsDelivered;

  /// The tier's engine fluid in oz (`fluidTiers[].fluidMl`), null when this
  /// tier carries no fluid.
  final int? fluidOz;

  /// FC-6: the hydration-check row is the first row of the SNACK card on
  /// ≥ 2 h plans.
  final bool hostsHydrationCheck;

  /// Collapsed "foods line" — the row names joined.
  String get foodsLine => rows
      .map((r) => r.name.replaceAll(RegExp(r' \((cups|packets)\)$'), ''))
      .join(' + ');
}

/// The hydration check's presentation state (hydration-check v1).
///
/// The result copy is DERIVED from the current plan every build — never
/// chosen at answer time and stored — so it cannot go stale after the
/// athlete edits rows (ops bug
/// 2026-08-26-hydration-check-result-copy-stale-after-edits):
///
/// * DARK / NOT_YET with the tagged water row present → "An 8 oz water entry
///   was added…"
/// * DARK / NOT_YET, no row, delivered ≥ target → "…already covered…"
/// * DARK / NOT_YET, no row, delivered < target (the athlete removed the row
///   or stepped a drink down) → the state-independent sentence only:
///   "Your fluid target rises to N oz."
class HydrationCheckViewState {
  const HydrationCheckViewState({
    required this.answer,
    required this.targetOz,
    required this.deliveredOz,
    required this.waterRowPresent,
  });

  /// NONE = the TO-DO state.
  final HydrationCheckAnswer answer;

  /// The current fluid target in oz — interpolated into the result copy
  /// (`round(fluidMl / 29.5735)`).
  final int targetOz;

  /// Σ fluid over every feeding row, in oz, as of THIS build.
  final int deliveredOz;

  /// Whether the tagged "added by hydration check" row is on the plan NOW.
  final bool waterRowPresent;

  bool get isAnswered => answer != HydrationCheckAnswer.none;

  /// The DARK / NOT_YET "already covered" branch, evaluated now.
  bool get alreadyCovered =>
      answer.raisesTarget && !waterRowPresent && deliveredOz >= targetOz;

  /// DARK / NOT_YET where the row is gone and the plan no longer covers the
  /// target — neither ratified sentence is true, so only the target line
  /// renders.
  bool get shortfallWithoutRow =>
      answer.raisesTarget && !waterRowPresent && deliveredOz < targetOz;

  /// The short status after the head: "target raised to 25 oz".
  String get resultShort {
    switch (answer) {
      case HydrationCheckAnswer.pale:
        return 'target unchanged';
      case HydrationCheckAnswer.dark:
      case HydrationCheckAnswer.notYet:
        return alreadyCovered
            ? 'target $targetOz oz, already covered'
            : 'target raised to $targetOz oz';
      case HydrationCheckAnswer.notSure:
        return 'no change to your target';
      case HydrationCheckAnswer.none:
        return '';
    }
  }

  /// "Dark · target raised to 25 oz".
  String get resultLine => '${answer.resultHead} · $resultShort';

  String get _raisedBody {
    final rises = 'Your fluid target rises to $targetOz oz.';
    if (waterRowPresent) {
      return '$rises An 8 oz water entry was added to help you get there — '
          'adjust it like any other item.';
    }
    if (alreadyCovered) {
      return '$rises What you already have planned covers it, so nothing '
          'was added.';
    }
    return rises;
  }

  /// The result body (copy register, hydration-check v1), derived now.
  String get resultBody {
    switch (answer) {
      case HydrationCheckAnswer.pale:
        return "You're hydrated. Your fluid target is unchanged.";
      case HydrationCheckAnswer.dark:
        return _raisedBody;
      case HydrationCheckAnswer.notYet:
        return 'Treated as dark for now — update after you go. $_raisedBody';
      case HydrationCheckAnswer.notSure:
        return 'Recorded with no change to your target. Check when you can '
            'and update your answer.';
      case HydrationCheckAnswer.none:
        return '';
    }
  }
}

/// The ratified copy register (hydration-check v1) — ships as-is.
abstract final class HydrationCheckCopy {
  static const String title = 'Hydration check';
  static const String subtitle = 'adjusts your fluid target';
  static const String todo = 'TO-DO';
  static const String question = 'Is your urine pale yellow right now?';
  static const String timing =
      "Do this about two hours before you start, once you've finished your "
      'pre-run meal.';
  static const String caveat =
      'On a multivitamin or B-complex? It turns urine yellow on its own — '
      "don't read that as dark — choose Not sure.";
  static const String changeAnswer = 'Change answer';
  static const String optionPale = 'Pale yellow';
  static const String optionDark = 'Dark';
  static const String optionNotYet = "Haven't gone yet";
  static const String optionNotSure = 'Not sure';
  static const String addedRowNote = 'added by hydration check';
  static const String addedRowName = 'Water (cups)';
}

/// The whole BEFORE card (surface v1): one summary row above the ordered
/// feeding cards.
class PreWorkoutBeforeCardData {
  const PreWorkoutBeforeCardData({
    required this.carbs,
    required this.fluids,
    required this.sodium,
    required this.feedings,
    required this.hydrationCheck,
  });

  final FuelStatData carbs;
  final FuelStatData fluids;
  final FuelStatData sodium;

  /// Furthest-out first.
  final List<FeedingCardData> feedings;

  /// Null when the control is ABSENT by rule (sub-2 h plans; gated plans —
  /// deferred-ledger P1).
  final HydrationCheckViewState? hydrationCheck;
}
