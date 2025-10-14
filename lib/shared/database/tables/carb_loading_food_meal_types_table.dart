import 'package:drift/drift.dart';

/// Carb Loading Food Meal Types junction table
/// Links global carb loading foods to meal types (e.g., Cereal → Breakfast)
/// Allows many-to-many relationships: a food can be suitable for multiple meals
@DataClassName('CarbLoadingFoodMealType')
class CarbLoadingFoodMealTypesTable extends Table {
  TextColumn get carbLoadingFoodId => text().named('carb_loading_food_id')();
  IntColumn get mealTypeId => integer().named('meal_type_id')();

  @override
  Set<Column> get primaryKey => {carbLoadingFoodId, mealTypeId};

  @override
  String get tableName => 'carb_loading_food_meal_types';

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (carb_loading_food_id) REFERENCES carb_loading_foods(id) ON DELETE CASCADE',
    'FOREIGN KEY (meal_type_id) REFERENCES meal_types(id)',
  ];
}
