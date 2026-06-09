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

  /// String persisted in Drift + Supabase (`phase` column). Equals
  /// [analyticsValue]; named separately so storage intent reads clearly at
  /// call sites.
  String get wireValue => analyticsValue;

  /// Decode a persisted `phase` value. Returns `null` for unknown/null input
  /// so callers can skip and log rather than crash (forward-compat).
  static FormulaPhase? fromWireValue(String? value) {
    for (final p in FormulaPhase.values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}
