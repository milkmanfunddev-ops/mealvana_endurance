import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../models/version_check_result.dart';
import '../models/dirty_record_backup.dart';
import '../models/upload_error.dart';
import 'dirty_record_backup_service.dart';
import 'logging_service.dart';

// Repository imports for collecting dirty records
import '../../features/activities/data/activities_repository.dart';
import '../../features/events/data/events_repository.dart';
import '../../features/food_preferences/data/food_preferences_repository.dart';
import '../../features/user_foods/data/user_foods_repository.dart';
import '../../features/carb_loading/data/carb_loading_repository.dart';
import '../../features/nutrition_plan/data/food_repository.dart';
import '../../features/feedback/data/feedback_repository.dart';
import '../../features/coach_mode/data/coach_repository.dart';
import '../../features/auth/data/user_repository.dart';

part 'version_check_service.g.dart';

/// Service for checking app version and schema version against remote configuration
///
/// This service queries the app_config table in Supabase to determine if:
/// 1. The app version meets the minimum required version
/// 2. The local schema version matches the remote schema version
///
/// Results are cached in SharedPreferences to handle network failures gracefully.
@Riverpod(keepAlive: true)
VersionCheckService versionCheckService(Ref ref) {
  final supabase = Supabase.instance.client;
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.read(appLoggerProvider);
  final backupService = DirtyRecordBackupService(logger: logger);

  return VersionCheckService(
    supabase: supabase,
    database: database,
    logger: logger,
    backupService: backupService,
    ref: ref,
  );
}

class VersionCheckService {
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final DirtyRecordBackupService _backupService;
  final Ref _ref;

  // SharedPreferences keys for caching
  static const _keyMinAppVersion = 'cached_min_app_version';
  static const _keyRemoteSchemaVersion = 'cached_remote_schema_version';
  static const _keyCacheTimestamp = 'version_check_cache_timestamp';

  // Cache expiration: 24 hours
  static const _cacheExpiration = Duration(hours: 24);

  // Supabase query timeout
  static const _queryTimeout = Duration(seconds: 5);

  VersionCheckService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required DirtyRecordBackupService backupService,
    required Ref ref,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _backupService = backupService,
        _ref = ref;

  /// Check app version and schema version against remote configuration
  ///
  /// Returns:
  /// - [VersionCheckResult.ok] if versions are compatible
  /// - [VersionCheckResult.updateRequired] if app version is too low
  /// - [VersionCheckResult.resyncRequired] if schema version mismatch
  ///
  /// On network failure, returns cached result if available and not expired.
  Future<VersionCheckResult> checkVersion() async {
    try {
      // Query app_config table with timeout
      final response = await _supabase
          .from('app_config')
          .select('key, value')
          .inFilter('key', ['min_app_version', 'current_schema_version'])
          .timeout(_queryTimeout);

      // Parse response
      final Map<String, String> config = {};
      for (final row in response as List<dynamic>) {
        config[row['key'] as String] = row['value'] as String;
      }

      final minAppVersion = config['min_app_version'];
      final remoteSchemaVersionStr = config['current_schema_version'];

      if (minAppVersion == null || remoteSchemaVersionStr == null) {
        throw Exception('Missing required config keys in app_config table');
      }

      final remoteSchemaVersion = int.parse(remoteSchemaVersionStr);

      // Cache the results
      await _cacheVersionInfo(minAppVersion, remoteSchemaVersion);

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Get local schema version
      final localSchemaVersion = _database.schemaVersion;

      // Compare versions and return result
      return _compareVersions(
        currentVersion: currentVersion,
        minAppVersion: minAppVersion,
        localSchemaVersion: localSchemaVersion,
        remoteSchemaVersion: remoteSchemaVersion,
      );
    } catch (e) {
      // On failure, try to use cached result
      return await _getCachedResult();
    }
  }

