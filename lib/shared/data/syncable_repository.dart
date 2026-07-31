import 'package:shared_preferences/shared_preferences.dart';

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int count;
  final String? error;

  const SyncResult({required this.success, required this.count, this.error});

  factory SyncResult.successful(int count) =>
      SyncResult(success: true, count: count);

  factory SyncResult.failed(String error) =>
      SyncResult(success: false, count: 0, error: error);
}

/// Result of an upload operation
class UploadResult {
  final bool success;
  final int count;
  final String? error;

  const UploadResult({required this.success, required this.count, this.error});

  factory UploadResult.successful(int count) =>
      UploadResult(success: true, count: count);

  factory UploadResult.nothingToUpload() =>
      const UploadResult(success: true, count: 0);

  factory UploadResult.failed(String error) =>
      UploadResult(success: false, count: 0, error: error);
}

/// Mixin for repositories that support synchronization.
///
/// This mixin provides the core interface for repository-level sync with:
/// - Staleness tracking (1-hour threshold by default)
/// - SharedPreferences-based timestamp storage
/// - Dependency declaration for sync ordering
/// - Upload and download operations
///
/// Implementations must:
/// - Define a unique [repositoryKey] for staleness tracking
/// - Specify [dependencies] that must be synced first
/// - Implement [syncFromRemote] to download data from Supabase
/// - Implement [uploadDirtyRecords] to upload local changes
mixin SyncableRepository {
  /// Unique identifier for this repository used in SharedPreferences.
  ///
  /// Examples: 'users', 'activities', 'events', 'food_preferences'
  String get repositoryKey;

  /// List of repository keys that must be synced before this repository.
  ///
  /// Examples:
  /// - 'users' → [] (no dependencies)
  /// - 'activities' → ['users']
  /// - 'food_preferences' → ['users', 'foods']
  List<String> get dependencies => [];

  /// Duration after which data is considered stale and requires resync.
  ///
  /// Default: 1 hour (reduced from 24h to ensure athletes see coach changes quickly)
  static const staleDuration = Duration(hours: 1);

  /// Check if this repository's data is stale and needs syncing.
  ///
  /// Data is stale if:
  /// - Never been synced (no timestamp in SharedPreferences)
  /// - Last sync was more than [staleDuration] ago
  Future<bool> isStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    return DateTime.now().difference(lastSync) > staleDuration;
  }

  /// Get the last sync timestamp from SharedPreferences.
  ///
  /// Returns null if never synced.
  /// Uses key pattern: '{repositoryKey}_last_sync'
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${repositoryKey}_last_sync';
    final timestamp = prefs.getString(key);

    if (timestamp == null) return null;

    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      // Invalid timestamp - treat as never synced
      return null;
    }
  }

  /// Update the last sync timestamp in SharedPreferences.
  ///
  /// Stores as ISO8601 string for human readability.
  /// Uses key pattern: '{repositoryKey}_last_sync'
  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${repositoryKey}_last_sync';
    await prefs.setString(key, time.toIso8601String());
  }

  /// Sync this repository's data from Supabase.
  ///
  /// This method should:
  /// 1. Query Supabase for fresh data
  /// 2. Save to local Drift database
  /// 3. Update last sync timestamp via [setLastSyncTime]
  ///
  /// Called by SyncCoordinator after dependencies are synced.
  Future<SyncResult> syncFromRemote(String userId);

  /// Upload dirty records (needs_upload = true) for this repository.
  ///
  /// This method should:
  /// 1. Query local Drift database for dirty records
  /// 2. Upload to Supabase (upsert)
  /// 3. Clear dirty flags on success
  /// 4. Return count of uploaded records
  ///
  /// Called by SyncCoordinator before syncing fresh data.
  Future<UploadResult> uploadDirtyRecords(String userId);
}
