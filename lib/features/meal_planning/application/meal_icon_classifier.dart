/// Application-layer entry point for the icon classifier (05 §1). The port
/// of `meal-icon.ts` lives in the domain (`MealIconClassifier`) because
/// `MealRef` parsing resolves icons too; this re-export keeps imports at the
/// layer the file tree names.
library;

export '../domain/meal_icon.dart' show MealIcon;
export '../domain/meal_icon_classifier.dart' show MealIconClassifier;
