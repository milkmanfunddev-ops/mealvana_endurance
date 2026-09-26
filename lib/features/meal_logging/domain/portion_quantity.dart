/// Helpers for reading and rewriting the leading numeric quantity of a
/// free-text portion string (e.g. "1 cup", "1.5 oz", "1/2 cup dry",
/// "1 1/2 cups", "a handful").
///
/// Meal items persist the eaten amount inside the portion string itself —
/// neither [MealComponent] nor [MealAnalysisItem] has a separate quantity
/// field — so the Edit Item dialogs use these helpers to (a) derive the
/// baseline quantity from the portion and (b) fold the chosen Quantity back
/// into the portion at save time. During editing the Portion label itself is
/// never rewritten (bug 39fe3fdb): the label shows the unit portion and the
/// Quantity field communicates how many of it were eaten.
///
/// The leading number may be a whole number, a decimal, a fraction or a mixed
/// number (testing-wave 112-003: "1/2 cup dry" x 2 used to become "2/2 cup
/// dry" because only the numerator was read).
library;

/// `1`, `1.5`, `1/2`, `1 1/2`, `1-1/2`, with optional leading whitespace.
final RegExp _leadingQuantity = RegExp(
  r'^(\s*)(\d+(?:\.\d+)?(?:[\s-]+\d+/\d+)?|\d+/\d+)(?=\s|$|[a-zA-Z(×x])',
);

/// A bracketed weight or volume after the unit: "(115 g)", "(240 ml)",
/// "(about 150g)".
final RegExp _bracketedAmount = RegExp(
  r'\((\s*(?:about|approx\.?|~)?\s*)(\d+(?:\.\d+)?)(\s*(?:g|ml|oz|mg)\s*)\)',
  caseSensitive: false,
);

/// Parses the leading numeric quantity from a portion string, e.g. "2 cups"
/// → 2.0, "1.5 oz" → 1.5, "1/2 cup" → 0.5, "1 1/2 cups" → 1.5. Returns null
/// when the portion has no leading number (e.g. "a handful").
double? parseLeadingQuantity(String portion) {
  final match = _leadingQuantity.firstMatch(portion);
  if (match == null) return null;
  return _parseQuantityToken(match.group(2)!);
}

double? _parseQuantityToken(String token) {
  final parts = token.trim().split(RegExp(r'[\s-]+'));
  var total = 0.0;
  for (final part in parts) {
    final slash = part.indexOf('/');
    if (slash == -1) {
      final v = double.tryParse(part);
      if (v == null) return null;
      total += v;
    } else {
      final num = double.tryParse(part.substring(0, slash));
      final den = double.tryParse(part.substring(slash + 1));
      if (num == null || den == null || den == 0) return null;
      total += num / den;
    }
  }
  return total;
}

/// Rewrites the leading number of [portion] to [qty], preserving the unit
/// suffix (e.g. "1 cup" + 2 → "2 cup", "1/2 cup dry" + 1 → "1 cup dry").
/// Returns null when there is no leading number to replace, leaving the
/// caller's portion text untouched.
String? replaceLeadingQuantity(String portion, double qty) {
  final match = _leadingQuantity.firstMatch(portion);
  if (match == null) return null;
  return '${match.group(1)}${fmtQty(qty)}${portion.substring(match.end)}';
}

/// Scales [portion] by [factor]: the leading number is multiplied, and so is a
/// bracketed weight or volume after the unit ("4 oz cooked (115 g)" x 1.5 →
/// "6 oz cooked (173 g)"; the bracketed amount is rounded to a whole number).
/// Returns null when the portion has no leading number to scale.
String? scalePortion(String portion, double factor) {
  final qty = parseLeadingQuantity(portion);
  if (qty == null) return null;
  final scaled = replaceLeadingQuantity(portion, qty * factor);
  if (scaled == null) return null;
  return scaled.replaceFirstMapped(_bracketedAmount, (m) {
    final amount = double.parse(m.group(2)!);
    return '(${m.group(1)}${fmtQty((amount * factor).roundToDouble())}'
        '${m.group(3)})';
  });
}

/// Formats a quantity without a trailing ".0" for whole numbers, to at most
/// three decimals (1.875 stays; 0.6666… becomes 0.667).
String fmtQty(double qty) {
  final rounded = (qty * 1000).round() / 1000;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  var text = rounded.toStringAsFixed(3);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
