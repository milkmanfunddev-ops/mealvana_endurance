/// Where the environmental conditions on a plan came from.
///
/// Spec: `docs/ssot/spec/fueling/during-workout-hydration.md` — conditions
/// provenance CP-1..CP-6 (RULED Xuan, 2026-09-21). Vectors:
/// `docs/ssot/vectors/fueling/conditions-provenance.json`.
///
/// CP-5 is the rule this type exists to enforce: provenance is **SOURCE**
/// driven, never failure driven. `ConditionsSource` answers "where did this
/// number come from", not "did a network call fail". More than one code path
/// seeds the CP-1 placeholders (the failed forecast fetch, the Q-CA2
/// per-activity form reset with no forecast loaded, the schedule-change
/// reseed, and the indoor-terrain switch), so a flag keyed on the fetch
/// outcome marks the first and silently misses the rest.
enum ConditionsSource {
  /// Fetched for the session's place and time.
  measured('measured', 'Measured'),

  /// The CP-1 fallback is in play — 20.0 °C / 60 % (45 % humidity indoors).
  /// Nothing measured this session's conditions.
  assumed('assumed', 'Assumed'),

  /// The athlete supplied or overrode the value. Outranks the fallback: an
  /// override typed after a failed fetch is MANUAL, never assumed.
  manual('manual', 'Manual');

  const ConditionsSource(this.wireValue, this.displayLabel);

  /// Persisted/serialized form — stable, never the enum's Dart name.
  final String wireValue;

  /// The source-chip parameter (D-2 `Measured · Assumed · Manual`).
  final String displayLabel;

  static ConditionsSource? fromWire(Object? raw) {
    if (raw is! String) return null;
    for (final value in ConditionsSource.values) {
      if (value.wireValue == raw) return value;
    }
    return null;
  }

  /// The plan-level flag for a pair of per-value sources.
  ///
  /// Precedence is **assumed > manual > measured**, i.e. the least-confident
  /// input wins. CP-2: "a plan whose conditions were assumed MUST NOT be
  /// presentable as one built on measured conditions" — so one invented value
  /// is enough to make the whole plan `assumed`, and a plan is only
  /// `measured` when every conditions input was actually fetched.
  static ConditionsSource resolve(
    ConditionsSource temperature,
    ConditionsSource humidity,
  ) {
    if (temperature == ConditionsSource.assumed ||
        humidity == ConditionsSource.assumed) {
      return ConditionsSource.assumed;
    }
    if (temperature == ConditionsSource.manual ||
        humidity == ConditionsSource.manual) {
      return ConditionsSource.manual;
    }
    return ConditionsSource.measured;
  }
}
