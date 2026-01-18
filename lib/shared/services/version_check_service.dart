import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../models/version_check_result.dart';

part 'version_check_service.g.dart';

/// Service for checking app version and schema version against remote configuration
///
/// This service queries the app_config table in Supabase to determine if:
/// 1. The app version meets the minimum required version
/// 2. The local schema version matches the remote schema version
///
/// Results are cached in SharedPreferences to handle network failures gracefully.
@Riverpod(keepAlive: true)
VersionCheckService versionCheckService(VersionCheckServiceRef ref) {
  final supabase = Supabase.instance.client;
  final database = ref.watch(appDatabaseProvider);
  return VersionCheckService(supabase: supabase, database: database);
}

class VersionCheckService {
  final SupabaseClient _supabase;
  final AppDatabase _database;

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
  })  : _supabase = supabase,
        _database = database;

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
