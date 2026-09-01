/// Settings keys — rows in `user_memories` with `kind = 'setting'`
/// (contract 02 §1). Both are booleans today.
enum VanaSetting {
  batchCooking('batch_cooking'),
  showMacros('show_macros');

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
