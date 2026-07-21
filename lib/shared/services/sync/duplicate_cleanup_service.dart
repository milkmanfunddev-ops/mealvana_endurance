import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';

part 'duplicate_cleanup_service.g.dart';

@Riverpod(keepAlive: true)
DuplicateCleanupService duplicateCleanupService(Ref ref) {
  return DuplicateCleanupService(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Service responsible for cleaning up duplicate records in the local Drift database.
///
/// Duplicates can occur during sync operations when records are inserted multiple times.
/// This service keeps the most recent record (by local_updated_at or updated_at) and
/// deletes older duplicates.
class DuplicateCleanupService {
  const DuplicateCleanupService({
    required AppDatabase database,
    required AppLogger logger,
  }) : _database = database,
       _logger = logger;

  final AppDatabase _database;
  final AppLogger _logger;

  /// Clean duplicate records from all tables for a user.
  /// Returns the total number of duplicates deleted.
  Future<int> cleanAllDuplicates(String userId) async {
    try {
      int totalDuplicatesDeleted = 0;

      // Clean each table (using actual SQLite table names, not Drift class names)
      totalDuplicatesDeleted += await _cleanTableDuplicates(
        tableName: 'activities',
        userId: userId,
      );

      totalDuplicatesDeleted += await _cleanTableDuplicates(
        tableName: 'events',
        userId: userId,
      );

      totalDuplicatesDeleted += await _cleanTableDuplicates(
        tableName: 'carb_loading_plans',
        userId: userId,
      );

      totalDuplicatesDeleted += await _cleanTableDuplicates(
        tableName: 'carb_loading_days',
        userId: userId,
        userIdColumn: null, // Uses carb_loading_plan_id foreign key
      );

      totalDuplicatesDeleted += await _cleanTableDuplicates(
        tableName: 'user_foods',
        userId: userId,
      );

      totalDuplicatesDeleted += await _cleanTableDuplicates(
        tableName: 'feedback',
        userId: userId,
        userIdColumn: 'device_id', // Uses device_id, not user_id
      );

      // Clean users table duplicates (different structure - uses 'id' and 'updated_at')
      // NOTE: UserProfilesTable has tableName override = 'users', not 'user_profiles'
      totalDuplicatesDeleted += await _cleanUserProfilesDuplicates(userId);

      if (totalDuplicatesDeleted > 0) {
        _logger.info(
          'Cleaned duplicate records from Drift',
          context: 'DUPLICATE_CLEANUP',
          data: {
            'total_duplicates_deleted': totalDuplicatesDeleted,
            'user_id': userId,
          },
        );
      }

      return totalDuplicatesDeleted;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clean duplicates from Drift',
        context: 'DUPLICATE_CLEANUP',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't throw - allow sync to continue even if cleanup fails
      return 0;
    }
  }

  /// Clean duplicates from a specific table.
  /// Returns the number of duplicates deleted.
  Future<int> _cleanTableDuplicates({
    required String tableName,
    required String userId,
    String? userIdColumn,
  }) async {
    try {
      // Use user_id by default, or provided column, or skip filtering for carb_loading_days
      final userFilter = userIdColumn == null
          ? '' // carb_loading_days doesn't filter by user
          : userIdColumn == 'device_id'
          ? 'device_id = (SELECT device_id FROM users WHERE id = ?)' // feedback uses device_id
          : 'user_id = ?'; // default

      // Find duplicate IDs (IDs that appear more than once)
      final duplicateQuery =
          '''
        SELECT id, COUNT(*) as count
        FROM $tableName
        ${userFilter.isEmpty ? '' : 'WHERE $userFilter'}
        GROUP BY id
        HAVING COUNT(*) > 1
      ''';

      final duplicates = await _database
          .customSelect(
            duplicateQuery,
            variables: userFilter.isEmpty ? [] : [Variable(userId)],
          )
          .get();

      if (duplicates.isEmpty) {
        return 0;
      }

      int deletedCount = 0;

      for (final duplicate in duplicates) {
        // Convert ID to string - handles both int and text IDs
        final id = duplicate.data['id'].toString();
        final count = duplicate.data['count'] as int;

        _logger.debug(
          'Found duplicate records in $tableName',
          context: 'DUPLICATE_CLEANUP',
          data: {'id': id, 'count': count, 'table': tableName},
        );

        // Find all records with this ID, ordered by local_updated_at DESC
        // Keep the most recent one, delete the rest
        final allRecordsQuery =
            '''
          SELECT rowid, id, local_updated_at
          FROM $tableName
          WHERE id = ?
          ORDER BY local_updated_at DESC
        ''';

        final allRecords = await _database
            .customSelect(allRecordsQuery, variables: [Variable(id)])
            .get();

        // Skip the first one (most recent), delete the rest
        for (int i = 1; i < allRecords.length; i++) {
          final rowid = allRecords[i].data['rowid'] as int;
          final updatedAt = allRecords[i].data['local_updated_at'];

          await _database.customStatement(
            'DELETE FROM $tableName WHERE rowid = ?',
            [rowid],
          );

          _logger.debug(
            'Deleted duplicate record from $tableName',
            context: 'DUPLICATE_CLEANUP',
            data: {
              'id': id,
              'rowid': rowid,
              'local_updated_at': updatedAt?.toString(),
              'kept_most_recent': true,
            },
          );

          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        _logger.info(
          'Cleaned duplicates from $tableName',
          context: 'DUPLICATE_CLEANUP',
          data: {'table': tableName, 'duplicates_deleted': deletedCount},
        );
      }

      return deletedCount;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clean duplicates from $tableName',
        context: 'DUPLICATE_CLEANUP',
        error: e,
        stackTrace: stackTrace,
        data: {'table': tableName},
      );
      return 0; // Return 0 on error, don't block sync
    }
  }

  /// Clean duplicate user profiles from Drift.
  /// User profiles use 'id' column and 'updated_at' (not user_id/local_updated_at).
  /// NOTE: The table is named 'users' in SQL (see UserProfilesTable.tableName override).
  /// Returns the number of duplicates deleted.
  Future<int> _cleanUserProfilesDuplicates(String userId) async {
    try {
      // Find duplicate IDs in users table (rows with same id appearing more than once)
      final duplicateQuery = '''
        SELECT id, COUNT(*) as count
        FROM users
        GROUP BY id
        HAVING COUNT(*) > 1
      ''';

      final duplicates = await _database.customSelect(duplicateQuery).get();

      if (duplicates.isEmpty) {
        return 0;
      }

      int deletedCount = 0;

      for (final duplicate in duplicates) {
        final id = duplicate.data['id'].toString();
        final count = duplicate.data['count'] as int;

        _logger.debug(
          'Found duplicate users records',
          context: 'DUPLICATE_CLEANUP',
          data: {'id': id, 'count': count},
        );

        // Find all records with this ID, ordered by updated_at DESC
        // Keep the most recent one, delete the rest
        final allRecordsQuery = '''
          SELECT rowid, id, updated_at
          FROM users
          WHERE id = ?
          ORDER BY updated_at DESC
        ''';

        final allRecords = await _database
            .customSelect(allRecordsQuery, variables: [Variable(id)])
            .get();

        // Skip the first one (most recent), delete the rest
        for (int i = 1; i < allRecords.length; i++) {
          final rowid = allRecords[i].data['rowid'] as int;
          final updatedAt = allRecords[i].data['updated_at'];

          await _database.customStatement('DELETE FROM users WHERE rowid = ?', [
            rowid,
          ]);

          _logger.debug(
            'Deleted duplicate user',
            context: 'DUPLICATE_CLEANUP',
            data: {
              'id': id,
              'rowid': rowid,
              'updated_at': updatedAt?.toString(),
            },
          );

          deletedCount++;
        }
      }

      // Also clean up: if multiple profiles have needs_upload = true, keep only the most recent
      // This prevents "Too many elements" error when uploading
      final multipleNeedsUploadQuery = '''
        SELECT COUNT(*) as count FROM users WHERE needs_upload = 1
      ''';
      final needsUploadCount = await _database
          .customSelect(multipleNeedsUploadQuery)
          .getSingle();
      final count = needsUploadCount.data['count'] as int;

      if (count > 1) {
        _logger.info(
          'Multiple users need upload, keeping only most recent',
          context: 'DUPLICATE_CLEANUP',
          data: {'count': count},
        );

        // Get all profiles needing upload, ordered by most recent
        final profilesQuery = '''
          SELECT rowid, id, updated_at FROM users
          WHERE needs_upload = 1
          ORDER BY updated_at DESC
        ''';
        final profiles = await _database.customSelect(profilesQuery).get();

        // Skip the first (most recent), clear needs_upload for the rest
        for (int i = 1; i < profiles.length; i++) {
          final rowid = profiles[i].data['rowid'] as int;
          await _database.customStatement(
            'UPDATE users SET needs_upload = 0 WHERE rowid = ?',
            [rowid],
          );
        }
      }

      return deletedCount;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clean users duplicates',
        context: 'DUPLICATE_CLEANUP',
        error: e,
        stackTrace: stackTrace,
      );
      return 0; // Return 0 on error, don't block sync
    }
  }
}
