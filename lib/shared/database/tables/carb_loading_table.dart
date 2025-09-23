import 'package:drift/drift.dart';

@DataClassName('CarbLoadingEntry')
class CarbLoadingTable extends Table {
  TextColumn get id => text()();                    // UUID (PK)
  TextColumn get userId => text()();                // References user_profiles.id

  // Race Information
  DateTimeColumn get raceDate => dateTime()();
  TextColumn get raceDistance => text()();          // half_marathon, marathon, 50k, etc.
  TextColumn get trainingVolume => text()();        // low, moderate, high

  // Calculated Targets (JSON format)
  TextColumn get planData => text()();              // Full plan JSON

  // Metadata
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_plans';
}