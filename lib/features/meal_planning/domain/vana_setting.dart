/// Settings keys — rows in `user_memories` with `kind = 'setting'`
/// (contract 02 §1). Batch cooking and show-macros are booleans; the plan
/// period (mp-269) is `week_start` (`'sun'` … `'sat'`) and `period_days`
/// (a whole number of days) — see `PlanPeriod` in `week_start.dart`.
enum VanaSetting {
  batchCooking('batch_cooking'),
  showMacros('show_macros'),
  weekStart('week_start'),
  periodDays('period_days');

  const VanaSetting(this.wire);

  /// `user_memories.key` / the `set_setting` payload `key`.
  final String wire;

  static VanaSetting? fromWire(String? value) {
    if (value == null) return null;
    for (final v in VanaSetting.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}
