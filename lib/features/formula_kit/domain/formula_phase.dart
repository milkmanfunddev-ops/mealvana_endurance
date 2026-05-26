/// Phase of an endurance workout that a formula targets.
///
/// PR 1 of Formula Kit covered Before and During. PR 3 (After-phase parity)
/// adds the [after] case so the library, pin machinery, and edge-function
/// solver can address `post_workout_templates` the same way.
enum FormulaPhase {
  before,
  during,
  after;

  String get analyticsValue => switch (this) {
        FormulaPhase.before => 'before',
        FormulaPhase.during => 'during',
        FormulaPhase.after => 'after',
      };

  String get displayLabel => switch (this) {
        FormulaPhase.before => 'Before',
        FormulaPhase.during => 'During',
        FormulaPhase.after => 'After',
      };
}
