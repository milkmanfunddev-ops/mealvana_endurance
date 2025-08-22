import 'package:drift/drift.dart';

/// Nutrition plans table definition for Drift
/// Stores nutrition plans as JSON data for flexibility
@DataClassName('NutritionPlan')
class NutritionPlans extends Table {
  /// Plan ID (primary key)
  TextColumn get id => text()();
  
  /// User ID (foreign key reference)
  TextColumn get userId => text()();
  
  /// Plan data stored as JSON string
  TextColumn get planData => text()();
  
  /// When the plan was created
  DateTimeColumn get createdAt => dateTime()();
  
  /// When the plan was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}