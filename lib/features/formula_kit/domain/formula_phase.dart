/// Phase of an endurance workout that a formula targets.
///
/// PR 1 of Formula Kit covers Before and During. After is intentionally out
/// of scope (no design exists yet).
enum FormulaPhase {
  before,
  during;

  String get analyticsValue => switch (this) {
        FormulaPhase.before => 'before',
        FormulaPhase.during => 'during',
      };

  String get displayLabel => switch (this) {
        FormulaPhase.before => 'Before',
        FormulaPhase.during => 'During',
      };
}
