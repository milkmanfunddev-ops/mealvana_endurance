import 'package:flutter/foundation.dart';

import '../../onboarding/domain/allergy.dart';
import '../../onboarding/domain/dietary_preference.dart';
import 'before_sub_phase.dart';
import 'during_filter_options.dart';
import 'formula_phase.dart';

/// Immutable filter state for the Formula Library browse screen.
///
/// PR 1 of Formula Kit owns this state in `FormulaLibraryController`. PR 1
/// surfaces:
///   - Phase tabs (Before / During)
///   - Per-phase chip row (Timing for Before; Activity + Duration for During)
///   - More Filters sheet (digestion speed, gut training level, per-restriction
///     dietary-profile chips)
///
/// The dietary-profile section renders one chip per item in the user's profile
/// (each allergy + the diet, if set). Each chip is selected by default — the
/// user can deselect individual restrictions via `bypassedAllergies` /
/// `bypassedDiets`. Bypassing is **opt-in**; the default empty sets mean every
/// restriction is being applied.
@immutable
class FormulaFilterState {
  const FormulaFilterState({
    this.phase = FormulaPhase.before,
    this.beforeSubPhase,
    this.beforeDigestionSpeed,
    this.duringActivity,
    this.duringDuration,
    this.duringGutLevel,
    this.bypassedAllergies = const {},
    this.bypassedDiets = const {},
  });

  final FormulaPhase phase;

  // ---- Before-only fields ----
  final BeforeSubPhase? beforeSubPhase;
  final FormulaDigestionSpeed? beforeDigestionSpeed;

  // ---- During-only fields ----
  final DuringActivity? duringActivity;
  final DuringDuration? duringDuration;
  final DuringGutLevel? duringGutLevel;

  // ---- Cross-phase: per-restriction bypass ----
  /// Allergies from the user profile that the user has explicitly opted out of
  /// for this session. The corresponding chips render as **unselected** in the
  /// More Filters sheet; formulas containing these allergens will be shown.
  final Set<Allergy> bypassedAllergies;

  /// Diets from the user profile that the user has explicitly opted out of for
  /// this session. Today the profile only carries a single dietary preference,
  /// but the set keeps room for the V2 multi-select diet picker.
  final Set<DietaryPreference> bypassedDiets;

  int get activeChipFilterCount {
    if (phase == FormulaPhase.before) {
      return beforeSubPhase == null ? 0 : 1;
    }
    return (duringActivity == null ? 0 : 1) +
        (duringDuration == null ? 0 : 1);
  }

  /// Count of "non-default" More Filters fields, used for the badge on the
  /// More Filters button. The dietary section contributes 1 if any
  /// restriction has been bypassed (regardless of how many).
  int get activeMoreFilterCount {
    final phaseSpecific = phase == FormulaPhase.before
        ? (beforeDigestionSpeed == null ? 0 : 1)
        : (duringGutLevel == null ? 0 : 1);
    final dietary =
        (bypassedAllergies.isEmpty && bypassedDiets.isEmpty) ? 0 : 1;
    return phaseSpecific + dietary;
  }

  FormulaFilterState copyWith({
    FormulaPhase? phase,
    BeforeSubPhase? Function()? beforeSubPhase,
    FormulaDigestionSpeed? Function()? beforeDigestionSpeed,
    DuringActivity? Function()? duringActivity,
    DuringDuration? Function()? duringDuration,
    DuringGutLevel? Function()? duringGutLevel,
    Set<Allergy>? bypassedAllergies,
    Set<DietaryPreference>? bypassedDiets,
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
      bypassedAllergies: bypassedAllergies ?? this.bypassedAllergies,
      bypassedDiets: bypassedDiets ?? this.bypassedDiets,
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
        setEquals(other.bypassedAllergies, bypassedAllergies) &&
        setEquals(other.bypassedDiets, bypassedDiets);
  }

  @override
  int get hashCode => Object.hash(
        phase,
        beforeSubPhase,
        beforeDigestionSpeed,
        duringActivity,
        duringDuration,
        duringGutLevel,
        Object.hashAllUnordered(bypassedAllergies),
        Object.hashAllUnordered(bypassedDiets),
      );
}
