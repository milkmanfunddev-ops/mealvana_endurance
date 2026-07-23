/// Helpers for reading and rewriting the leading numeric quantity of a
/// free-text portion string (e.g. "1 cup", "1.5 oz", "a handful").
///
/// Meal items persist the eaten amount inside the portion string itself —
/// neither [MealComponent] nor [MealAnalysisItem] has a separate quantity
/// field — so the Edit Item dialogs use these helpers to (a) derive the
/// baseline quantity from the portion and (b) fold the chosen Quantity back
/// into the portion at save time. During editing the Portion label itself is
/// never rewritten (bug 39fe3fdb): the label shows the unit portion and the
/// Quantity field communicates how many of it were eaten.
library;

/// Parses the leading numeric quantity from a portion string, e.g. "2 cups"
/// → 2.0, "1.5 oz" → 1.5. Returns null when the portion has no leading
/// number (e.g. "a handful").
double? parseLeadingQuantity(String portion) {
  final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(portion);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

/// Rewrites the leading number of [portion] to [qty], preserving the unit
/// suffix (e.g. "1 cup" + 2 → "2 cup"). Returns null when there is no leading
/// number to replace, leaving the caller's portion text untouched.
String? replaceLeadingQuantity(String portion, double qty) {
  final match = RegExp(r'^(\s*)(\d+(?:\.\d+)?)(.*)$').firstMatch(portion);
  if (match == null) return null;
  return '${match.group(1)}${fmtQty(qty)}${match.group(3)}';
}

/// Formats a quantity without a trailing ".0" for whole numbers.
String fmtQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  return qty.toString();
}
