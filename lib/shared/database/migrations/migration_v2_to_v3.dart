import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../schema_versions.dart';

/// V2 -> V3 Migration (December 2025)
///
/// Changes:
/// - Creates integrations table for Final Surge, TrainingPeaks, Strava OAuth tokens
/// - Adds sync columns to activities for external provider tracking:
///   - synced_from_provider, provider_workout_id, provider_workout_url, last_synced_at
/// - Adds workout metadata:
///   - workout_subtype, pace_min_minutes_per_mile, pace_max_minutes_per_mile, distance_meters
/// - Creates index for synced activities
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

  // 2. Add sync columns to activities table
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

  // 3. Create index for synced activities (if not exists)
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

  if (kDebugMode) {
    print('V2->V3 migration completed: Final Surge integration schema added');
  }
}
