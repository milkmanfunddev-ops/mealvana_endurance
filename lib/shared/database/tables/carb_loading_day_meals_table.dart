import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Carb Loading Day Meals table - tracks actual food selections per day/meal
/// Stores which foods a user selected for each meal on each carb loading day
/// Example: Day -2, Breakfast: 2x Cereal (28g carbs), 1x Banana (27g carbs)
@DataClassName('CarbLoadingDayMeal')
class CarbLoadingDayMealsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PRIMARY KEY (UUID)
  TextColumn get carbLoadingDayId => text().named('carb_loading_day_id')(); // FK to carb_loading_days.id
  IntColumn get mealTypeId => integer().named('meal_type_id')(); // FK to meal_types.id (1=breakfast, 2=lunch, etc.)

  // EXACTLY ONE of these must be non-null (enforced by CHECK constraint)
  TextColumn get carbLoadingFoodId => text().nullable().named('carb_loading_food_id')(); // FK to carb_loading_foods.id (UUID)
  TextColumn get carbLoadingUserFoodId => text().nullable().named('carb_loading_user_food_id')(); // FK to carb_loading_user_foods.id (UUID)

  TextColumn get foodDisplayName => text().nullable().named('food_display_name')(); // Cached food name for display
  IntColumn get quantity => integer().withDefault(const Constant(1))(); // Number of servings
  RealColumn get carbsConsumed => real().named('carbs_consumed')(); // Calculated: quantity * carbs_per_serving
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_day_meals';

  @override
  List<String> get customConstraints => [
    // Note: Foreign key constraints are handled by Drift's type system and relationships
    // The actual FK enforcement happens in Supabase PostgreSQL, not in SQLite
    'CHECK (quantity > 0)',
    'CHECK (carbs_consumed >= 0)',
    // Ensure exactly one food type is set (either default food OR user food, not both)
    'CHECK ((carb_loading_food_id IS NOT NULL AND carb_loading_user_food_id IS NULL) OR (carb_loading_food_id IS NULL AND carb_loading_user_food_id IS NOT NULL))',
  ];
}
