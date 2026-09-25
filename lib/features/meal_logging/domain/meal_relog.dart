import 'meal_component.dart';
import 'portion_quantity.dart';

/// Scales one item of a logged meal by [servings] for a re-log from Recent.
///
/// At 1 serving the item is returned unchanged, so a re-log is an exact copy
/// of what the source row holds. Otherwise every known macro is multiplied
/// (unknown stays unknown) and the portion's leading number is rewritten
/// ("2 cakes" x 2 → "4 cakes"); a portion without one is prefixed with the
/// servings ("1.5 × a handful").
MealComponent scaleComponentForRelog(MealComponent item, double servings) {
  if (servings == 1) return item;
  final portion =
      replaceLeadingQuantity(
        item.portion,
        (parseLeadingQuantity(item.portion) ?? 0) * servings,
      ) ??
      '${fmtQty(servings)} × ${item.portion}';
  return MealComponent(
    name: item.name,
    portion: portion,
    calories: item.calories == null
        ? null
        : (item.calories! * servings).round(),
    carbG: item.carbG == null ? null : item.carbG! * servings,
    proteinG: item.proteinG == null ? null : item.proteinG! * servings,
    fatG: item.fatG == null ? null : item.fatG! * servings,
    sodiumMg: item.sodiumMg == null ? null : item.sodiumMg! * servings,
  );
}
