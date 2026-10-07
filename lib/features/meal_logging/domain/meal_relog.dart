import 'macro_rounding.dart';
import 'meal_component.dart';
import 'portion_quantity.dart';

/// Scales one item of a logged meal by [servings] for a re-log from Recent,
/// and for a Common ingredient or search result logged at a serving count.
///
/// At 1 serving the item is returned unchanged, so a re-log is an exact copy
/// of what the source row holds. Otherwise every known macro is multiplied
/// and rounded (unknown stays unknown) and the portion is scaled with its
/// unit kept ("2 cakes" x 2 → "4 cakes", "1 large" x 1.5 → "1.5 large",
/// "1/2 cup dry" x 2 → "1 cup dry", "4 oz cooked (115 g)" x 1.5 → "6 oz
/// cooked (173 g)"); a portion with no leading number is prefixed with the
/// servings ("1.5 × a handful").
MealComponent scaleComponentForRelog(MealComponent item, double servings) {
  if (servings == 1) return item;
  final portion =
      scalePortion(item.portion, servings) ??
      '${fmtQty(servings)} × ${item.portion}';
  return MealComponent(
    name: item.name,
    portion: portion,
    calories: item.calories == null
        ? null
        : (item.calories! * servings).round(),
    carbG: roundMacro(item.carbG == null ? null : item.carbG! * servings),
    proteinG: roundMacro(
      item.proteinG == null ? null : item.proteinG! * servings,
    ),
    fatG: roundMacro(item.fatG == null ? null : item.fatG! * servings),
    sodiumMg: roundSodium(
      item.sodiumMg == null ? null : item.sodiumMg! * servings,
    ),
  );
}
