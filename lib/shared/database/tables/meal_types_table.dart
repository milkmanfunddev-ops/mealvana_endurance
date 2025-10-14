import 'package:drift/drift.dart';

/// Meal Types table - meal categories for carb loading (breakfast, lunch, dinner, snacks)
/// This is separate from the categories table which is for nutrition plan timing (before/during/after run)
@DataClassName('MealType')
class MealTypesTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withLength(min: 1, max: 50)(); // 'breakfast', 'lunch', 'dinner', 'snacks'
  TextColumn get displayName => text().withLength(min: 1, max: 50).named('display_name')(); // 'Breakfast', 'Lunch', 'Dinner', 'Snacks'

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'meal_types';
}
