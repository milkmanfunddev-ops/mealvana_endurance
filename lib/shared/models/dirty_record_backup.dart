import 'package:mealvana_endurance/shared/models/upload_error.dart';

/// Model representing a backup of dirty records that failed to upload.
///
/// This backup is created when dirty records cannot be uploaded to Supabase
/// before a schema migration or sync operation. It allows recovery of user
/// data in case of sync failures.
class DirtyRecordBackup {
  /// Timestamp when the backup was created
  final DateTime backupCreatedAt;

  /// App version at the time of backup (e.g., "1.12.1")
  final String appVersion;

  /// Drift schema version at the time of backup
  final int schemaVersion;

  /// User ID associated with the dirty records
  final String userId;

  /// Map of repository keys to lists of dirty records
  /// Example: {"activities": [...], "events": [...]}
  final Map<String, List<Map<String, dynamic>>> dirtyRecords;

  /// List of upload errors that occurred
  final List<UploadError> uploadErrors;

  DirtyRecordBackup({
    required this.backupCreatedAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.userId,
    required this.dirtyRecords,
    required this.uploadErrors,
  });

  /// Convert backup to JSON for file storage
  Map<String, dynamic> toJson() {
    return {
      'backup_created_at': backupCreatedAt.toIso8601String(),
      'app_version': appVersion,
      'schema_version': schemaVersion,
      'user_id': userId,
      'dirty_records': dirtyRecords,
      'upload_errors': uploadErrors.map((e) => e.toJson()).toList(),
    };
  }

  /// Create backup from JSON file
  factory DirtyRecordBackup.fromJson(Map<String, dynamic> json) {
    return DirtyRecordBackup(
      backupCreatedAt: DateTime.parse(json['backup_created_at'] as String),
      appVersion: json['app_version'] as String,
      schemaVersion: json['schema_version'] as int,
      userId: json['user_id'] as String,
      dirtyRecords: (json['dirty_records'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as List).map((e) => e as Map<String, dynamic>).toList(),
        ),
      ),
      uploadErrors: (json['upload_errors'] as List)
          .map((e) => UploadError.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Check if backup has any dirty records
  bool get hasDirtyRecords {
    return dirtyRecords.values.any((records) => records.isNotEmpty);
  }

  /// Get total count of dirty records across all repositories
  int get totalRecordCount {
    return dirtyRecords.values.fold(0, (sum, records) => sum + records.length);
  }
}
