import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../services/performance_telemetry.dart';

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
  /// Schema version 14: build-a-meal redesign — `meal_logs.slot` becomes
  /// optional (nullable). SQLite has no `ALTER COLUMN ... DROP NOT NULL`, so
  /// the `from < 14` step rebuilds the table (rename → recreate via the
  /// current `mealLogsTable` definition, which is now nullable → copy rows →
  /// drop the renamed original). Guarded on the live column's `notnull` flag
  /// (via PRAGMA table_info) so it's safe to re-run if a web `user_version`
  /// hiccup replays this step. Matching Supabase SQL (dev + prod):
  /// `ALTER TABLE meal_logs ALTER COLUMN slot DROP NOT NULL;` (see the
  /// meal-logging redesign notes — NOT bundled with this migration, applied
  /// out-of-band by the orchestrator).
  ///
  /// v14 also adds `activities.is_fasted` (INTEGER NOT NULL DEFAULT 0) so a
  /// plan generated fasted regenerates fasted. Folded into the existing v14
  /// step (not a v15 bump) because v14 has not shipped to any user. The
  /// matching Supabase column (`activities.is_fasted boolean not null
  /// default false`) already exists on dev + prod.
  ///
  /// Schema version 11: meal logging + Mealvana AI groundwork. Adds three tables:
  ///   • meal_logs   — logged meals on the Daily Macros tab (offline-first,
  ///     soft-deleted via is_deleted, needs_upload dirty tracking)
  ///   • saved_meals — explicit user favorites for one-tap re-logging
  ///   • recipes     — read-only mirror of the curated recipe catalog
  /// Mealvana AI chat tables (jade_conversations/jade_messages/jade_calls) are
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
  int get schemaVersion => 15;

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
        // Idempotent migration primitives. SQLite has no `ADD COLUMN IF NOT
        // EXISTS` / `CREATE TABLE` guard that plays nicely with drift's
        // Migrator, and on WEB the persisted `user_version` does not reliably
        // advance after a migration commits (drift wasm / IndexedDB quirk) — so
        // the same `from < N` step can re-run on the next launch and blow up
        // with "duplicate column" / "table already exists", which then trips
        // the recovery path (fatal on web, no file to delete). Guarding every
        // step on the actual schema makes re-runs harmless.
        Future<bool> columnExists(String table, String column) async {
          final rows = await customSelect('PRAGMA table_info($table)').get();
          return rows.any((r) => r.read<String>('name') == column);
        }

        Future<void> addColumn(String table, String column, String type) async {
          if (!await columnExists(table, column)) {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN $column $type',
            );
          }
        }

        Future<bool> tableExists(String table) async {
          final rows = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
            variables: [Variable.withString(table)],
          ).get();
          return rows.isNotEmpty;
        }

        Future<void> ensureTable(TableInfo table) async {
          if (!await tableExists(table.actualTableName)) {
            await m.createTable(table);
          }
        }

        /// Returns true when [column] on [table] is currently declared
        /// `NOT NULL` (PRAGMA table_info's `notnull` flag). Used to guard the
        /// "make a column nullable" rebuild below so it's idempotent even if a
        /// web `user_version` hiccup replays the `from < N` step.
        Future<bool> columnIsNotNull(String table, String column) async {
          final rows = await customSelect('PRAGMA table_info($table)').get();
          for (final r in rows) {
            if (r.read<String>('name') == column) {
              return r.read<int>('notnull') == 1;
            }
          }
          return false;
        }

        // v7: Add sweat profile + body-comp precedence columns to users.
        if (from < 7) {
          await addColumn('users', 'sweat_sodium', 'TEXT');
          await addColumn('users', 'known_sweat_rate_ml_per_hour', 'INTEGER');
          await addColumn(
            'users',
            'known_sodium_concentration_mg_per_liter',
            'INTEGER',
          );
          await addColumn('users', 'sweat_test_date', 'INTEGER');
          await addColumn('users', 'sweat_test_source', 'TEXT');
          await addColumn('users', 'weight_pounds_updated_at', 'INTEGER');
          await addColumn('users', 'body_fat_pct_updated_at', 'INTEGER');
        }

        // v8: Add needs_upload column to integrations so existing OAuth
        // tokens get backed up to Supabase on the next sync. Default 1 so
        // every pre-existing row is treated as dirty exactly once — Supabase
        // had no integrations table before this, so we need to seed it.
        if (from < 8) {
          await addColumn(
            'integrations',
            'needs_upload',
            'INTEGER NOT NULL DEFAULT 1',
          );
        }

        // v9: Formula Kit local tables — during/pre/post workout template
        // mirrors plus formula_pins. Consolidated from unreleased interim
        // versions; no local FK references, so creation order is readability.
        if (from < 9) {
          await ensureTable(duringWorkoutTemplatesTable);
          await ensureTable(preWorkoutTemplatesTable);
          await ensureTable(postWorkoutTemplatesTable);
          await ensureTable(formulaPinsTable);
        }

        // v10: Formula Kit personal formulas — user-authored fueling recipes.
        if (from < 10) {
          await ensureTable(personalFormulasTable);
        }

        // v11: Meal logging + Mealvana AI groundwork — meal_logs, saved_meals,
        // recipes. No local FK references between them.
        if (from < 11) {
          await ensureTable(mealLogsTable);
          await ensureTable(savedMealsTable);
          await ensureTable(recipesTable);
        }

        // v12: Coach AI insight persistence — two nullable TEXT columns on
        // personal_formulas so the generated insight survives navigation.
        if (from < 12) {
          await addColumn('personal_formulas', 'coach_insight_text', 'TEXT');
          await addColumn('personal_formulas', 'coach_insight_marker', 'TEXT');
        }

        // v13: Mirror `selection_priority` onto the local during-workout
        // template table so the client-side default-formula selector (used to
        // seed onboarding pins) can rank by it, matching the post table.
        if (from < 13) {
          await addColumn(
            'during_workout_templates',
            'selection_priority',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }

        // v14 (part 2): persist the fasted flag the nutrition plan was
        // generated with. addColumn is idempotent, so a web user_version
        // replay of this step is harmless.
        if (from < 14) {
          await addColumn(
            'activities',
            'is_fasted',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }

        // v14: build-a-meal redesign — meal_logs.slot becomes optional.
        // SQLite can't ALTER COLUMN to drop NOT NULL, so rebuild the table:
        // rename the old one aside, recreate via the (now-nullable) current
        // `mealLogsTable` definition, copy rows across, drop the renamed
        // original. Guarded on the live NOT NULL flag + a resumable temp-table
        // check so a web user_version replay can't crash on a half-done
        // rebuild or double-copy rows.
        if (from < 14) {
          const tempName = 'meal_logs_pre_v14';
          if (await tableExists('meal_logs') &&
              await columnIsNotNull('meal_logs', 'slot')) {
            if (!await tableExists(tempName)) {
              await customStatement(
                'ALTER TABLE meal_logs RENAME TO $tempName',
              );
            }
            if (!await tableExists('meal_logs')) {
              await m.createTable(mealLogsTable);
            }
            if (await tableExists(tempName)) {
              await customStatement('''
                INSERT OR IGNORE INTO meal_logs (
                  id, user_id, log_date, slot, name, source, items,
                  calories, carbs_g, protein_g, fat_g, sodium_mg,
                  photo_path, recipe_id, saved_meal_id, notes, eaten_at,
                  created_at, updated_at, is_deleted, needs_upload,
                  local_updated_at
                )
                SELECT
                  id, user_id, log_date, slot, name, source, items,
                  calories, carbs_g, protein_g, fat_g, sodium_mg,
                  photo_path, recipe_id, saved_meal_id, notes, eaten_at,
                  created_at, updated_at, is_deleted, needs_upload,
                  local_updated_at
                FROM $tempName
              ''');
              await customStatement('DROP TABLE $tempName');
            }
          }
        }

        // v15: repair `activities.is_fasted` on installs that were already at
        // v14 when that column was introduced.
        //
        // The column was originally added inside the `from < 14` step above
        // ("v14 (part 2)"). Devices that had ALREADY migrated to v14 before
        // that step existed never re-run it — Drift skips onUpgrade entirely
        // when `from == to` — so they sat at schemaVersion 14 with the column
        // missing. The startup integrity check then found
        //   Table "activities" missing columns: is_fasted
        // and WIPED the local database to recover, losing any unsynced local
        // data (Sentry MEALVANA-ENDURANCE-DEV-60 / DEV-61, 4 users).
        //
        // Bumping to 15 is what actually fixes it: it forces onUpgrade to run
        // again for those installs. addColumn is idempotent, so devices that
        // already picked the column up via the v14 path are unaffected.
        if (from < 15) {
          await addColumn(
            'activities',
            'is_fasted',
            'INTEGER NOT NULL DEFAULT 0',
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
        final seedTables = {'foods', 'carb_loading_foods', 'user_foods'};

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
          // adding a provider (first 'vdot', later 'runna') to the Dart
          // definition doesn't update tables that already exist on-device. We
          // deliberately do NOT bump schemaVersion for this CHECK fix, so this
          // idempotent in-place repair (not a version bump) is what fixes
          // existing installs that reject inserts for the new provider.
          await PerformanceTelemetry.measure(
            'database.ensure_integrations_constraint',
            _ensureIntegrationsProviderCheck,
            threshold: const Duration(milliseconds: 500),
          );

          await PerformanceTelemetry.measure(
            'database.validate_schema',
            _validateSchemaIntegrity,
            data: {'table_count': allTables.length},
            threshold: const Duration(milliseconds: 500),
          );
        }

        // Normalize any legacy timestamp strings in user_foods to Unix millis
        await PerformanceTelemetry.measure(
          'database.normalize_user_food_timestamps',
          foodsDao.normalizeUserFoodTimestamps,
          threshold: const Duration(milliseconds: 500),
        );
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

        final missingColumns = expectedColumnNames.difference(
          actualColumnNames,
        );
        if (missingColumns.isNotEmpty) {
          errors.add(
            'Table "$tableName" missing columns: ${missingColumns.join(', ')}',
          );
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

      await deleteAndResync(
        reason: 'schema_integrity_validation_failed',
        oldSchemaVersion: schemaVersion,
        newSchemaVersion: schemaVersion,
        context: errors.take(3).join(' | '),
      );

      throw DatabaseSchemaException(
        'Database schema is corrupted or incomplete. The app will resync data from the server.',
        errors: errors,
      );
    }

    if (kDebugMode) {
      print('✅ Schema validation passed (${allTables.length} tables verified)');
    }
  }

  /// Ensure the `integrations.provider` CHECK constraint allows every
  /// provider the app can write ('vdot' was added first, 'runna' later).
  ///
  /// SQLite stores CHECK constraints as part of the table's CREATE statement,
  /// so editing the Dart table definition does NOT alter tables that already
  /// exist on-device — those keep rejecting inserts for the new provider with
  /// a CHECK failure (code 275). Bumping schemaVersion would trigger a
  /// delete-and-resync, so instead we repair the constraint in place: detect
  /// a stale CHECK and, if found, rebuild the table preserving its rows.
  /// Idempotent — once the CHECK includes all required providers this is a
  /// no-op on open.
  Future<void> _ensureIntegrationsProviderCheck() async {
    final rows = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'integrations'",
    ).get();
    if (rows.isEmpty) return; // missing table is handled by schema validation
    final createSql = rows.first.read<String?>('sql') ?? '';
    // Providers added after the table first shipped — extend this list when a
    // new provider value is added to the CHECK in integrations_table.dart.
    const requiredProviders = ["'vdot'", "'runna'"];
    if (requiredProviders.every(createSql.contains)) {
      return; // already up to date
    }

    if (kDebugMode) {
      print(
        '🔧 Rebuilding integrations table to refresh the provider CHECK '
        '(needs: $requiredProviders)',
      );
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
        print(
          '🔧 Schema error detected but recovery already attempted this session',
        );
        print('   Context: ${context ?? 'unknown'}');
        print('   Error: $error');
        print(
          '   → Not retrying to prevent infinite loop. Please fix the Drift schema.',
        );
      }
      // Don't retry, just rethrow the original error
      return;
    }

    // Mark that we're attempting recovery (before we actually do it)
    _schemaRecoveryAttempted = true;

    if (kDebugMode) {
      print(
        '🔧 Schema error detected - deleting database and resyncing (one-time recovery)',
      );
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
    await deleteAndResync(
      reason: 'runtime_schema_error',
      oldSchemaVersion: database?.schemaVersion,
      context: context ?? error.runtimeType.toString(),
    );

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
  static Future<void> deleteAndResync({
    required String reason,
    int? oldSchemaVersion,
    int? newSchemaVersion,
    String? context,
  }) async {
    PerformanceTelemetry.recordDatabaseReset(
      reason: reason,
      oldSchemaVersion: oldSchemaVersion,
      newSchemaVersion: newSchemaVersion,
      context: context,
    );
    // On web there is no database file to delete — the drift data lives in
    // OPFS / IndexedDB, and there is no supported cross-implementation delete
    // we can call here. Recovery-by-file-deletion is native-only. Surface an
    // actionable schema exception instead of the previous cryptic
    // `UnsupportedError: Database file path not available on web`, which used
    // to bubble up as a fatal "Database recovery failed" white screen. Note
    // this path should be rare now that migrations are idempotent (see the
    // onUpgrade helpers) — it is reserved for genuine local-store corruption.
    if (kIsWeb) {
      throw DatabaseSchemaException(
        'Local database recovery is not available on web. Clear this site\'s '
        'data (browser Settings → Privacy → clear site data) and reload — your '
        'data re-syncs from the server on next sign-in.',
      );
    }
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

  /// Get the platform-specific database file path (native only — web has no
  /// file path; see [deleteAndResync]).
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
