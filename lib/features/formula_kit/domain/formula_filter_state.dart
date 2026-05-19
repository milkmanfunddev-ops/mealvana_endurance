import 'package:flutter/foundation.dart';

import 'before_sub_phase.dart';
import 'during_filter_options.dart';
import 'formula_phase.dart';

/// Immutable filter state for the Formula Library browse screen.
///
/// PR 1 of Formula Kit owns this state in `FormulaLibraryController`. PR 1
/// surfaces:
///   - Phase tabs (Before / During)
///   - Per-phase chip row (Timing for Before; Activity + Duration for During)
///   - More Filters sheet (digestion speed, gut training level,
///     "ignore my dietary profile" toggle)
///
/// PR 3 / PR 5 will extend this object via `copyWith` to add the
/// "Show favorites only" chip and multi-select diet / allergen pickers — the
/// field set below is the minimum required for the V1 browse-only slice.
@immutable
class FormulaFilterState {
  const FormulaFilterState({
    this.phase = FormulaPhase.before,
    this.beforeSubPhase,
    this.beforeDigestionSpeed,
    this.duringActivity,
    this.duringDuration,
    this.duringGutLevel,
    this.ignoreDietaryProfile = false,
  });

  final FormulaPhase phase;

  // ---- Before-only fields ----
  final BeforeSubPhase? beforeSubPhase;
  final FormulaDigestionSpeed? beforeDigestionSpeed;

  // ---- During-only fields ----
  final DuringActivity? duringActivity;
  final DuringDuration? duringDuration;
  final DuringGutLevel? duringGutLevel;

  // ---- Cross-phase ----
  /// When true, the user's dietary preferences / allergens are ignored when
  /// filtering the list. Controlled by the "Show all" toggle in the More
  /// Filters sheet (PR 1 surfaces it as a soft escape hatch; in V1 we still
  /// fetch profile but the chip lets the user bypass it explicitly).
  final bool ignoreDietaryProfile;

  int get activeChipFilterCount {
    if (phase == FormulaPhase.before) {
      return beforeSubPhase == null ? 0 : 1;
    }
    return (duringActivity == null ? 0 : 1) +
        (duringDuration == null ? 0 : 1);
  }

  int get activeMoreFilterCount {
    return (phase == FormulaPhase.before
            ? (beforeDigestionSpeed == null ? 0 : 1)
            : (duringGutLevel == null ? 0 : 1)) +
        (ignoreDietaryProfile ? 1 : 0);
  }

  FormulaFilterState copyWith({
    FormulaPhase? phase,
    BeforeSubPhase? Function()? beforeSubPhase,
    FormulaDigestionSpeed? Function()? beforeDigestionSpeed,
    DuringActivity? Function()? duringActivity,
    DuringDuration? Function()? duringDuration,
    DuringGutLevel? Function()? duringGutLevel,
    bool? ignoreDietaryProfile,
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
      ignoreDietaryProfile:
          ignoreDietaryProfile ?? this.ignoreDietaryProfile,
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
        other.ignoreDietaryProfile == ignoreDietaryProfile;
  }

  @override
  int get hashCode => Object.hash(
        phase,
        beforeSubPhase,
        beforeDigestionSpeed,
        duringActivity,
        duringDuration,
        duringGutLevel,
        ignoreDietaryProfile,
      );
}
