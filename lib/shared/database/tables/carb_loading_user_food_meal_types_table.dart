import 'package:drift/drift.dart';

/// Carb Loading User Food Meal Types junction table
/// Links user-created carb loading foods to meal types (e.g., "My Pasta" → Lunch, Dinner)
/// Allows many-to-many relationships: a user food can be suitable for multiple meals
@DataClassName('CarbLoadingUserFoodMealType')
class CarbLoadingUserFoodMealTypesTable extends Table {
  TextColumn get carbLoadingUserFoodId => text().named('carb_loading_user_food_id')();
  IntColumn get mealTypeId => integer().named('meal_type_id')();

  @override
  Set<Column> get primaryKey => {carbLoadingUserFoodId, mealTypeId};

  @override
  String get tableName => 'carb_loading_user_food_meal_types';

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (carb_loading_user_food_id) REFERENCES carb_loading_user_foods(id) ON DELETE CASCADE',
    'FOREIGN KEY (meal_type_id) REFERENCES meal_types(id)',
  ];
}
