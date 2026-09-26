/// Rounding for the numbers a `meal_logs` row stores (testing-wave 112-004).
///
/// Scaling a quick log by 1.5 servings multiplies doubles, and the product
/// carries float noise (60.449999999999996, 0.6000000000000001) into the
/// row and on to the server, coach views and Vana. Every scaled item and
/// every summed total is rounded here before the write: macros to one
/// decimal, sodium to a whole milligram. Unknown stays unknown (`null ≠ 0`).
library;

/// Grams of carbohydrate, protein or fat: one decimal.
double? roundMacro(double? grams) =>
    grams == null ? null : (grams * 10).round() / 10;

/// Sodium in milligrams: a whole number, kept as a double for the column.
double? roundSodium(double? mg) => mg?.roundToDouble();
