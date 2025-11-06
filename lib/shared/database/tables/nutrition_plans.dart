import 'package:drift/drift.dart';

/// Nutrition plans table definition for Drift - matches Supabase nutrition_plans schema
/// Stores nutrition plans with versioning and conflict resolution
@DataClassName('NutritionPlanEntry')
class NutritionPlans extends Table {
  /// Primary key (matches Supabase nutrition_plans.id) - flexible length for various ID formats
  TextColumn get id => text()();

  /// Device ID (foreign key reference to users.device_id)
  TextColumn get deviceId => text().named('device_id')();

  /// Plan data stored as JSON (matches Supabase nutrition_plans.plan_data)
  TextColumn get planData => text().named('plan_data')();

  /// Plan metadata (matches Supabase schema)
  TextColumn get planId => text().named('plan_id')();
  TextColumn get planName => text().named('plan_name')();
  RealColumn get distanceMiles => real().nullable().named('distance_miles')();
  RealColumn get paceMinutesPerMile => real().nullable().named('pace_minutes_per_mile')();
  IntColumn get totalCalories => integer().nullable().named('total_calories')();
  TextColumn get notes => text().nullable()();

  // NEW: Calendar integration fields
  TextColumn get activityId => text().nullable().named('activity_id')(); // FOREIGN KEY to activities.id
  TextColumn get planType => text().withDefault(const Constant('standard')).named('plan_type')(); // 'standard', 'carb_loading', 'recovery'
  TextColumn get sportType => text().withDefault(const Constant('running')).named('sport_type')(); // Placeholder for future multi-sport support

  /// Versioning and sync (matches Supabase schema)
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get lastModifiedBy => text().nullable().named('last_modified_by')();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable().named('client_updated_at')();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false)).named('is_deleted')();
  TextColumn get conflictResolution => text().nullable().named('conflict_resolution')();

  /// Timestamps (matches Supabase schema)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  /// Offline-first sync flags (matches calendar tables pattern)
  BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().withDefault(currentDateAndTime).named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(device_id, plan_id)', // Match Supabase unique constraint
    "CHECK (plan_type IN ('standard', 'carb_loading', 'recovery'))",
  ];
}
