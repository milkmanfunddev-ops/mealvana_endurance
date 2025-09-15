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
  
  /// Scheduled run date and time
  DateTimeColumn get runDateTime => dateTime().nullable()();
  
  /// User's rating of plan effectiveness (1-3 scale)
  /// 1 = Could be better, 2 = Neutral, 3 = Satisfied
  IntColumn get planRating => integer().nullable()();
  
  /// User's journal notes about the plan
  TextColumn get journalNotes => text().nullable()();
  
  /// When the plan was created
  DateTimeColumn get createdAt => dateTime()();
  
  /// When the plan was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}