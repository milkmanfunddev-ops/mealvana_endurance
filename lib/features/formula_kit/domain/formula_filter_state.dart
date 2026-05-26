import 'package:flutter/foundation.dart';

import '../../onboarding/domain/allergy.dart';
import '../../onboarding/domain/dietary_preference.dart';
import 'after_filter_options.dart';
import 'before_sub_phase.dart';
import 'during_filter_options.dart';
import 'formula_phase.dart';

/// Immutable filter state for the Formula Library browse screen.
///
/// PR 1 of Formula Kit owns this state in `FormulaLibraryController`. PR 1
/// surfaces:
///   - Phase tabs (Before / During)
///   - Per-phase chip row (Timing for Before; Activity + Duration for During)
///   - More Filters sheet (digestion speed, gut training level, per-allergen
///     and per-diet filter chips)
///
/// The dietary-profile section shows **all 9 allergen types** plus the
/// active dietary preference (if set). A chip is **selected** when its
/// allergen / diet is in [activeAllergyFilters] / [activeDietFilters] —
/// meaning formulas containing that restriction will be hidden. On first
/// load the controller seeds the active sets from the user profile so the
/// out-of-the-box experience matches the user's allergies, but the user can
/// add or remove any allergen for this session.
@immutable
class FormulaFilterState {
  const FormulaFilterState({
    this.phase = FormulaPhase.before,
    this.beforeSubPhase,
    this.beforeDigestionSpeed,
    this.duringActivity,
    this.duringDuration,
    this.duringGutLevel,
    this.afterTravelFriendliness = defaultAfterTravelFriendliness,
    this.activeAllergyFilters = const {},
    this.activeDietFilters = const {},
    this.pinnedOnly = false,
  });

  /// Default value for [afterTravelFriendliness] — all three travel buckets
  /// selected, i.e. no filter active. The After chip row is a multi-select
  /// rather than the Before/During single-select pattern.
  static const Set<TravelFriendliness> defaultAfterTravelFriendliness = {
    TravelFriendliness.inBag,
    TravelFriendliness.coolerFriendly,
    TravelFriendliness.homeOnly,
  };

  final FormulaPhase phase;

  // ---- Before-only fields ----
  final BeforeSubPhase? beforeSubPhase;
  final FormulaDigestionSpeed? beforeDigestionSpeed;

  // ---- During-only fields ----
  final DuringActivity? duringActivity;
  final DuringDuration? duringDuration;
  final DuringGutLevel? duringGutLevel;

  // ---- After-only fields ----
  /// Multi-select set of travel buckets to include. Defaults to all three
  /// (see [defaultAfterTravelFriendliness]); the user removes a bucket by
  /// toggling its chip off. Templates whose `travelFriendliness` is null
  /// are always shown (no scoped value to filter on).
  final Set<TravelFriendliness> afterTravelFriendliness;

  // ---- Cross-phase: dietary filters ----
  /// Allergies that are currently being filtered out. Formulas whose allergens
  /// intersect this set are hidden from the library.
  final Set<Allergy> activeAllergyFilters;

  /// Diets being filtered against. A formula is hidden if any active diet
  /// appears in its `excluded_diets`.
  final Set<DietaryPreference> activeDietFilters;

  /// When `true`, the library shows only formulas the user has pinned (still
  /// scoped to the active [phase] and gated by the other chip / dietary
  /// filters — pinned-only stacks, it doesn't override). Driven by the
  /// AppBar pin toggle.
  final bool pinnedOnly;

  int get activeChipFilterCount {
    if (phase == FormulaPhase.before) {
      return beforeSubPhase == null ? 0 : 1;
    }
    if (phase == FormulaPhase.during) {
      return (duringActivity == null ? 0 : 1) +
          (duringDuration == null ? 0 : 1);
    }
    // After: travel-friendliness is a single multi-select chip row; counts as
    // "active" whenever the user has narrowed away from the all-three default.
    return setEquals(
      afterTravelFriendliness,
      defaultAfterTravelFriendliness,
    )
        ? 0
        : 1;
  }

  FormulaFilterState copyWith({
    FormulaPhase? phase,
    BeforeSubPhase? Function()? beforeSubPhase,
    FormulaDigestionSpeed? Function()? beforeDigestionSpeed,
    DuringActivity? Function()? duringActivity,
    DuringDuration? Function()? duringDuration,
    DuringGutLevel? Function()? duringGutLevel,
    Set<TravelFriendliness>? afterTravelFriendliness,
    Set<Allergy>? activeAllergyFilters,
    Set<DietaryPreference>? activeDietFilters,
    bool? pinnedOnly,
  }) {
    return FormulaFilterState(
      phase: phase ?? this.phase,
      beforeSubPhase:
          beforeSubPhase != null ? beforeSubPhase() : this.beforeSubPhase,
      beforeDigestionSpeed: beforeDigestionSpeed != null
          ? beforeDigestionSpeed()
          : this.beforeDigestionSpeed,
      duringActivity:
          duringActivity != null ? duringActivity() : this.duringActivity,
      duringDuration:
          duringDuration != null ? duringDuration() : this.duringDuration,
      duringGutLevel:
          duringGutLevel != null ? duringGutLevel() : this.duringGutLevel,
      afterTravelFriendliness:
          afterTravelFriendliness ?? this.afterTravelFriendliness,
      activeAllergyFilters:
          activeAllergyFilters ?? this.activeAllergyFilters,
      activeDietFilters: activeDietFilters ?? this.activeDietFilters,
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FormulaFilterState &&
        other.phase == phase &&
        other.beforeSubPhase == beforeSubPhase &&
        other.beforeDigestionSpeed == beforeDigestionSpeed &&
        other.duringActivity == duringActivity &&
        other.duringDuration == duringDuration &&
        other.duringGutLevel == duringGutLevel &&
        setEquals(other.afterTravelFriendliness, afterTravelFriendliness) &&
        setEquals(other.activeAllergyFilters, activeAllergyFilters) &&
        setEquals(other.activeDietFilters, activeDietFilters) &&
        other.pinnedOnly == pinnedOnly;
  }

  @override
  int get hashCode => Object.hash(
        phase,
        beforeSubPhase,
        beforeDigestionSpeed,
        duringActivity,
        duringDuration,
        duringGutLevel,
        Object.hashAllUnordered(afterTravelFriendliness),
        Object.hashAllUnordered(activeAllergyFilters),
        Object.hashAllUnordered(activeDietFilters),
        pinnedOnly,
      );
}
