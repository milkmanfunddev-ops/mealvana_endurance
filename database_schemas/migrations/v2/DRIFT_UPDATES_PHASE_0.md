# Drift Schema Updates for Phase 0

After running the Phase 0 SQL migrations on both Dev and Prod, you need to update your Drift schema.

## Step 1: Update Activities Table

**File:** `lib/shared/database/tables/activities_table.dart`

```dart
class ActivitiesTable extends Table {
  // ✅ CHANGED: text() → integer().autoIncrement()
  IntColumn get id => integer().autoIncrement()();

  // ✅ CHANGED: text() → text() (but now stores UUID as string)
  TextColumn get userId => text().named('user_id')();

  TextColumn get activityType => text().named('activity_type')();
  TextColumn get title => text()();
  DateTimeColumn get scheduledDateTime => dateTime().named('scheduled_date_time')();
  TextColumn get status => text().withDefault(const Constant('planned'))();

  // Running/general fields
  RealColumn get distanceMiles => real().named('distance_miles').nullable()();
  IntColumn get durationMinutes => integer().named('duration_minutes').nullable()();
  RealColumn get paceTargetMinutesPerMile => real().named('pace_target_minutes_per_mile').nullable()();
  TextColumn get intensityLevel => text().named('intensity_level').nullable()();

  // Cycling fields
  RealColumn get cyclingSpeedMph => real().named('cycling_speed_mph').nullable()();
  TextColumn get cyclingTerrain => text().named('cycling_terrain').nullable()();
  TextColumn get cyclingIndoorOutdoor => text().named('cycling_indoor_outdoor').nullable()();
  IntColumn get cyclingElevationGainFt => integer().named('cycling_elevation_gain_ft').nullable()();
  TextColumn get cyclingSessionGoal => text().named('cycling_session_goal').nullable()();
  IntColumn get cyclingPowerWatts => integer().named('cycling_power_watts').nullable()();
  IntColumn get cyclingFtpWatts => integer().named('cycling_ftp_watts').nullable()();

  // Swimming fields
  IntColumn get swimmingPacePer100mSeconds => integer().named('swimming_pace_per_100m_seconds').nullable()();
  TextColumn get swimmingPoolOrOpenWater => text().named('swimming_pool_or_open_water').nullable()();
  RealColumn get swimmingWaterTempC => real().named('swimming_water_temp_c').nullable()();
  IntColumn get swimmingSpeedPer100m => integer().named('swimming_speed_per_100m').nullable()();
  IntColumn get swimmingCssSecondsPer100m => integer().named('swimming_css_seconds_per_100m').nullable()();

  // Completion fields
  DateTimeColumn get completedAt => dateTime().named('completed_at').nullable()();
  IntColumn get completionRating => integer().named('completion_rating').nullable()();
  TextColumn get completionNotes => text().named('completion_notes').nullable()();
  RealColumn get actualDistanceMiles => real().named('actual_distance_miles').nullable()();
  IntColumn get actualDurationMinutes => integer().named('actual_duration_minutes').nullable()();

  // Metadata
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  // Sync tracking
  BoolColumn get needsUpload => boolean().named('needs_upload').withDefault(const Constant(true))();
  DateTimeColumn get localUpdatedAt => dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  // Legacy field (keep for now)
  TextColumn get sportType => text().named('sport_type').withDefault(const Constant('running'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'activities';
}
```

## Step 2: Update Events Table

**File:** `lib/shared/database/tables/events_table.dart`

```dart
class EventsTable extends Table {
  // ✅ CHANGED: text() → integer().autoIncrement()
  IntColumn get id => integer().autoIncrement()();

  // ✅ CHANGED: text() → text() (but now stores UUID as string)
  TextColumn get userId => text().named('user_id')();

  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime().named('start_time')();

  // ✅ CHANGED: text() → integer() (BIGINT FK)
  IntColumn get activityId => integer().named('activity_id').nullable()();

  DateTimeColumn get carbLoadingStartDate => dateTime().named('carb_loading_start_date').nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  BoolColumn get needsUpload => boolean().named('needs_upload').withDefault(const Constant(true))();
  DateTimeColumn get localUpdatedAt => dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'events';
}
```

## Step 3: Update Carb Loading Plans Table

**File:** `lib/shared/database/tables/carb_loading_plans_table.dart`

```dart
class CarbLoadingPlansTable extends Table {
  // ✅ CHANGED: text() → integer().autoIncrement()
  IntColumn get id => integer().autoIncrement()();

  // ✅ CHANGED: text() → text() (UUID as string)
  TextColumn get userId => text().named('user_id')();

  DateTimeColumn get raceDate => dateTime().named('race_date')();
  TextColumn get raceName => text().named('race_name').nullable()();
  RealColumn get raceDistanceMiles => real().named('race_distance_miles').nullable()();
  IntColumn get daysBeforeRace => integer().named('days_before_race')();
  IntColumn get dailyCarbTargetGrams => integer().named('daily_carb_target_grams')();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  BoolColumn get needsUpload => boolean().named('needs_upload').withDefault(const Constant(true))();
  DateTimeColumn get localUpdatedAt => dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_plans';
}
```

