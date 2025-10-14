import 'package:drift/drift.dart';

/// Table for all calendar entries including workouts and events
@DataClassName('Activity')
class ActivitiesTable extends Table {
  TextColumn get id => text()(); // PRIMARY KEY
  TextColumn get userId => text().named('user_id')(); // FOREIGN KEY to user_profiles.id
  
  TextColumn get activityType => text().named('activity_type')(); // 'running', 'cycling', 'swimming'
  TextColumn get title => text()();
  DateTimeColumn get scheduledDateTime => dateTime().named('scheduled_date_time')(); // TIMESTAMP
  
  TextColumn get status => text().withDefault(const Constant('planned')).named('status')(); // 'planned', 'in_progress', 'completed', 'skipped'
  
  // Activity parameters (nullable)
  RealColumn get distanceMiles => real().nullable().named('distance_miles')();
  IntColumn get durationMinutes => integer().nullable().named('duration_minutes')();
  RealColumn get paceTargetMinutesPerMile => real().nullable().named('pace_target_minutes_per_mile')();
  TextColumn get intensityLevel => text().nullable().named('intensity_level')(); // 'easy', 'moderate', 'hard', 'race'
  
  // Completion data (nullable)
  DateTimeColumn get completedAt => dateTime().nullable().named('completed_at')();
  IntColumn get completionRating => integer().nullable().named('completion_rating')(); // 1-5
  TextColumn get completionNotes => text().nullable().named('completion_notes')();
  RealColumn get actualDistanceMiles => real().nullable().named('actual_distance_miles')();
  IntColumn get actualDurationMinutes => integer().nullable().named('actual_duration_minutes')();
  
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
    "CHECK (status IN ('planned', 'in_progress', 'completed', 'skipped'))",
    "CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race'))",
    'CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5))',
  ];
}