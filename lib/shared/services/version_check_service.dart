import 'dart:async';
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
import 'sync/sync_dependency_graph.dart';

// Repository imports for uploadDirtyRecords
import '../../features/activities/data/activities_repository.dart';
import '../../features/events/data/events_repository.dart';
import '../../features/food_preferences/data/food_preferences_repository.dart';
import '../../features/carb_loading/data/carb_loading_repository.dart';
import '../../features/feedback/data/feedback_repository.dart';
import '../../features/integrations/presentation/providers/integrations_providers.dart';
import '../../features/user_foods/data/user_foods_repository.dart';
import '../data/syncable_repository.dart';

part 'version_check_service.g.dart';

/// Service for checking app version and schema version against remote configuration
///
/// This service queries the app_config table in Supabase to determine if:
/// 1. The app version meets the minimum required version
/// 2. The local schema version is within the server-supported schema window
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
  static const _keyMinSupportedSchemaVersion =
      'cached_min_supported_schema_version';
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
  }) : _supabase = supabase,
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
          .inFilter('key', [
            'min_app_version',
            'current_schema_version',
            'latest_schema_version',
            'min_supported_schema_version',
            'min_supported_schema',
          ])
          .timeout(_queryTimeout);

      // Parse response
      final Map<String, String> config = {};
      for (final row in response as List<dynamic>) {
        config[row['key'] as String] = row['value'] as String;
      }

      final minAppVersion = config['min_app_version'];
      final latestSchemaVersionStr =
          config['latest_schema_version'] ?? config['current_schema_version'];
      final minSupportedSchemaVersionStr =
          config['min_supported_schema_version'] ??
          config['min_supported_schema'];
      final compatibilityWindowEnabled =
          minSupportedSchemaVersionStr != null ||
          config.containsKey('latest_schema_version');

      if (minAppVersion == null || latestSchemaVersionStr == null) {
        throw Exception('Missing required config keys in app_config table');
      }

      final latestSchemaVersion = int.parse(latestSchemaVersionStr);
      final minSupportedSchemaVersion = minSupportedSchemaVersionStr != null
          ? int.parse(minSupportedSchemaVersionStr)
          : latestSchemaVersion;

      if (minSupportedSchemaVersion > latestSchemaVersion) {
        throw Exception(
          'Invalid app_config: min_supported_schema_version cannot be greater than latest_schema_version',
        );
      }

      // Cache the results
      await _cacheVersionInfo(
        minAppVersion,
        latestSchemaVersion,
        minSupportedSchemaVersion,
      );

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
        latestSchemaVersion: latestSchemaVersion,
        minSupportedSchemaVersion: minSupportedSchemaVersion,
        compatibilityWindowEnabled: compatibilityWindowEnabled,
      );
    } catch (e) {
      // On failure, try to use cached result
      return await _getCachedResult();
    }
  }

  /// Perform schema resync when schema version mismatch is detected.
  ///
  /// This method:
  /// 1. Attempts to upload dirty records from all repositories using uploadDirtyRecords
  /// 2. If upload fails, logs errors (repositories handle backup internally)
  /// 3. Deletes the local database
  /// 4. Returns true if successful, false if critical failure
  ///
  /// IMPORTANT: The database must be reinitialized after this method returns true.
  /// The app should restart or reinitialize the database connection.
  ///
  /// **Anonymous data protection** (onboarding-redesign plan §7): when the
  /// current user is anonymous (or the auth session is gone entirely) and
  /// dirty local rows could not reach Supabase, deleting the database would
  /// destroy the only copy of their data. In that case the resync is
  /// DEFERRED — [wasDeferredForDataProtection] is set, no delete happens,
  /// and the caller continues on the old schema; the mismatch retries next
  /// launch, by which point the upload has usually succeeded.
  bool wasDeferredForDataProtection = false;

  Future<bool> performSchemaResync(
    String? userId, {
    int? targetSchemaVersion,
  }) async {
    wasDeferredForDataProtection = false;
    try {
      _logger.info(
        'Starting schema resync',
        context: 'VERSION_CHECK_SERVICE',
        data: {
          'userId': userId ?? 'null',
          'localSchema': _database.schemaVersion,
        },
      );

      // Step 1 & 2: Upload dirty records using repository methods
      final uploadErrors = <UploadError>[];
      if (userId != null) {
        final repos = await _getUploadableRepositories();
        for (final entry in repos.entries) {
          try {
            final result = await entry.value.uploadDirtyRecords(userId);
            if (!result.success) {
              uploadErrors.add(
                UploadError(
                  repository: entry.key,
                  error: result.error ?? 'Upload failed',
                  timestamp: DateTime.now(),
                ),
              );
            }
          } catch (e) {
            uploadErrors.add(
              UploadError(
                repository: entry.key,
                error: e.toString(),
                timestamp: DateTime.now(),
              ),
            );
          }
        }

        // Step 3: If any uploads failed, create backup with error details
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
            dirtyRecords:
                {}, // Empty - records are safely stored locally with needs_upload=true
            uploadErrors: uploadErrors,
          );

          await _backupService.backupDirtyRecords(backup);
        }
      } else {
        _logger.info(
          'Skipping dirty record upload - no userId available',
          context: 'VERSION_CHECK_SERVICE',
        );
      }

      // Step 3.5: Anonymous data-protection guard. If dirty rows could not
      // be uploaded (offline, or no auth session at all) and the local user
      // is anonymous — meaning Supabase may hold no copy of this data —
      // deleting now would be unrecoverable. Defer instead.
      final shouldGuard = userId == null || uploadErrors.isNotEmpty;
      if (shouldGuard && await _hasUnprotectedAnonymousData(userId)) {
        wasDeferredForDataProtection = true;
        _logger.warning(
          'Deferring schema resync: anonymous user has dirty local rows '
          'that did not reach Supabase — deleting would lose them. '
          'Will retry on next launch.',
          context: 'VERSION_CHECK_SERVICE',
          data: {
            'userId': userId ?? 'null',
            'failedUploads': uploadErrors.length,
          },
        );
        return false;
      }

      // Step 4: Delete the database files
      _logger.info(
        'Deleting database for schema resync',
        context: 'VERSION_CHECK_SERVICE',
      );

      await AppDatabase.deleteAndResync(
        reason: 'remote_schema_version_resync',
        oldSchemaVersion: _database.schemaVersion,
        newSchemaVersion: targetSchemaVersion,
      );

      // Step 5: Clear all repository sync staleness timestamps from SharedPreferences.
      // Without this, controllers calling ensureSynced() after the DB is recreated
      // would see stale-but-recent timestamps and skip syncing, leaving the DB empty.
      final prefs = await SharedPreferences.getInstance();
      final repoKeys = SyncDependencyGraph.repositoryKeys;
      for (final key in repoKeys) {
        await prefs.remove('${key}_last_sync');
      }

      _logger.info(
        'Schema resync completed successfully',
        context: 'VERSION_CHECK_SERVICE',
        data: {
          'dirtyRecordsBackedUp': uploadErrors.isNotEmpty,
          'staleness_timestamps_cleared': repoKeys.length,
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

  /// True when the local database holds an anonymous user with any dirty
  /// (`needs_upload = 1`) rows — the state where delete-and-resync would
  /// destroy the only copy of that user's data.
  ///
  /// With [userId] null (no auth session) any anonymous user row counts;
  /// with a session, only that user's rows are checked.
  Future<bool> _hasUnprotectedAnonymousData(String? userId) async {
    try {
      final userFilter = userId != null ? "AND id = '$userId'" : '';
      final anonUsers = await _database
          .customSelect(
            'SELECT id FROM users WHERE is_anonymous = 1 $userFilter',
          )
          .get();
      if (anonUsers.isEmpty) return false;

      final ids = anonUsers.map((r) => "'${r.read<String>('id')}'").join(',');
      // The tables onboarding + core usage write locally-first. A dirty user
      // row alone also counts — it carries the whole profile.
      for (final table in [
        'users',
        'onboarding_surveys',
        'activities',
        'events',
        'meal_logs',
      ]) {
        final idColumn = table == 'users' ? 'id' : 'user_id';
        final rows = await _database
            .customSelect(
              'SELECT 1 FROM $table WHERE needs_upload = 1 '
              'AND $idColumn IN ($ids) LIMIT 1',
            )
            .get();
        if (rows.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      // If the check itself fails, err toward protecting data.
      _logger.warning(
        'Anonymous-data check failed; deferring resync defensively',
        context: 'VERSION_CHECK_SERVICE',
        data: {'error': e.toString()},
      );
      return true;
    }
  }

  /// Get all repositories that support uploadDirtyRecords.
  ///
  /// Returns a map of repository keys to SyncableRepository instances.
  Future<Map<String, SyncableRepository>> _getUploadableRepositories() async {
    return {
      'activities': _ref.read(activitiesRepositoryProvider),
      'events': _ref.read(eventsRepositoryProvider),
      'carb_loading': _ref.read(carbLoadingRepositoryProvider),
      'feedback': _ref.read(feedbackRepositoryProvider),
      'food_preferences': await _ref.read(
        foodPreferencesRepositoryProvider.future,
      ),
      'integrations': _ref.read(integrationsRepositoryProvider),
      'user_foods': await _ref.read(userFoodsRepositoryProvider.future),
    };
  }

  /// Compare versions and return appropriate result
  VersionCheckResult _compareVersions({
    required String currentVersion,
    required String minAppVersion,
    required int localSchemaVersion,
    required int latestSchemaVersion,
    required int minSupportedSchemaVersion,
    required bool compatibilityWindowEnabled,
  }) {
    // Check app version first (higher priority)
    // Strip pre-release suffixes (e.g. "1.15.1-dev" → "1.15.1") so that
    // debug/profile builds are treated as the release version.
    final current = Version.parse(currentVersion);
    final currentBase = Version(current.major, current.minor, current.patch);
    final required = Version.parse(minAppVersion);

    if (currentBase < required) {
      return VersionCheckResult.updateRequired(
        currentVersion: currentVersion,
        requiredVersion: minAppVersion,
      );
    }

    if (localSchemaVersion < latestSchemaVersion) {
      if (compatibilityWindowEnabled) {
        // Reject schemas below server minimum support window.
        // Returning updateRequired here avoids delete/recreate loops for older apps.
        if (localSchemaVersion < minSupportedSchemaVersion) {
          return VersionCheckResult.updateRequired(
            currentVersion: currentVersion,
            requiredVersion: minAppVersion,
          );
        }

        // Schema is behind latest but still within compatibility window.
        return const VersionCheckResult.ok();
      }

      return VersionCheckResult.resyncRequired(
        localSchemaVersion: localSchemaVersion,
        remoteSchemaVersion: latestSchemaVersion,
      );
    }

    return const VersionCheckResult.ok();
  }

  /// Cache version info in SharedPreferences
  Future<void> _cacheVersionInfo(
    String minAppVersion,
    int remoteSchemaVersion,
    int minSupportedSchemaVersion,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMinAppVersion, minAppVersion);
    await prefs.setInt(_keyRemoteSchemaVersion, remoteSchemaVersion);
    await prefs.setInt(
      _keyMinSupportedSchemaVersion,
      minSupportedSchemaVersion,
    );
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
    final cachedMinSupportedSchema = prefs.getInt(
      _keyMinSupportedSchemaVersion,
    );

    if (cachedMinVersion == null || cachedRemoteSchema == null) {
      // No cache available, return ok to allow app to start
      return const VersionCheckResult.ok();
    }

    final minSupportedSchemaVersion =
        cachedMinSupportedSchema ?? cachedRemoteSchema;
    final compatibilityWindowEnabled = cachedMinSupportedSchema != null;

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
      latestSchemaVersion: cachedRemoteSchema,
      minSupportedSchemaVersion: minSupportedSchemaVersion,
      compatibilityWindowEnabled: compatibilityWindowEnabled,
    );
  }

  /// Clear cached version info (useful for testing)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMinAppVersion);
    await prefs.remove(_keyRemoteSchemaVersion);
    await prefs.remove(_keyMinSupportedSchemaVersion);
    await prefs.remove(_keyCacheTimestamp);
  }
}
