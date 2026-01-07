import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../schema_versions.dart';

/// V2 -> V3 Migration (December 2025 - January 2026)
///
/// Changes:
/// INTEGRATIONS (Final Surge):
/// - Creates integrations table for Final Surge, TrainingPeaks, Strava OAuth tokens
/// - Adds sweat_rate column to users table (default: 'medium', values: 'light', 'medium', 'heavy')
/// - Adds sync columns to activities for external provider tracking:
///   - synced_from_provider, provider_workout_id, provider_workout_url, last_synced_at
/// - Adds workout metadata:
///   - workout_subtype, pace_min_minutes_per_mile, pace_max_minutes_per_mile, distance_meters
/// - Creates index for synced activities
///
/// COACH MODE:
/// - Adds is_coach column to users table (boolean flag set by admin)
/// - Creates coach_athlete_relationships table for coach-athlete connections
/// - Creates coach_messages table for bidirectional messaging
/// - Creates indexes for coach mode tables
///
/// Note: Migration is idempotent - checks if columns/tables exist before adding.
Future<void> runMigrationV2ToV3(
  AppDatabase db,
  Migrator m,
  Schema3 schema,
) async {
  if (kDebugMode) {
    print('Running V2->V3 migration: Final Surge integration schema');
  }

  // 1. Create integrations table if it doesn't exist
  await m.createTable(schema.integrations);

  // 2. Add sweat_rate column to users table
  final usersColumns = await db.customSelect("PRAGMA table_info(users)").get();
  final usersColumnNames = usersColumns.map((row) => row.read<String>('name')).toSet();

  if (!usersColumnNames.contains('sweat_rate')) {
    await db.customStatement(
      "ALTER TABLE users ADD COLUMN sweat_rate TEXT NOT NULL DEFAULT 'medium'"
    );
  }

  // 3. Add sync columns to activities table
  final activitiesColumns = await db.customSelect("PRAGMA table_info(activities)").get();
  final activitiesColumnNames = activitiesColumns.map((row) => row.read<String>('name')).toSet();

  // External provider sync tracking
  if (!activitiesColumnNames.contains('synced_from_provider')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN synced_from_provider TEXT');
  }
  if (!activitiesColumnNames.contains('provider_workout_id')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN provider_workout_id TEXT');
  }
  if (!activitiesColumnNames.contains('provider_workout_url')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN provider_workout_url TEXT');
  }
  if (!activitiesColumnNames.contains('last_synced_at')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN last_synced_at INTEGER');
  }

  // Workout subtype
  if (!activitiesColumnNames.contains('workout_subtype')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN workout_subtype TEXT');
  }

  // Pace ranges
  if (!activitiesColumnNames.contains('pace_min_minutes_per_mile')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN pace_min_minutes_per_mile REAL');
  }
  if (!activitiesColumnNames.contains('pace_max_minutes_per_mile')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN pace_max_minutes_per_mile REAL');
  }

  // Swimming distance in meters
  if (!activitiesColumnNames.contains('distance_meters')) {
    await db.customStatement('ALTER TABLE activities ADD COLUMN distance_meters REAL');
  }

  // 4. Create index for synced activities (if not exists)
  try {
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_activities_provider_sync
      ON activities(synced_from_provider, provider_workout_id)
    ''');
  } catch (e) {
    // Index may already exist - safe to ignore
    if (kDebugMode) {
      print('Index creation note: $e');
    }
  }

  // ========================================================================
  // COACH MODE TABLES AND COLUMNS
  // ========================================================================

  // 5. Add is_coach column to users table
  if (!usersColumnNames.contains('is_coach')) {
    await db.customStatement(
      'ALTER TABLE users ADD COLUMN is_coach INTEGER NOT NULL DEFAULT 0'
    );
    if (kDebugMode) {
      print('Added is_coach column to users table');
    }
  }

  // 6. Create coach_athlete_relationships table
  try {
    await m.createTable(schema.coachAthleteRelationships);
    if (kDebugMode) {
      print('Created coach_athlete_relationships table');
    }
  } catch (e) {
    // Table may already exist
    if (kDebugMode) {
      print('coach_athlete_relationships table note: $e');
    }
  }

  // 7. Create coach_messages table
  try {
    await m.createTable(schema.coachMessages);
    if (kDebugMode) {
      print('Created coach_messages table');
    }
  } catch (e) {
    // Table may already exist
    if (kDebugMode) {
      print('coach_messages table note: $e');
    }
  }

  // 8. Create indexes for coach mode tables
  try {
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_car_coach_user ON coach_athlete_relationships(coach_user_id)'
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_car_athlete ON coach_athlete_relationships(athlete_user_id)'
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_car_status ON coach_athlete_relationships(status)'
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cm_coach ON coach_messages(coach_user_id)'
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cm_athlete ON coach_messages(athlete_user_id)'
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cm_conversation ON coach_messages(coach_user_id, athlete_user_id, created_at)'
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cm_activity ON coach_messages(activity_id)'
    );
  } catch (e) {
    if (kDebugMode) {
      print('Coach mode index creation note: $e');
    }
  }

  if (kDebugMode) {
    print('V2->V3 migration completed: Final Surge integration + sweat_rate + coach mode');
  }
}
