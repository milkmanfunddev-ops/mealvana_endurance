import '../../nutrition_plan/domain/food_item.dart';

/// The key a food's preference row is stored under: `template_foods.name`
/// (snake_case) for a catalog food, the food's own name for a user food.
/// The plan engine and onboarding match on the same key (ticket 58).
String foodPreferenceKey(FoodItem food) => food.catalogName ?? food.name;
