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
import 'tables/feature_survey_responses_table.dart';
import 'tables/integrations_table.dart';
import 'tables/coaches_table.dart';
import 'tables/coach_athlete_relationships_table.dart';
import 'tables/coach_messages_table.dart';

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
    CarbLoadingPlansTable,
    CarbLoadingDaysTable,

    // Carb Loading Food tables
    CarbLoadingFoodsTable,
    CarbLoadingUserFoodsTable,
    CarbLoadingDayMealsTable,

    // Weather feature tables
    WeatherForecastsTable,

    // Feature survey tables
    FeatureSurveyResponsesTable,

    // External integrations (Final Surge, TrainingPeaks, Strava, etc.)
    IntegrationsTable,

    // Coach mode tables
    CoachesTable,
    CoachAthleteRelationshipsTable,
    CoachMessagesTable,
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
  int get schemaVersion => 3;

  /// Ensure sync tracking columns exist for user-authored tables.
  /// Uses ALTER TABLE IF NOT EXISTS which is supported in modern SQLite (3.35+).
  Future<void> ensureUserDataSyncColumns() async {
    // v1 ships with the correct schema; skip runtime ALTERs to avoid legacy migrations.
    return;
  }

  /// V3 database setup with simplified migration strategy.
  /// Schema changes trigger delete & resync via VersionCheckService (Phase 4.3).
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
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

  // === Database Health & Recovery Methods ===

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
