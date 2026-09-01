/// `MealContext` in `contracts.ts` — when a library meal fits in the week.
enum MealContext {
  everyday('everyday'),
  preSession('pre-session'),
  recovery('recovery'),
  restDay('rest-day'),
  raceWeek('race-week'),
  carbLoad('carb-load'),
  travel('travel');

  const MealContext(this.wire);

  final String wire;

  static MealContext? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MealContext.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  /// Parse a wire list, dropping unknown values.
  static List<MealContext> listFromWire(Iterable<String> values) =>
      List.unmodifiable(values.map(fromWire).whereType<MealContext>());
}
