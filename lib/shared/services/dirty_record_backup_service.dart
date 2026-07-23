import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:mealvana_endurance/shared/models/dirty_record_backup.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

/// Service for backing up and recovering dirty records.
///
/// When dirty records cannot be uploaded to Supabase (e.g., network failure,
/// server error), this service backs them up to a JSON file in the App Support
/// directory. This ensures user data is not lost during schema migrations or
/// sync operations.
///
/// **Backup Flow:**
/// 1. Attempt to upload dirty records (with retries)
/// 2. If all retries fail, create backup file
/// 3. Log warning to Sentry
/// 4. Proceed with sync (data is backed up)
///
/// **Recovery Flow:**
/// 1. On app startup, check for backup file
/// 2. If found, prompt user to upload or discard
/// 3. Attempt upload if user chooses
/// 4. Delete backup file after successful upload or user discard
class DirtyRecordBackupService {
  static const String _backupFileName = 'dirty_records_backup.json';
  final AppLogger _logger;

  DirtyRecordBackupService({required AppLogger logger}) : _logger = logger;

  /// Get the backup file path in Application Support directory
  Future<File> _getBackupFile() async {
    final appSupport = await getApplicationSupportDirectory();
    return File('${appSupport.path}/$_backupFileName');
  }

  /// Create a backup of dirty records
  ///
  /// This should be called when dirty records cannot be uploaded after retries.
  /// The backup is saved to App Support directory as JSON.
  Future<void> backupDirtyRecords(DirtyRecordBackup backup) async {
    try {
      final backupFile = await _getBackupFile();

      // Convert backup to JSON
      final jsonString = jsonEncode(backup.toJson());

      // Write to file
      await backupFile.writeAsString(jsonString);

      _logger.info(
        'Dirty records backed up successfully',
        data: {
          'record_count': backup.totalRecordCount,
          'repositories': backup.dirtyRecords.keys.toList(),
          'backup_path': backupFile.path,
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to backup dirty records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if a backup file exists
  Future<bool> hasBackup() async {
    try {
      final backupFile = await _getBackupFile();
      return await backupFile.exists();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check for backup file',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Recover dirty records from backup file
  ///
  /// Returns the DirtyRecordBackup if found, otherwise null.
  /// This should be called on app startup to check for unsaved data.
  Future<DirtyRecordBackup?> recoverBackup() async {
    try {
      final backupFile = await _getBackupFile();

      if (!await backupFile.exists()) {
        return null;
      }

      // Read and parse JSON
      final jsonString = await backupFile.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final backup = DirtyRecordBackup.fromJson(json);

      _logger.info(
        'Dirty record backup recovered',
        data: {
          'backup_created_at': backup.backupCreatedAt.toIso8601String(),
          'record_count': backup.totalRecordCount,
          'repositories': backup.dirtyRecords.keys.toList(),
          'app_version': backup.appVersion,
          'schema_version': backup.schemaVersion,
        },
      );

      return backup;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to recover backup',
        error: e,
        stackTrace: stackTrace,
      );
      // Return null instead of rethrowing - we don't want to block app startup
      return null;
    }
  }

  /// Delete the backup file
  ///
  /// This should be called after successfully uploading recovered records
  /// or when the user chooses to discard the backup.
  Future<void> deleteBackup() async {
    try {
      final backupFile = await _getBackupFile();

      if (await backupFile.exists()) {
        await backupFile.delete();
        _logger.info('Dirty record backup deleted');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete backup file',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get backup file path (for debugging/testing)
  Future<String> getBackupFilePath() async {
    final backupFile = await _getBackupFile();
    return backupFile.path;
  }
}