## Step 4: Update Carb Loading Days Table

**File:** `lib/shared/database/tables/carb_loading_days_table.dart`

```dart
class CarbLoadingDaysTable extends Table {
  // ✅ CHANGED: text() → integer().autoIncrement()
  IntColumn get id => integer().autoIncrement()();

  // ✅ CHANGED: text() → integer() (BIGINT FK)
  IntColumn get carbLoadingPlanId => integer().named('carb_loading_plan_id')();

  DateTimeColumn get dayDate => dateTime().named('day_date')();
  IntColumn get dayNumber => integer().named('day_number')();
  IntColumn get carbTargetGrams => integer().named('carb_target_grams')();
  IntColumn get carbActualGrams => integer().named('carb_actual_grams').nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_days';
}
```

## Step 5: Update Workout Notes Table

**File:** `lib/shared/database/tables/workout_notes_table.dart`

```dart
class WorkoutNotesTable extends Table {
  // ✅ CHANGED: text() → integer().autoIncrement()
  IntColumn get id => integer().autoIncrement()();

  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get deviceId => text().named('device_id').nullable()();

  // ✅ CHANGED: text() → integer() (BIGINT FK)
  IntColumn get activityId => integer().named('activity_id').nullable()();

  TextColumn get notes => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'workout_notes';
}
```

## Step 6: Update Feature Survey Responses Table

**File:** `lib/shared/database/tables/feature_survey_responses_table.dart`

```dart
class FeatureSurveyResponsesTable extends Table {
  // ✅ CHANGED: text() → integer().autoIncrement()
  IntColumn get id => integer().autoIncrement()();

  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get deviceId => text().named('device_id').nullable()();
  TextColumn get featureName => text().named('feature_name')();
  TextColumn get responseData => text().named('response_data')();  // JSONB stored as TEXT in Drift
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'feature_survey_responses';
}
```

## Step 7: Update Domain Models

You'll need to update the domain models to use `int` for IDs instead of `String`:

**File:** `lib/features/activities/domain/activity.dart`

```dart
class Activity {
  const Activity({
    required this.id,  // Now int instead of String
    required this.userId,  // Now String (UUID) instead of String (device_id)
    // ... rest of fields
  });

  final int id;  // ✅ CHANGED from String
  final String userId;  // ✅ Now stores UUID
  // ... rest of fields

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int,  // ✅ Parse as int
      userId: json['user_id'] as String,  // ✅ UUID as string
      // ... rest
    );
  }
}
```

## Step 8: Regenerate Drift Code

```bash
# Clean old generated files
rm lib/shared/database/app_database.g.dart
rm lib/shared/database/tables/*.g.dart

# Regenerate
dart run build_runner build --delete-conflicting-outputs

# Update schema snapshot (OVERWRITES v1)
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/

# Verify
flutter analyze
```

## Step 9: Update Repositories

You'll need to update repository methods that reference IDs:

**Example:** `lib/features/activities/data/activities_repository.dart`

```dart
// ✅ BEFORE
Future<Activity?> getActivityById(String userId, String activityId) async {
  final query = select(activitiesTable)
    ..where((tbl) => tbl.id.equals(activityId));
  // ...
}

// ✅ AFTER
Future<Activity?> getActivityById(String userId, int activityId) async {
  final query = select(activitiesTable)
    ..where((tbl) => tbl.id.equals(activityId));
  // ...
}
```

## Summary Checklist

- [ ] Update all table classes (activities, events, carb_loading_plans, carb_loading_days, workout_notes, feature_survey_responses)
- [ ] Change `id` columns from `text()` to `integer().autoIncrement()`
- [ ] Change `user_id` columns to store UUID as text (no schema change, just semantic)
- [ ] Change foreign key references (e.g., `activityId`, `carbLoadingPlanId`) from `text()` to `integer()`
- [ ] Update domain models to use `int` for IDs
- [ ] Update repository methods to accept `int` IDs
- [ ] Regenerate Drift code
- [ ] Run `flutter analyze` to catch any type mismatches
- [ ] Test thoroughly!

## Notes

- **Drift doesn't have native UUID type**, so we store UUIDs as TEXT
- **BIGSERIAL maps to `integer().autoIncrement()` in Drift**
- **This is a breaking change** - all existing local data will be lost (fresh install required)
- **Coordinate with Phase 1** to embed nutrition data in activities table
