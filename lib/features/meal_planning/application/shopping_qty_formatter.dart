import '../../nutrition_plan/domain/run_parameters.dart';

/// Renders a shopping-list quantity in the athlete's unit system.
///
/// The server aggregates in the catalog's own units (metric weights and
/// volumes, cups/tbsp/tsp, counts) — see `_shared/vana/grocery.ts`. US
/// shoppers read pounds and ounces, so unless the athlete has switched to
/// metric in Settings (Lee, 2026-09-07) weights and volumes are converted
/// here, at the edge of the UI. Cups, spoons, counts and words pass through
/// untouched in both systems.
///
/// A quantity can carry several units joined by ` + ` (`"2 cup + 200 g"`);
/// each segment converts on its own.
String formatShoppingQty(String qty, UnitSystem units) {
  if (qty.isEmpty || units == UnitSystem.metric) return qty;
  return qty.split(' + ').map(_toImperial).join(' + ');
}

final _segment = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l)$');

String _toImperial(String segment) {
  final m = _segment.firstMatch(segment.trim().toLowerCase());
  if (m == null) return segment;
  final n = double.parse(m.group(1)!.replaceAll(',', '.'));
  switch (m.group(2)) {
    case 'kg':
      return _lb(n * 1000);
    case 'g':
      return _lb(n);
    case 'ml':
      return _floz(n);
    case 'l':
      return _floz(n * 1000);
  }
  return segment;
}

/// Grams → ounces under a pound, pounds (one decimal) from there.
String _lb(double grams) {
  final oz = grams / 28.3495;
  if (oz < 16) return '${_round(oz, 0.5)} oz';
  return '${_round(oz / 16, 0.1)} lb';
}

/// Millilitres → fluid ounces under a quart, quarts (one decimal) from there.
String _floz(double ml) {
  final floz = ml / 29.5735;
  if (floz < 32) return '${_round(floz, 0.5)} fl oz';
  return '${_round(floz / 32, 0.1)} qt';
}

/// Round to the nearest [step] and print without a trailing `.0`.
String _round(double value, double step) {
  final r = (value / step).round() * step;
  if (r == r.roundToDouble()) return r.round().toString();
  return r.toStringAsFixed(1);
}
