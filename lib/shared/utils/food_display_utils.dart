// Shared utility functions for parsing and formatting food quantities and names.
//
// Consolidates duplicated logic from:
// - activity_detail_screen.dart
// - activity_detail_controller.dart
// - expandable_food_item_widget.dart

/// Extracts the leading numeric value from a raw quantity string.
///
/// Example: "2.5 cups Oatmeal" -> 2.5, "banana" -> null
double? parseLeadingQuantity(String raw) {
  final match = RegExp(r'^([\d.]+)').firstMatch(raw.trim());
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

/// Formats a quantity for display, removing unnecessary decimal places.
///
/// Examples: 2.0 -> "2", 1.5 -> "1.5", 1.33 -> "1.33"
String formatQuantity(double value) {
  if ((value - value.roundToDouble()).abs() < 0.01) {
    return value.round().toString();
  }
  if ((value * 10 - (value * 10).round()).abs() < 0.01) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}

/// Removes parenthetical suffixes from a food name.
///
/// Example: "Banana (organic)" -> "Banana"
String stripParenthetical(String value) {
  return value.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
}

/// Extracts the non-numeric tail from a quantity string.
///
/// Example: "2 cups Oatmeal" -> "cups Oatmeal", "3" -> ""
String parseQuantityTail(String raw) {
  final match = RegExp(r'^[\d.]+\s*(.*)$').firstMatch(raw);
  return (match?.group(1) ?? '').trim();
}
