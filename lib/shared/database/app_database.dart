import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// Platform-specific connection implementations
import 'connection_native.dart' if (dart.library.html) 'connection_web.dart';

// Table definitions
import 'tables/user_profiles.dart';
import 'tables/food_preferences.dart';
import 'tables/feedback.dart';
import 'tables/foods_table.dart';
import 'tables/app_content_table.dart';
import 'tables/edge_functions_table.dart';
import 'tables/user_foods_table.dart';
import 'tables/activities_table.dart';
import 'tables/events_table.dart';
import 'tables/carb_loading_plans_table.dart';
import 'tables/carb_loading_days_table.dart';
import 'tables/carb_loading_foods_table.dart';
import 'tables/carb_loading_user_foods_table.dart';
import 'tables/carb_loading_day_meals_table.dart';
import 'tables/weather_forecasts_table.dart';
import 'tables/integrations_table.dart';
import 'tables/coaches_table.dart';
import 'tables/coach_athlete_relationships_table.dart';
import 'tables/coach_messages_table.dart';
import 'tables/template_foods_table.dart';
import 'tables/templates_table.dart';
import 'tables/during_workout_templates_table.dart';
import 'tables/pre_workout_templates_table.dart';
import 'tables/post_workout_templates_table.dart';
import 'tables/tp_writeback_table.dart';
import 'tables/personal_templates_table.dart';
import 'tables/formula_pins_table.dart';
import 'tables/personal_formulas_table.dart';
import 'tables/athlete_pairing_codes_table.dart';
import 'tables/coach_pairing_codes_table.dart';
import 'tables/daily_macro_targets_table.dart';
import 'tables/race_checklist_items_table.dart';
import 'tables/meal_logs_table.dart';
import 'tables/saved_meals_table.dart';
import 'tables/recipes_table.dart';

// DAOs (extracted for modularity)
import 'daos/user_dao.dart';
import 'daos/food_preferences_dao.dart';
import 'daos/activity_dao.dart';
import 'daos/foods_dao.dart';
import 'daos/content_dao.dart';
import 'daos/diagnostic_dao.dart';

part 'app_database.g.dart';

