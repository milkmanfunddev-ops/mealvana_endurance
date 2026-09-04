/// One of a library meal's `swaps` suggestions, parsed from the wire string
/// the catalog stores — `"water→milk (+10g protein)"` — into the
/// `{from, to, effect?}` triple the swap action sends (plan Phase 6.3).
///
/// The catalog writes the arrow as `→`; `->` is accepted for hand-typed
/// rows. Anything without an arrow is not a swap and parses to `null`.
class IngredientSwap {
  const IngredientSwap({required this.from, required this.to, this.effect});

  final String from;
  final String to;

  /// The bracketed trade-off, e.g. `+10g protein`; `null` when absent.
  final String? effect;

  static final _pattern = RegExp(
    r'^\s*(.+?)\s*(?:→|->)\s*(.+?)\s*(?:\((.+?)\))?\s*$',
  );

  static IngredientSwap? parse(String raw) {
    final match = _pattern.firstMatch(raw);
    if (match == null) return null;
    final from = match.group(1)!.trim();
    final to = match.group(2)!.trim();
    if (from.isEmpty || to.isEmpty) return null;
    final effect = match.group(3)?.trim();
    return IngredientSwap(
      from: from,
      to: to,
      effect: effect == null || effect.isEmpty ? null : effect,
    );
  }

  /// Parse a list, dropping strings that are not swaps.
  static List<IngredientSwap> parseAll(Iterable<String> raw) => [
    for (final s in raw)
      if (parse(s) case final swap?) swap,
  ];

  @override
  bool operator ==(Object other) =>
      other is IngredientSwap &&
      other.from == from &&
      other.to == to &&
      other.effect == effect;

  @override
  int get hashCode => Object.hash(from, to, effect);

  @override
  String toString() => 'IngredientSwap($from → $to${effect == null ? '' : ' ($effect)'})';
}
