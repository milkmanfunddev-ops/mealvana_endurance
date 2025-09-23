import 'package:drift/drift.dart';

/// Simplified carb loading table for 50g increment food tracking
@DataClassName('CarbLoadingSimpleEntry')
class CarbLoadingSimpleTable extends Table {
  TextColumn get id => text()();                    // UUID (PK)
  TextColumn get userId => text()();                // References user_profiles.id

  // Race Information
  DateTimeColumn get raceDate => dateTime()();
  TextColumn get raceDistance => text()();          // half_marathon, marathon, 50k, etc.
  TextColumn get trainingVolume => text()();        // low, moderate, high

  // Simplified Carb Targets
  IntColumn get dailyCarbTargetG => integer()();    // e.g., 500g
  IntColumn get dailyServingsTarget => integer()(); // e.g., 10 servings (500g ÷ 50g)
  RealColumn get bodyWeightKg => real()();          // Body weight in kg
  RealColumn get carbsPerKgTarget => real()();      // 8g/kg from Featherstone guide

  // Food Selections (JSON format)
  TextColumn get daySelectionsJson => text()();     // Map<int, DayFoodSelections> as JSON

  // Metadata
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_simple_plans';
}