/// Main Drift database for the Mealvana Endurance app.
///
/// This class provides access to all database operations through DAOs:
/// - [userDao] - User profile CRUD and authentication
/// - [foodPreferencesDao] - Food preference management
/// - [activityDao] - Activity and nutrition plan storage
/// - [foodsDao] - Food catalog and user foods
/// - [contentDao] - App content caching and surveys
/// - [diagnosticDao] - Data clearing, migration, and health checks
///
/// Example usage:
/// ```dart
/// final db = ref.read(appDatabaseProvider);
/// final user = await db.userDao.getCurrentUserProfile(currentAuthUserId: authId);
/// final foods = await db.foodsDao.getAllCachedFoods();
/// ```
@DriftDatabase(
  tables: [
    // Core tables aligned with Supabase
    UserProfilesTable,
    FoodPreferencesTable,
    FeedbackTable,

    // Food system tables
    FoodsTable,

    // User-specific food tables
    UserFoodsTable,

    // Content management
    AppContentTable,

    // Additional features
    EdgeFunctionsTable,

    // Calendar feature tables
    ActivitiesTable,
    EventsTable,
    RaceChecklistItemsTable,
    CarbLoadingPlansTable,
    CarbLoadingDaysTable,

    // Carb Loading Food tables
    CarbLoadingFoodsTable,
    CarbLoadingUserFoodsTable,
    CarbLoadingDayMealsTable,

    // Weather feature tables
    WeatherForecastsTable,

    // External integrations (Final Surge, TrainingPeaks, Strava, etc.)
    IntegrationsTable,

    // Coach mode tables
    CoachesTable,
    CoachAthleteRelationshipsTable,
    CoachMessagesTable,

    // Template system tables (read-only reference data)
    TemplateFoodsTable,
    TemplatesTable,
    DuringWorkoutTemplatesTable,
    PreWorkoutTemplatesTable,
    PostWorkoutTemplatesTable,

    // TrainingPeaks write-back tracking
    TpWritebackTable,

    // Personal nutrition plan templates
    PersonalTemplatesTable,

    // Formula Kit pins (user preference signal for plan generation)
    FormulaPinsTable,

    // Formula Kit personal formulas (user-authored fueling recipes)
    PersonalFormulasTable,

    // Pairing codes for coach connections
    AthletePairingCodesTable,
    CoachPairingCodesTable,

    // Daily macro targets cache
    DailyMacroTargetsTable,

    // Meal logging (Daily Macros tab) + saved favorites
    MealLogsTable,
    SavedMealsTable,

    // Curated recipe catalog (read-only mirror)
    RecipesTable,
  ],
  daos: [
    UserDao,
    FoodPreferencesDao,
    ActivityDao,
    FoodsDao,
    ContentDao,
    DiagnosticDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with in-memory database
  factory AppDatabase.memory() {
    return AppDatabase._internal(createNativeMemoryDatabase());
  }

  /// Constructor for migration testing with SchemaVerifier
  /// Allows injecting a custom QueryExecutor for testing migrations
  factory AppDatabase.forTesting(QueryExecutor executor) {
    return AppDatabase._internal(executor);
  }

  /// Internal constructor for factory
  AppDatabase._internal(super.e);

  @override
  /// Schema version 11: meal logging + Jade groundwork. Adds three tables:
  ///   • meal_logs   — logged meals on the Daily Macros tab (offline-first,
  ///     soft-deleted via is_deleted, needs_upload dirty tracking)
  ///   • saved_meals — explicit user favorites for one-tap re-logging
  ///   • recipes     — read-only mirror of the curated recipe catalog
  /// Jade chat tables (jade_conversations/jade_messages/jade_calls) are
  /// online-only and have NO Drift mirror. Supabase schema:
  /// docs/database/meal_logging_jade_schema.sql (applied dev + prod).
  /// NOTE: the matching Supabase `app_config` schema version (read by
  /// VersionCheckService) must be set to 11 when this ships.
  ///
  /// Schema version 10: adds `personal_formulas` — Formula Kit personal
  /// formulas (user-authored fueling recipes, forked or from-scratch, tied to
  /// a phase). Distinct table from personal_templates; soft-deleted via
  /// is_deleted. Standalone createTable in the `from < 10` ladder step.
  /// NOTE: the matching Supabase `app_config` schema version (read by
  /// VersionCheckService) must be set to 10 when this ships, or v9 clients
  /// won't migrate consistently. Apply the personal_formulas table SQL
  /// (docs/database/apply_all.sql §4) to Supabase before/with that bump.
  ///
  /// Schema version 9: Formula Kit local tables — a single consolidated bump
  /// from the last released schema (v8). Adds four tables that were developed
  /// across unreleased intermediate versions on the feat/formula-kit branch;
  /// since none of those interim versions ever shipped, they collapse into
  /// one v9 migration:
  ///   • during_workout_templates — read-only During-phase formula catalog
  ///   • pre_workout_templates    — read-only Before-phase formula catalog
  ///     (replaces the legacy `templates` table for Before formulas)
  ///   • post_workout_templates   — read-only After-phase formula catalog
  ///     (v2 Notion shape; `travel_friendliness` filter + `selection_priority`)
  ///   • formula_pins             — user pin signal for plan generation,
  ///     soft-deleted via `is_deleted` so unpin propagates across devices
  ///     (matches the user_foods soft-delete convention)
  /// NOTE: the matching `app_config` schema version on Supabase (read by
  /// VersionCheckService as latest/current_schema_version) must be set to 9
  /// when this ships, or existing v8 clients won't migrate consistently.
  /// v8 added needs_upload column to integrations so OAuth tokens are
  /// mirrored to Supabase and survive Drift schema resyncs / reinstalls.
  /// (v8 also includes 'vdot' in the integrations.provider CHECK and
  /// 'requires_reauth' in the last_sync_status CHECK — added 2026-05-18,
  /// before v8 shipped.)
  /// v7 added activities.garmin_device_name (Garmin brand-compliant
  /// attribution), sweat profile fields on users (sweat_sodium,
  /// known_sweat_rate_ml_per_hour, known_sodium_concentration_mg_per_liter,
  /// sweat_test_date, sweat_test_source) for hydration/sodium transparency, and
  /// users.weight_pounds_updated_at + users.body_fat_pct_updated_at for Garmin
  /// body-comp precedence resolution. Formalizes previously-runtime column/table
  /// additions.
  /// v6 added athlete_pairing_codes table for coach-athlete connections.
  /// v5 added personal_templates table for user-saved nutrition plan templates.
  /// v4 added template_foods and templates tables for nutrition templates.
  /// v3 added intensity distribution and default pace columns.
  int get schemaVersion => 12;

  /// Ensure sync tracking columns exist for user-authored tables.
  /// Uses ALTER TABLE IF NOT EXISTS which is supported in modern SQLite (3.35+).
  Future<void> ensureUserDataSyncColumns() async {
    // v1 ships with the correct schema; skip runtime ALTERs to avoid legacy migrations.
    return;
  }

  /// Database setup with delete-and-resync migration strategy.
  ///
  /// Schema changes are handled by VersionCheckService at app startup:
  /// 1. App checks `current_schema_version` in Supabase `app_config` table
  /// 2. If local schemaVersion != remote, dirty records are uploaded
  /// 3. Local database is deleted and recreated fresh
  /// 4. Data is resynced from Supabase
  ///
  /// This eliminates complex step-by-step migrations in favor of a simpler
  /// delete-and-resync approach controlled by the server.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // No step-by-step migrations - schema mismatches trigger delete & resync
      // via VersionCheckService before the database is even opened.
      // If we somehow get here with a version mismatch, recreate all tables.
      onUpgrade: (Migrator m, int from, int to) async {
        // v7: Add sweat profile + body-comp precedence columns to users.
        // Note: SQLite does NOT support `ADD COLUMN IF NOT EXISTS`. The
        // `from < 7` guard provides idempotency by version.
        if (from < 7) {
          await customStatement(
            'ALTER TABLE users ADD COLUMN sweat_sodium TEXT',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN known_sweat_rate_ml_per_hour INTEGER',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN known_sodium_concentration_mg_per_liter INTEGER',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN sweat_test_date INTEGER',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN sweat_test_source TEXT',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN weight_pounds_updated_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN body_fat_pct_updated_at INTEGER',
          );
        }

        // v8: Add needs_upload column to integrations so existing OAuth
        // tokens get backed up to Supabase on the next sync. Default 1 so
        // every pre-existing row is treated as dirty exactly once — Supabase
        // had no integrations table before this, so we need to seed it.
        if (from < 8) {
          await customStatement(
            'ALTER TABLE integrations ADD COLUMN needs_upload INTEGER NOT NULL DEFAULT 1',
          );
        }

        // v9: Formula Kit local tables — a single consolidated step from the
        // last released schema (v8). Creates all four mirrors/pin tables for a
        // user upgrading from v8: the during/pre/post workout template mirrors
        // plus formula_pins. These were developed across unreleased interim
        // versions (during=9, pre=10, formula_pins=11, post=12 on the feature
        // branch); none shipped, so they collapse into one step. None of them
        // reference each other via FK locally, so creation order is for
        // readability only. (Previously post_workout_templates was added to
        // the @DriftDatabase table set + the schemaVersion bump but never to
        // this ladder, so upgrading users hit the schema-integrity safety net
        // and were force-wiped — folding it in here is the fix.)
        if (from < 9) {
          await m.createTable(duringWorkoutTemplatesTable);
          await m.createTable(preWorkoutTemplatesTable);
          await m.createTable(postWorkoutTemplatesTable);
          await m.createTable(formulaPinsTable);
        }

        // v10: Formula Kit personal formulas — user-authored fueling recipes
        // (forked from a system formula or built from scratch), tied to a
        // phase. A distinct concept from personal_templates, so it gets its
        // own table. Soft-deleted via is_deleted. No local FK references, so
        // creation is standalone.
        if (from < 10) {
          await m.createTable(personalFormulasTable);
        }

        // v11: Meal logging + Jade groundwork — meal_logs (offline-first log
        // entries), saved_meals (user favorites), recipes (read-only catalog
        // mirror). No local FK references between them, so creation order is
        // for readability only.
        if (from < 11) {
          await m.createTable(mealLogsTable);
          await m.createTable(savedMealsTable);
          await m.createTable(recipesTable);
        }

        // v12: Coach AI insight persistence — two nullable TEXT columns on
        // personal_formulas so the generated insight survives navigation.
        if (from < 12) {
          await customStatement(
            'ALTER TABLE personal_formulas ADD COLUMN coach_insight_text TEXT',
          );
          await customStatement(
            'ALTER TABLE personal_formulas ADD COLUMN coach_insight_marker TEXT',
          );
        }
      },

      // Called when database is first created (version 0 -> current)
      onCreate: (Migrator m) async {
        // Check which tables already exist (from seed DB)
        final existingTablesResult = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        ).get();

        final existingTables = existingTablesResult
            .map((row) => row.read<String>('name'))
            .toSet();

        // Seed tables (already have data - must NOT be recreated)
        final seedTables = {
          'foods',
          'carb_loading_foods',
          'user_foods',
        };

        // For each table definition, manually create with IF NOT EXISTS
        for (final table in allTables) {
          final tableName = table.actualTableName;

          // Skip tables that already exist AND are seed tables (have data)
          if (existingTables.contains(tableName) &&
              seedTables.contains(tableName)) {
            continue;
          }

          await m.createTable(table);
        }

        await _populateDefaultData();
      },

      // Called immediately after database is opened
      beforeOpen: (details) async {
        // Enable foreign key support (required for Drift)
        await customStatement('PRAGMA foreign_keys = ON');

        if (kDebugMode) {
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = 10000');
        }

        // Schema integrity validation - fail fast if schema is corrupted
        if (!details.wasCreated) {
          // Repair the integrations.provider CHECK in place before validating.
          // CHECK constraints are baked into the table at CREATE time, so
          // adding 'vdot' to the Dart definition doesn't update tables that
          // already exist on-device. We keep schemaVersion at 9, so this
          // idempotent repair (not a version bump) is what fixes existing
          // installs that reject `provider = 'vdot'` inserts.
          await _ensureIntegrationsProviderCheck();

          await _validateSchemaIntegrity();
        }

        // Normalize any legacy timestamp strings in user_foods to Unix millis
        await foodsDao.normalizeUserFoodTimestamps();
      },
    );
  }

  /// Populate default data for fresh installations
  Future<void> _populateDefaultData() async {
    // No longer need to populate default data - using enums now
  }

  /// Validate schema integrity on database open.
  ///
  /// Uses Drift's `allTables` to automatically check that all expected tables
  /// and columns exist in the database. This is version-agnostic.
  ///
  /// If validation fails, it will:
  /// 1. Delete the corrupted database
  /// 2. Throw a [DatabaseSchemaException] to trigger app restart
  Future<void> _validateSchemaIntegrity() async {
    final errors = <String>[];

    for (final table in allTables) {
      final tableName = table.actualTableName;

      try {
        final actualColumns = await customSelect(
          "PRAGMA table_info('$tableName')",
        ).get();

        if (actualColumns.isEmpty) {
          errors.add('Table "$tableName" does not exist');
          continue;
        }

        final actualColumnNames = actualColumns
            .map((row) => row.read<String>('name'))
            .toSet();

        final expectedColumnNames = table.$columns
            .map((col) => col.$name)
            .toSet();

        final missingColumns = expectedColumnNames.difference(actualColumnNames);
        if (missingColumns.isNotEmpty) {
          errors.add('Table "$tableName" missing columns: ${missingColumns.join(', ')}');
        }
      } catch (e) {
        errors.add('Failed to validate table "$tableName": $e');
      }
    }

    if (errors.isNotEmpty) {
      if (kDebugMode) {
        for (final error in errors) {
          print('❌ Schema validation failed: $error');
        }
        print('🗑️ Deleting corrupted database to force fresh sync...');
      }

      await deleteAndResync();

      throw DatabaseSchemaException(
        'Database schema is corrupted or incomplete. The app will resync data from the server.',
        errors: errors,
      );
    }

    if (kDebugMode) {
      print('✅ Schema validation passed (${allTables.length} tables verified)');
    }
  }

  /// Ensure the `integrations.provider` CHECK constraint allows 'vdot'.
  ///
  /// SQLite stores CHECK constraints as part of the table's CREATE statement,
  /// so editing the Dart table definition (which now lists 'vdot') does NOT
  /// alter tables that were created before 'vdot' was added — those keep
  /// rejecting `provider = 'vdot'` inserts with a CHECK failure (code 275).
  /// Bumping schemaVersion would trigger a delete-and-resync, but we're
  /// deliberately staying on v9, so instead we repair the constraint in place:
  /// detect a stale CHECK and, if found, rebuild the table preserving its rows.
  /// Idempotent — once the CHECK includes 'vdot' this is a no-op on open.
  Future<void> _ensureIntegrationsProviderCheck() async {
    final rows = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'integrations'",
    ).get();
    if (rows.isEmpty) return; // missing table is handled by schema validation
    final createSql = rows.first.read<String?>('sql') ?? '';
    if (createSql.contains("'vdot'")) return; // already up to date

    if (kDebugMode) {
      print('🔧 Rebuilding integrations table to add \'vdot\' to provider CHECK');
    }

    // FK toggling must happen outside a transaction; the rebuild itself is a
    // standard SQLite table recreation (rename → create → copy → drop).
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      // Clean up any half-finished rebuild from a prior interrupted open.
      await customStatement('DROP TABLE IF EXISTS _integrations_legacy');
      await customStatement(
        'ALTER TABLE integrations RENAME TO _integrations_legacy',
      );
      // Recreate from the current Dart definition (includes the updated CHECK
      // and the UNIQUE(user_id, provider) constraint).
      await createMigrator().createTable(integrationsTable);
      // Explicit column list — physical column order differs across installs
      // (needs_upload was appended via ALTER on the v7→v8 path), so a bare
      // `SELECT *` copy is unsafe.
      const cols =
          'id, user_id, provider, access_token, refresh_token, '
          'token_expires_at, provider_athlete_id, provider_athlete_name, '
          'provider_athlete_email, provider_athlete_weight_kg, '
          'provider_athlete_birth_month, provider_athlete_gender, '
          'provider_athlete_body_fat_pct, athlete_zones_json, is_active, '
          'last_sync_at, last_sync_status, last_sync_error, needs_upload, '
          'created_at, updated_at';
      await customStatement(
        'INSERT INTO integrations ($cols) SELECT $cols FROM _integrations_legacy',
      );
      await customStatement('DROP TABLE _integrations_legacy');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  // === Database Health & Recovery Methods ===

  /// Check if database is healthy using PRAGMA integrity_check
  /// Returns true if database passes integrity check, false otherwise
  Future<bool> isDatabaseHealthy() async {
    try {
      final result = await customSelect('PRAGMA integrity_check').get();

      if (result.isEmpty) {
        return false;
      }

      final integrityCheck = result.first.data['integrity_check'] as String?;
      return integrityCheck == 'ok';
    } catch (e) {
      // If we can't even run the integrity check, database is unhealthy
      return false;
    }
  }

  /// Quick health check - try to execute a simple query
  /// Returns true if database can execute basic queries, false otherwise
  Future<bool> canExecuteQueries() async {
    try {
      // Try to count records in users table (always exists)
      await customSelect('SELECT COUNT(*) FROM users').get();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Circuit breaker: prevents infinite loops when schema recovery fails
  ///
  /// If we delete and recreate the database but the Drift schema itself is wrong,
  /// we'd loop forever. This flag ensures we only attempt recovery ONCE per app session.
  static bool _schemaRecoveryAttempted = false;

  /// Check if an exception is a schema-related SQLite error
  ///
  /// Returns true for errors that indicate schema mismatch:
  /// - CHECK constraint failed (code 275 / SQLITE_CONSTRAINT_CHECK)
  /// - No such column (code 1 / SQLITE_ERROR with column message)
  /// - Table doesn't exist
  /// - Foreign key constraint failed (code 787 / SQLITE_CONSTRAINT_FOREIGNKEY)
  static bool isSchemaError(Object error) {
    final errorString = error.toString().toLowerCase();

    // Check for common schema-related error patterns
    return errorString.contains('check constraint failed') ||
           errorString.contains('no such column') ||
           errorString.contains('no such table') ||
           errorString.contains('foreign key constraint failed') ||
           errorString.contains('constraint failed') ||
           errorString.contains('has no column named') ||
           errorString.contains('table') && errorString.contains('has no column');
  }

  /// Handle a schema error by closing DB, deleting files, and triggering resync
  ///
  /// Call this from repositories when catching exceptions that might be schema-related.
  /// If the error is a schema error, this closes the database, deletes the files,
  /// and throws [DatabaseSchemaException] to trigger app reinitialization.
  ///
  /// IMPORTANT: Pass the database instance so the connection can be closed before
  /// deleting files. Otherwise the in-memory connection will recreate the old schema.
  ///
  /// Example usage in a repository:
  /// ```dart
  /// try {
  ///   await _database.into(_database.activities).insert(companion);
  /// } catch (e) {
  ///   if (AppDatabase.isSchemaError(e)) {
  ///     await AppDatabase.handleSchemaError(e, database: _database);
  ///   }
  ///   rethrow;
  /// }
  /// ```
  static Future<void> handleSchemaError(
    Object error, {
    String? context,
    AppDatabase? database,
  }) async {
    if (!isSchemaError(error)) {
      return; // Not a schema error, don't handle
    }

    // Circuit breaker: only attempt recovery once per app session
    if (_schemaRecoveryAttempted) {
      if (kDebugMode) {
        print('🔧 Schema error detected but recovery already attempted this session');
        print('   Context: ${context ?? 'unknown'}');
        print('   Error: $error');
        print('   → Not retrying to prevent infinite loop. Please fix the Drift schema.');
      }
      // Don't retry, just rethrow the original error
      return;
    }

    // Mark that we're attempting recovery (before we actually do it)
    _schemaRecoveryAttempted = true;

    if (kDebugMode) {
      print('🔧 Schema error detected - deleting database and resyncing (one-time recovery)');
      print('   Context: ${context ?? 'unknown'}');
      print('   Error: $error');
    }

    // CRITICAL: Close the database connection BEFORE deleting files
    // Otherwise the in-memory connection recreates the old schema
    if (database != null) {
      try {
        await database.close();
        if (kDebugMode) {
          print('🔧 Database connection closed');
        }
      } catch (closeError) {
        if (kDebugMode) {
          print('🔧 Warning: Error closing database: $closeError');
        }
      }
    }

    // Delete the database files
    await deleteAndResync();

    // Throw exception to signal app needs to reinitialize database
    throw DatabaseSchemaException(
      'Schema mismatch detected. Database deleted - app will resync on restart.',
      errors: [error.toString()],
    );
  }

  /// Delete corrupted database and trigger full resync.
  ///
  /// This is the safest recovery strategy:
  /// 1. Close all database connections
  /// 2. Delete corrupted file
  /// 3. Re-initialize fresh database
  /// 4. Trigger full sync from Supabase
  static Future<void> deleteAndResync() async {
    try {
      final dbPath = await _getDatabasePath();

      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Delete WAL and SHM files if they exist
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }

      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
    } catch (e) {
      throw Exception('Database recovery failed: $e');
    }
  }

  /// Get the platform-specific database file path
  static Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      throw UnsupportedError('Database file path not available on web');
    }

    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'mealvana_endurance_db.sqlite');
  }
}

/// Database connection setup with seed database support.
/// Implementation is platform-specific (see connection_native.dart / connection_web.dart).
QueryExecutor _openConnection() => openNativeConnection();

/// Exception thrown when database schema validation fails.
///
/// This exception indicates that the database schema is corrupted or incomplete,
/// typically due to a failed migration. The database has been deleted and the
/// app needs to restart to create a fresh database and resync.
class DatabaseSchemaException implements Exception {
  final String message;
  final List<String> errors;

  DatabaseSchemaException(this.message, {this.errors = const []});

  @override
  String toString() {
    if (errors.isEmpty) {
      return 'DatabaseSchemaException: $message';
    }
    return 'DatabaseSchemaException: $message\nErrors: ${errors.join(', ')}';
  }
}
