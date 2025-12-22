import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Table for all calendar entries including workouts and events
@DataClassName('Activity')
class ActivitiesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PRIMARY KEY (UUID)
  TextColumn get userId => text().named('user_id')(); // FOREIGN KEY to user_profiles.id
  
  TextColumn get activityType => text().named('activity_type')(); // 'running', 'cycling', 'swimming'
  TextColumn get title => text()();
  DateTimeColumn get scheduledDateTime => dateTime().named('scheduled_date_time')(); // TIMESTAMP
  
  TextColumn get status => text().withDefault(const Constant('planned')).named('status')(); // 'draft', 'planned', 'in_progress', 'completed', 'skipped'
  
  // Activity parameters (nullable)
  RealColumn get distanceMiles => real().nullable().named('distance_miles')();
  IntColumn get durationMinutes => integer().nullable().named('duration_minutes')();
  RealColumn get paceTargetMinutesPerMile => real().nullable().named('pace_target_minutes_per_mile')();
  TextColumn get intensityLevel => text().nullable().named('intensity_level')(); // 'easy', 'moderate', 'hard', 'race'

  // Cycling-specific parameters
  RealColumn get cyclingSpeedMph => real().nullable().named('cycling_speed_mph')();
  TextColumn get cyclingTerrain => text().nullable().named('cycling_terrain')(); // 'flat', 'rolling', 'hilly'
  TextColumn get cyclingIndoorOutdoor => text().nullable().named('cycling_indoor_outdoor')(); // 'indoor', 'outdoor'
  IntColumn get cyclingElevationGainFt => integer().nullable().named('cycling_elevation_gain_ft')();
  TextColumn get cyclingSessionGoal => text().nullable().named('cycling_session_goal')(); // 'endurance', 'tempo', 'intervals'

  // Swimming-specific parameters
  IntColumn get swimmingPacePer100mSeconds => integer().nullable().named('swimming_pace_per_100m_seconds')();
  TextColumn get swimmingPoolOrOpenWater => text().nullable().named('swimming_pool_or_open_water')(); // 'pool', 'open_water'
  RealColumn get swimmingWaterTempC => real().nullable().named('swimming_water_temp_c')();

  // Shared intensity and timing
  TextColumn get intensityTarget => text().nullable().named('intensity_target')(); // 'zone_1', 'zone_2', 'rpe_3', etc.
  IntColumn get timeBeforeMinutes => integer().nullable().named('time_before_minutes')();

  // Reminder settings
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false)).named('reminder_enabled')();
  IntColumn get reminderDaysBefore => integer().nullable().named('reminder_days_before')(); // 1-7 days before activity
  TextColumn get reminderTimeOfDay => text().nullable().named('reminder_time_of_day')(); // Format: "HH:mm"
  BoolColumn get reminderRecurring => boolean().withDefault(const Constant(false)).named('reminder_recurring')();

  // Sync tracking (offline-first architecture)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().nullable().named('local_updated_at')();

  // External provider sync tracking (Final Surge, TrainingPeaks, Strava, etc.)
  TextColumn get syncedFromProvider => text().nullable().named('synced_from_provider')(); // 'final_surge', 'training_peaks', etc.
  TextColumn get providerWorkoutId => text().nullable().named('provider_workout_id')(); // External workout ID
  TextColumn get providerWorkoutUrl => text().nullable().named('provider_workout_url')(); // Link to view in provider
  DateTimeColumn get lastSyncedAt => dateTime().nullable().named('last_synced_at')();

  // Workout subtype from external provider (e.g., "Long Run", "Walk", "Recovery", "Tempo", "Intervals")
  TextColumn get workoutSubtype => text().nullable().named('workout_subtype')();

  // Pace ranges (for workouts with "8:30-9:30" style paces from Final Surge)
  RealColumn get paceMinMinutesPerMile => real().nullable().named('pace_min_minutes_per_mile')();
  RealColumn get paceMaxMinutesPerMile => real().nullable().named('pace_max_minutes_per_mile')();

  // Swimming distance in meters (industry standard for swimming)
  RealColumn get distanceMeters => real().nullable().named('distance_meters')();

  // Completion data (nullable)
  DateTimeColumn get completedAt => dateTime().nullable().named('completed_at')();
  IntColumn get completionRating => integer().nullable().named('completion_rating')(); // 1-5
  TextColumn get completionNotes => text().nullable().named('completion_notes')();
  RealColumn get actualDistanceMiles => real().nullable().named('actual_distance_miles')();
  IntColumn get actualDurationMinutes => integer().nullable().named('actual_duration_minutes')();

  // Embedded nutrition plan data (JSONB in Supabase, stored as TEXT in SQLite)
  TextColumn get nutritionPlanData => text().nullable().named('nutrition_plan_data')();

  // Metadata
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'activities';
  
  @override
  List<String> get customConstraints => [
    "CHECK (activity_type IN ('running', 'cycling', 'swimming'))",
    "CHECK (status IN ('draft', 'planned', 'in_progress', 'completed', 'skipped'))",
    "CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race'))",
    'CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5))',
  ];
}