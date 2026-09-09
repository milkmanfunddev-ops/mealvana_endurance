import '../../meal_planning/domain/shopping_item.dart';
import '../domain/kroger_models.dart';

/// Only dimension-compatible conversions are automatic. Cups → grams, cooked →
/// dry, variable-weight produce and unparsed multipacks require shopper judgment.
class KrogerMatching {
  static ({double amount, String dimension})? parse(String input) {
    var s = input.toLowerCase().trim();
    for (final entry in {'½': '.5', '¼': '.25', '¾': '.75'}.entries) {
      s = s.replaceAllMapped(
        RegExp('(?:(\\d+)\\s*)?${entry.key}'),
        (m) => '${m[1] ?? '0'}${entry.value}',
      );
    }
    final match = RegExp(
      r'^(\d+(?:\.\d+)?|\d+/\d+)\s*(kg|g|grams?|lb|lbs|oz|ml|l|fl oz|ct|count|each)?$',
    ).firstMatch(s);
    if (match == null) return null;
    final raw = match[1]!;
    final parts = raw.split('/');
    final n = parts.length == 2
        ? double.parse(parts[0]) / double.parse(parts[1])
        : double.parse(raw);
    if (!n.isFinite || n <= 0) return null;
    final unit = match[2] ?? '';
    final (factor, dimension) = switch (unit) {
      'kg' => (1000.0, 'mass'),
      'g' || 'gram' || 'grams' => (1.0, 'mass'),
      'lb' || 'lbs' => (453.59237, 'mass'),
      'oz' => (28.349523125, 'mass'),
      'l' => (1000.0, 'volume'),
      'ml' => (1.0, 'volume'),
      'fl oz' => (29.5735295625, 'volume'),
      _ => (1.0, 'count'),
    };
    return (amount: n * factor, dimension: dimension);
  }

  static int? packages(String requirement, String packageSize) {
    final pack = parse(packageSize);
    if (pack == null) return null;
    double total = 0;
    for (final part in requirement.split(' + ')) {
      final amount = parse(part);
      if (amount == null || amount.dimension != pack.dimension) return null;
      total += amount.amount;
    }
    final result = (total / pack.amount - 1e-9).ceil();
    return result >= 1 && result <= 99 ? result : null;
  }

  static KrogerDraft reconcile(KrogerDraft draft, List<ShoppingItem> source) {
    if (draft.exported) {
      return draft; // Preserve the historical handoff snapshot.
    }
    final previous = {for (final l in draft.lines) l.id: l};
    final lines = <KrogerLine>[];
    for (final item in source) {
      final id = KrogerLine.sourceId(draft.planId, item.name);
      final old = previous[id];
      final changed = old != null && old.requiredQty != item.qty;
      var line =
          old ?? KrogerLine(id: id, name: item.name, requiredQty: item.qty);
      line = line.copyWith(
        requiredQty: item.qty,
        excluded:
            old == null || line.sourceExcluded != (item.have || item.checked)
            ? item.have || item.checked
            : line.excluded,
        sourceExcluded: item.have || item.checked,
        approved: changed ? false : line.approved,
        quantity: changed && !line.quantityEdited
            ? packages(item.qty, line.product?.size ?? '') ?? line.quantity
            : line.quantity,
      );
      lines.add(line);
    }
    lines.addAll(draft.lines.where((l) => l.manual));
    return draft.copyWith(lines: lines);
  }
}