  /// Perform schema resync when schema version mismatch is detected.
  ///
  /// This method:
  /// 1. Collects dirty records from all repositories
  /// 2. Attempts to upload them to Supabase (with retries)
  /// 3. If upload fails, creates backup to JSON file
  /// 4. Deletes the local database
  /// 5. Returns true if successful, false if critical failure
  ///
  /// IMPORTANT: The database must be reinitialized after this method returns true.
  /// The app should restart or reinitialize the database connection.
  Future<bool> performSchemaResync(String userId) async {
    try {
      _logger.info(
        'Starting schema resync',
        context: 'VERSION_CHECK_SERVICE',
        data: {
          'userId': userId,
          'localSchema': _database.schemaVersion,
        },
      );

      // Step 1: Collect all dirty records from repositories
      final dirtyRecords = await _collectDirtyRecords(userId);

      // Step 2: Try to upload dirty records
      final uploadErrors = <UploadError>[];
      if (dirtyRecords.isNotEmpty) {
        _logger.info(
          'Found dirty records to upload',
          context: 'VERSION_CHECK_SERVICE',
          data: {
            'repositories': dirtyRecords.keys.toList(),
            'totalRecords': dirtyRecords.values.fold<int>(
              0,
              (sum, records) => sum + records.length,
            ),
          },
        );

        // Try to upload each repository's dirty records
        for (final entry in dirtyRecords.entries) {
          final repoKey = entry.key;
          final records = entry.value;

          try {
            await _uploadDirtyRecordsForRepository(repoKey, userId, records);
            _logger.info(
              'Successfully uploaded dirty records',
              context: 'VERSION_CHECK_SERVICE',
              data: {'repository': repoKey, 'count': records.length},
            );
          } catch (e, stackTrace) {
            _logger.error(
              'Failed to upload dirty records',
              context: 'VERSION_CHECK_SERVICE',
              error: e,
              stackTrace: stackTrace,
              data: {'repository': repoKey},
            );

            uploadErrors.add(UploadError(
              repository: repoKey,
              error: e.toString(),
              timestamp: DateTime.now(),
            ));
          }
        }

        // Step 3: If any uploads failed, create backup
        if (uploadErrors.isNotEmpty) {
          _logger.warning(
            'Some dirty records failed to upload, creating backup',
            context: 'VERSION_CHECK_SERVICE',
            data: {'failedRepositories': uploadErrors.length},
          );

          final packageInfo = await PackageInfo.fromPlatform();
          final backup = DirtyRecordBackup(
            backupCreatedAt: DateTime.now(),
            appVersion: packageInfo.version,
            schemaVersion: _database.schemaVersion,
            userId: userId,
            dirtyRecords: dirtyRecords,
            uploadErrors: uploadErrors,
          );

          await _backupService.backupDirtyRecords(backup);
        }
      }

      // Step 4: Delete the database files
      _logger.info(
        'Deleting database for schema resync',
        context: 'VERSION_CHECK_SERVICE',
      );

      await AppDatabase.deleteAndResync();

      _logger.info(
        'Schema resync completed successfully',
        context: 'VERSION_CHECK_SERVICE',
        data: {
          'dirtyRecordsBackedUp': uploadErrors.isNotEmpty,
        },
      );

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Schema resync failed',
        context: 'VERSION_CHECK_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Collect all dirty records from all repositories.
  ///
  /// Returns a map of repository keys to lists of dirty record JSON objects.
  Future<Map<String, List<Map<String, dynamic>>>> _collectDirtyRecords(
    String userId,
  ) async {
    final dirtyRecords = <String, List<Map<String, dynamic>>>{};

    // Get all repositories
    final activitiesRepo = _ref.read(activitiesRepositoryProvider);
    final eventsRepo = _ref.read(eventsRepositoryProvider);
    final foodPrefsRepo = _ref.read(foodPreferencesRepositoryProvider);
    final userFoodsRepo = _ref.read(userFoodsRepositoryProvider);
    final carbLoadingRepo = _ref.read(carbLoadingRepositoryProvider);
    final foodRepo = _ref.read(foodRepositoryProvider);
    final feedbackRepo = _ref.read(feedbackRepositoryProvider);
    final coachRepo = _ref.read(coachRepositoryProvider);
    final userRepo = _ref.read(userRepositoryProvider);

    // Collect dirty records from each repository
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'activities',
      userId,
      activitiesRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'events',
      userId,
      eventsRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'food_preferences',
      userId,
      foodPrefsRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'user_foods',
      userId,
      userFoodsRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'carb_loading_plans',
      userId,
      carbLoadingRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'foods',
      userId,
      foodRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'feedback',
      userId,
      feedbackRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'coaches',
      userId,
      coachRepo,
    );
    await _collectDirtyRecordsFromRepository(
      dirtyRecords,
      'users',
      userId,
      userRepo,
    );

    return dirtyRecords;
  }

  /// Helper method to collect dirty records from a single repository.
  Future<void> _collectDirtyRecordsFromRepository(
    Map<String, List<Map<String, dynamic>>> dirtyRecords,
    String repoKey,
    String userId,
    dynamic repository,
  ) async {
    try {
      // Query dirty records using repository's uploadDirtyRecords method
      // This will return UploadResult, but we need the actual records
      // For now, we'll query the database directly based on repository key

      final records = await _queryDirtyRecords(repoKey, userId);
      if (records.isNotEmpty) {
        dirtyRecords[repoKey] = records;
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to collect dirty records from repository',
        context: 'VERSION_CHECK_SERVICE',
        error: e,
        stackTrace: stackTrace,
        data: {'repository': repoKey},
      );
    }
  }

  /// Query dirty records directly from the database.
  ///
  /// This is a workaround since repositories don't expose a method to
  /// get dirty records without uploading them.
  ///
  /// Uses raw SQL queries to handle the dynamic table access pattern.
  Future<List<Map<String, dynamic>>> _queryDirtyRecords(
    String repoKey,
    String userId,
  ) async {
    // Map repository keys to SQL table names
    final tableNameMap = {
      'activities': 'activities',
      'events': 'events',
      'food_preferences': 'food_preferences',
      'user_foods': 'user_foods',
      'carb_loading_plans': 'carb_loading_plans',
      'foods': 'foods',
      'feedback': 'feedback',
      'coaches': 'coaches',
      'users': 'user_profiles',
    };

    final tableName = tableNameMap[repoKey];
    if (tableName == null) {
      _logger.warning(
        'Unknown repository key, skipping dirty records collection',
        context: 'VERSION_CHECK_SERVICE',
        data: {'repository': repoKey},
      );
      return [];
    }

    // Query dirty records from the table using raw SQL
    // This allows dynamic table access that Drift's typed API doesn't support
    try {
      // Query all records where is_synced = 0 (dirty records)
      // Note: Not all tables have is_synced column, so we catch errors
      final results = await _database.customSelect(
        'SELECT * FROM $tableName WHERE is_synced = 0 AND user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();

      // Convert to JSON maps
      return results.map((row) => row.data).toList();
    } catch (e) {
      // Table might not have is_synced or user_id columns
      // Try without filters as fallback
      try {
        final results = await _database.customSelect(
          'SELECT * FROM $tableName',
        ).get();
        return results.map((row) => row.data).toList();
      } catch (e2) {
        _logger.warning(
          'Failed to query dirty records from table',
          context: 'VERSION_CHECK_SERVICE',
          data: {'repository': repoKey, 'error': e2.toString()},
        );
        return [];
      }
    }
  }

  /// Upload dirty records for a specific repository.
  Future<void> _uploadDirtyRecordsForRepository(
    String repoKey,
    String userId,
    List<Map<String, dynamic>> records,
  ) async {
    // Map repository keys to Supabase table names
    final tableMap = {
      'activities': 'activities',
      'events': 'events',
      'food_preferences': 'food_preferences',
      'user_foods': 'user_foods',
      'carb_loading_plans': 'carb_loading_plans',
      'foods': 'foods',
      'feedback': 'feedback',
      'coaches': 'coaches',
      'users': 'users',
    };

    final tableName = tableMap[repoKey];
    if (tableName == null) {
      throw Exception('Unknown repository key: $repoKey');
    }

    // Upload to Supabase using upsert
    await _supabase.from(tableName).upsert(records);
  }

  /// Compare versions and return appropriate result
  VersionCheckResult _compareVersions({
    required String currentVersion,
    required String minAppVersion,
    required int localSchemaVersion,
    required int remoteSchemaVersion,
  }) {
    // Check app version first (higher priority)
    final current = Version.parse(currentVersion);
    final required = Version.parse(minAppVersion);

    if (current < required) {
      return VersionCheckResult.updateRequired(
        currentVersion: currentVersion,
        requiredVersion: minAppVersion,
      );
    }

    // Check schema version
    if (localSchemaVersion != remoteSchemaVersion) {
      return VersionCheckResult.resyncRequired(
        localSchemaVersion: localSchemaVersion,
        remoteSchemaVersion: remoteSchemaVersion,
      );
    }

    return const VersionCheckResult.ok();
  }

  /// Cache version info in SharedPreferences
  Future<void> _cacheVersionInfo(
    String minAppVersion,
    int remoteSchemaVersion,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMinAppVersion, minAppVersion);
    await prefs.setInt(_keyRemoteSchemaVersion, remoteSchemaVersion);
    await prefs.setInt(
      _keyCacheTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get cached version check result
  ///
  /// Returns [VersionCheckResult.ok] if cache is expired or missing
  Future<VersionCheckResult> _getCachedResult() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if cache exists and is not expired
    final cacheTimestamp = prefs.getInt(_keyCacheTimestamp);
    if (cacheTimestamp != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      if (cacheAge > _cacheExpiration.inMilliseconds) {
        // Cache expired, return ok to allow app to start
        return const VersionCheckResult.ok();
      }
    }

    // Try to get cached values
    final cachedMinVersion = prefs.getString(_keyMinAppVersion);
    final cachedRemoteSchema = prefs.getInt(_keyRemoteSchemaVersion);

    if (cachedMinVersion == null || cachedRemoteSchema == null) {
      // No cache available, return ok to allow app to start
      return const VersionCheckResult.ok();
    }

    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // Get local schema version
    final localSchemaVersion = _database.schemaVersion;

    // Compare using cached values
    return _compareVersions(
      currentVersion: currentVersion,
      minAppVersion: cachedMinVersion,
      localSchemaVersion: localSchemaVersion,
      remoteSchemaVersion: cachedRemoteSchema,
    );
  }

  /// Clear cached version info (useful for testing)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMinAppVersion);
    await prefs.remove(_keyRemoteSchemaVersion);
    await prefs.remove(_keyCacheTimestamp);
  }
}
