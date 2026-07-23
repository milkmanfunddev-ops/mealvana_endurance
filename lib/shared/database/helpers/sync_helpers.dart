import 'package:drift/drift.dart';
import '../app_database.dart';

/// Helper utilities for sync tracking columns (needs_upload, local_updated_at)
///
/// These helpers reduce duplication when marking records for background sync
/// to Supabase.

/// Mark a record for upload by setting needs_upload = 1 and local_updated_at
///
/// [db] The AppDatabase instance
/// [tableName] The actual SQLite table name (e.g., 'user_foods', 'feedback')
/// [idColumn] The name of the ID column (default: 'id')
/// [id] The record ID to mark for upload
Future<void> markForUpload(
  AppDatabase db,
  String tableName,
  String id, {
  String idColumn = 'id',
}) async {
  final nowMillis = DateTime.now().millisecondsSinceEpoch;
  await db.customStatement(
    'UPDATE $tableName SET needs_upload = 1, local_updated_at = ? WHERE $idColumn = ?',
    [nowMillis, id],
  );
}

/// Normalize legacy TEXT timestamp columns to Unix milliseconds
///
/// Some older records may have timestamps stored as ISO 8601 strings.
/// This converts them to Unix milliseconds for Drift compatibility.
///
/// [db] The AppDatabase instance
/// [tableName] The actual SQLite table name
/// [columns] List of column names to normalize
Future<void> normalizeTimestampColumns(
  AppDatabase db,
  String tableName,
  List<String> columns,
) async {
  await db.transaction(() async {
    for (final column in columns) {
      await db.customStatement('''
        UPDATE $tableName
        SET $column = CAST(
          strftime('%s', replace(replace($column, 'T', ' '), 'Z', ''))
          AS INTEGER
        ) * 1000
        WHERE typeof($column) = 'text'
          AND $column IS NOT NULL
          AND $column != ''
          AND strftime('%s', replace(replace($column, 'T', ' '), 'Z', '')) IS NOT NULL;
      ''');
    }
  });
}

/// Clear the dirty flag after successful upload to Supabase
///
/// [db] The AppDatabase instance
/// [tableName] The actual SQLite table name
/// [id] The record ID to clear
/// [idColumn] The name of the ID column (default: 'id')
Future<void> clearDirtyFlag(
  AppDatabase db,
  String tableName,
  String id, {
  String idColumn = 'id',
}) async {
  await db.customStatement(
    'UPDATE $tableName SET needs_upload = 0 WHERE $idColumn = ?',
    [id],
  );
}

/// Get all records that need to be uploaded to Supabase
///
/// Returns a list of IDs that have needs_upload = 1
///
/// [db] The AppDatabase instance
/// [tableName] The actual SQLite table name
/// [idColumn] The name of the ID column (default: 'id')
/// [userIdColumn] Optional user ID column to filter by
/// [userId] Optional user ID to filter by
Future<List<String>> getPendingUploadIds(
  AppDatabase db,
  String tableName, {
  String idColumn = 'id',
  String? userIdColumn,
  String? userId,
}) async {
  String sql = 'SELECT $idColumn FROM $tableName WHERE needs_upload = 1';
  final args = <dynamic>[];

  if (userIdColumn != null && userId != null) {
    sql += ' AND $userIdColumn = ?';
    args.add(userId);
  }

  final result = await db
      .customSelect(sql, variables: args.map((a) => Variable(a)).toList())
      .get();
  return result.map((row) => row.read<String>(idColumn)).toList();
}
