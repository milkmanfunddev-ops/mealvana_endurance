import 'dart:io';
import 'dart:math';

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
import 'tables/tp_writeback_table.dart';
import 'tables/personal_templates_table.dart';
import 'tables/athlete_pairing_codes_table.dart';
import 'tables/coach_pairing_codes_table.dart';
import 'tables/daily_macro_targets_table.dart';
import 'tables/race_checklist_items_table.dart';

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

    // TrainingPeaks write-back tracking
    TpWritebackTable,

    // Personal nutrition plan templates
    PersonalTemplatesTable,

    // Pairing codes for coach connections
    AthletePairingCodesTable,
    CoachPairingCodesTable,

    // Daily macro targets cache
    DailyMacroTargetsTable,
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
  /// Schema version 6: Adds athlete_pairing_codes table for coach-athlete connections.
  /// v5 added personal_templates table for user-saved nutrition plan templates.
  /// v4 added template_foods and templates tables for nutrition templates.
  /// v3 added intensity distribution and default pace columns.
  int get schemaVersion => 6;

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
        // This should rarely run since VersionCheckService handles mismatches.
        // If it does run, just recreate the database.
        await m.createAll();
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

        // Runtime column additions (OTA-safe, no schema version bump needed).
        // SQLite ALTER TABLE ADD COLUMN is safe for nullable columns.
        // Catches "duplicate column" error for idempotency on subsequent launches.
        await _addColumnIfNotExists('users', 'email', 'TEXT');
        await _addColumnIfNotExists('activities', 'fuel_log_data', 'TEXT');

        // Daily macro calculation fields
        await _addColumnIfNotExists('users', 'body_fat_pct', 'REAL');
        await _addColumnIfNotExists('users', 'lifestyle', "TEXT DEFAULT 'mixed'");
        await _addColumnIfNotExists('users', 'typical_weekly_hours', 'REAL');
        await _addColumnIfNotExists('users', 'carb_cycle_opt_in', 'INTEGER DEFAULT 0');
        await _addColumnIfNotExists('users', 'training_phase', "TEXT DEFAULT 'base'");
        await _addColumnIfNotExists('activities', 'tss', 'REAL');

        // Garmin body composition pull
        await _addColumnIfNotExists(
            'integrations', 'provider_athlete_body_fat_pct', 'REAL');

        // Create daily_macro_targets table if not exists
        await customStatement('''
          CREATE TABLE IF NOT EXISTS daily_macro_targets (
            id TEXT NOT NULL PRIMARY KEY,
            user_id TEXT NOT NULL,
            target_date INTEGER NOT NULL,
            carb_g REAL NOT NULL,
            prot_g REAL NOT NULL,
            fat_g REAL NOT NULL,
            tdee REAL NOT NULL,
            rmr REAL NOT NULL,
            session_kcal REAL NOT NULL DEFAULT 0,
            neat_kcal REAL,
            tef_kcal REAL,
            mode TEXT NOT NULL DEFAULT 'prospective',
            ea REAL,
            ea_status TEXT,
            calculation_input TEXT,
            algorithm_version TEXT NOT NULL DEFAULT 'v4',
            needs_upload INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
            UNIQUE(user_id, target_date)
          )
        ''');

        // Create coach_pairing_codes table if not exists
        await customStatement('''
          CREATE TABLE IF NOT EXISTS coach_pairing_codes (
            id TEXT NOT NULL PRIMARY KEY,
            coach_user_id TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
            expires_at INTEGER NOT NULL,
            used_by_athlete_id TEXT,
            used_at INTEGER
          )
        ''');

        // Create race_checklist_items table if not exists (local-only feature)
        await customStatement('''
          CREATE TABLE IF NOT EXISTS race_checklist_items (
            id TEXT NOT NULL PRIMARY KEY,
            event_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            category TEXT NOT NULL,
            item_name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_checked INTEGER NOT NULL DEFAULT 0,
            checked_at INTEGER,
            notes TEXT,
            is_template_item INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
            CHECK (category IN ('gear', 'nutrition', 'logistics', 'pre_race', 'race_morning'))
          )
        ''');

        // Schema integrity validation - fail fast if schema is corrupted
        if (!details.wasCreated) {
          await _validateSchemaIntegrity();
        }

        // Normalize any legacy timestamp strings in user_foods to Unix millis
        await foodsDao.normalizeUserFoodTimestamps();
      },
    );
  }

  /// Add a column to a table if it doesn't already exist.
  /// SQLite doesn't support IF NOT EXISTS for ALTER TABLE ADD COLUMN,
  /// so we catch the "duplicate column name" error for idempotency.
  Future<void> _addColumnIfNotExists(
    String table,
    String column,
    String type,
  ) async {
    try {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      // SQLite throws "duplicate column name" if column already exists - safe to ignore
      if (!e.toString().contains('duplicate column name')) {
        rethrow;
      }
    }
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
LazyDatabase _openConnection() => openNativeConnection();

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
