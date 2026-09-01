# DataSyncService Refactoring Plan - Detailed Implementation

**Date**: 2026-01-09
**Target Completion**: 2-2.5 weeks
**Total Phases**: 3

---

## Table of Contents

1. [Phase 1: Quick Wins](#phase-1-quick-wins)
2. [Phase 2: Entity Services](#phase-2-entity-services)
3. [Phase 3: Core Refactoring](#phase-3-core-refactoring)
4. [Testing Strategy](#testing-strategy)
5. [Rollback Plan](#rollback-plan)

---

## Phase 1: Quick Wins

**Duration**: 1-2 days
**Risk**: Very Low
**Lines Saved**: ~795 lines

### Goals
- Extract self-contained utilities
- Extract data integrity service
- Eliminate obvious code duplication
- Make remaining refactoring easier

---

### 1.1: Create TypeConverters Utility

**File**: `lib/shared/services/sync/utils/type_converters.dart`
**Lines Saved**: ~380 lines

```dart
/// Type conversion utilities for sync operations
/// Handles conversion between different data formats (JSON, Drift, Supabase)
class TypeConverters {
  // Private constructor - all methods are static
  TypeConverters._();

  /// Convert dynamic ID to String (handles int/String transition)
  static String? toStringId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  /// Convert required ID to String with null check
  static String toRequiredStringId(dynamic value, String fieldName) {
    final result = toStringId(value);
    if (result == null) {
      throw ArgumentError('$fieldName cannot be null');
    }
    return result;
  }

  /// Convert dynamic bool (handles bool/int/String from different sources)
  static bool toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  /// Parse optional DateTime from various formats
  static DateTime? parseOptionalDateTime(
    dynamic value, {
    DateTime? defaultValue,
  }) {
    if (value == null) return defaultValue;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    if (value is int) {
      // Handle milliseconds since epoch (SQLite)
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// Parse required DateTime with error handling
  static DateTime parseRequiredDateTime(dynamic value, String fieldName) {
    final result = parseOptionalDateTime(value);
    if (result == null) {
      throw ArgumentError('$fieldName is required and must be a valid date');
    }
    return result;
  }

  /// Convert SQLite integer timestamp to ISO8601 string
  static String? intToIso8601(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return null;
  }

  /// Parse PostgreSQL array format {item1,item2,item3}
  static List<String> parsePgArray(String? value) {
    if (value == null || value.isEmpty) return [];
    final trimmed = value.replaceAll(RegExp(r'[{}]'), '');
    if (trimmed.isEmpty) return [];
    return trimmed.split(',').map((e) => e.trim()).toList();
  }

  /// Parse gender string to Gender enum
  static Gender parseGender(String? value) {
    if (value == null) return Gender.preferNotToSay;
    switch (value.toLowerCase()) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      default:
        return Gender.preferNotToSay;
    }
  }

  /// Parse gut training level string to GutTrainingLevel enum
  static GutTrainingLevel parseGutTrainingLevel(String? value) {
    if (value == null) return GutTrainingLevel.beginner;
    switch (value.toLowerCase()) {
      case 'beginner':
        return GutTrainingLevel.beginner;
      case 'intermediate':
        return GutTrainingLevel.intermediate;
      case 'advanced':
        return GutTrainingLevel.advanced;
      default:
        return GutTrainingLevel.beginner;
    }
  }
}
```

**Usage Example**:
```dart
// Before:
Value(
  data['created_at'] != null
      ? DateTime.parse(data['created_at'] as String)
      : null,
)

// After:
Value(TypeConverters.parseOptionalDateTime(data['created_at']))
```

---

### 1.2: Create SyncErrorHandler Utility

**File**: `lib/shared/services/sync/utils/sync_error_handler.dart`
**Lines Saved**: ~180 lines

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../logging_service.dart';

part 'sync_error_handler.g.dart';

@Riverpod(keepAlive: true)
SyncErrorHandler syncErrorHandler(Ref ref) {
  return SyncErrorHandler(
    logger: ref.read(appLoggerProvider),
  );
}

/// Centralized error handling for sync operations
/// Provides consistent logging and error recovery patterns
class SyncErrorHandler {
  const SyncErrorHandler({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  /// Execute action with error logging
  /// Returns result on success, null on error
  Future<T?> withErrorLogging<T>(
    String operation,
    String context,
    Future<T> Function() action, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      _logger.error(
        operation,
        context: context,
        error: e,
        stackTrace: stackTrace,
        data: metadata,
      );
      return null;
    }
  }

  /// Execute action with error logging and default value
  Future<T> withErrorLoggingAndDefault<T>(
    String operation,
    String context,
    Future<T> Function() action,
    T defaultValue, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      _logger.error(
        operation,
        context: context,
        error: e,
        stackTrace: stackTrace,
        data: metadata,
      );
      return defaultValue;
    }
  }

  /// Execute action with error logging, rethrow on error
  Future<T> withErrorLoggingAndRethrow<T>(
    String operation,
    String context,
    Future<T> Function() action, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      _logger.error(
        operation,
        context: context,
        error: e,
        stackTrace: stackTrace,
        data: metadata,
      );
      rethrow;
    }
  }

  /// Log warning without throwing
  void logWarning(
    String message,
    String context, {
    Map<String, dynamic>? metadata,
  }) {
    _logger.warning(message, context: context, data: metadata);
  }

  /// Log info
  void logInfo(
    String message,
    String context, {
    Map<String, dynamic>? metadata,
  }) {
    _logger.info(message, context: context, data: metadata);
  }
}
```

**Usage Example**:
```dart
// Before:
try {
  await _database.into(table).insert(companion);
} catch (e, stackTrace) {
  _logger.error(
    'Failed to upsert activity',
    context: 'ACTIVITY_SYNC',
    error: e,
    stackTrace: stackTrace,
    data: {'activityId': data['id']},
  );
}

// After:
await _errorHandler.withErrorLogging(
  'Failed to upsert activity',
  'ACTIVITY_SYNC',
  () => _database.into(table).insert(companion),
  metadata: {'activityId': data['id']},
);
```

---

### 1.3: Extract DataIntegrityService

**File**: `lib/shared/services/sync/data_integrity_service.dart`
**Lines Saved**: ~300 lines

```dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import 'utils/sync_error_handler.dart';

part 'data_integrity_service.g.dart';

@Riverpod(keepAlive: true)
DataIntegrityService dataIntegrityService(Ref ref) {
  return DataIntegrityService(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    errorHandler: ref.read(syncErrorHandlerProvider),
  );
}

/// Handles data integrity operations for sync service
/// Primarily responsible for detecting and cleaning duplicate records
class DataIntegrityService {
  const DataIntegrityService({
    required AppDatabase database,
    required AppLogger logger,
    required SyncErrorHandler errorHandler,
  })  : _database = database,
        _logger = logger,
        _errorHandler = errorHandler;

  final AppDatabase _database;
  final AppLogger _logger;
  final SyncErrorHandler _errorHandler;

  /// Clean duplicates from all tables before upload
  /// Ensures data integrity before syncing to Supabase
  Future<void> cleanAllDuplicates(String userId) async {
    _logger.info(
      'Starting duplicate cleanup for user',
      context: 'DATA_INTEGRITY',
      data: {'userId': userId},
    );

    await _errorHandler.withErrorLogging(
      'Cleaning duplicate user profiles',
      'DATA_INTEGRITY',
      () => _cleanUserProfilesDuplicates(userId),
    );

    // Clean other tables
    final tables = [
      'activities',
      'events',
      'carb_loading_plans',
      'carb_loading_days',
      'food_preferences',
      'feedback',
      'feature_survey_responses',
    ];

    for (final table in tables) {
      await _errorHandler.withErrorLogging(
        'Cleaning duplicates from $table',
        'DATA_INTEGRITY',
        () => _cleanTableDuplicates(table, userId),
      );
    }

    _logger.info(
      'Duplicate cleanup complete',
      context: 'DATA_INTEGRITY',
      data: {'userId': userId},
    );
  }

  /// Clean duplicate records from a specific table
  /// Keeps the most recent record (by updated_at or local_updated_at)
  Future<void> _cleanTableDuplicates(String tableName, String userId) async {
    // Determine timestamp column
    final timestampColumn = _getTimestampColumn(tableName);
    final userIdColumn = _getUserIdColumn(tableName);

    // Step 1: Find duplicates
    final duplicatesQuery = '''
      SELECT id, COUNT(*) as count
      FROM $tableName
      WHERE $userIdColumn = ?
      GROUP BY id
      HAVING COUNT(*) > 1
    ''';

    final duplicates = await _database.customSelect(
      duplicatesQuery,
      variables: [Variable.withString(userId)],
      readsFrom: {_database.allTables.firstWhere((t) => t.actualTableName == tableName)},
    ).get();

    if (duplicates.isEmpty) {
      return; // No duplicates
    }

    _logger.warning(
      'Found ${duplicates.length} duplicate IDs in $tableName',
      context: 'DATA_INTEGRITY',
      data: {'table': tableName, 'count': duplicates.length},
    );

    // Step 2: For each duplicate ID, keep the most recent
    for (final duplicate in duplicates) {
      final id = duplicate.read<String>('id');

      // Get all records with this ID, ordered by timestamp DESC
      final recordsQuery = '''
        SELECT rowid
        FROM $tableName
        WHERE id = ? AND $userIdColumn = ?
        ORDER BY $timestampColumn DESC
      ''';

      final records = await _database.customSelect(
        recordsQuery,
        variables: [Variable.withString(id), Variable.withString(userId)],
        readsFrom: {_database.allTables.firstWhere((t) => t.actualTableName == tableName)},
      ).get();

      if (records.length <= 1) continue;

      // Keep first (most recent), delete rest
      final toDelete = records.skip(1).map((r) => r.read<int>('rowid')).toList();

      for (final rowid in toDelete) {
        await _database.customStatement(
          'DELETE FROM $tableName WHERE rowid = ?',
          [rowid],
        );
      }

      _logger.info(
        'Cleaned ${toDelete.length} duplicate(s) for ID: $id',
        context: 'DATA_INTEGRITY',
        data: {'table': tableName, 'id': id, 'deletedCount': toDelete.length},
      );
    }
  }

  /// Clean duplicate user profiles
  /// Special handling for users table
  Future<void> _cleanUserProfilesDuplicates(String userId) async {
    const tableName = 'users';

    // Find duplicates
    final duplicatesQuery = '''
      SELECT id, COUNT(*) as count
      FROM $tableName
      WHERE id = ?
      GROUP BY id
      HAVING COUNT(*) > 1
    ''';

    final duplicates = await _database.customSelect(
      duplicatesQuery,
      variables: [Variable.withString(userId)],
      readsFrom: {_database.usersTable},
    ).get();

    if (duplicates.isEmpty) {
      return; // No duplicates
    }

    _logger.warning(
      'Found duplicate user profiles',
      context: 'DATA_INTEGRITY',
      data: {'userId': userId, 'count': duplicates.length},
    );

    // Get all records for this user, ordered by updated_at DESC
    final recordsQuery = '''
      SELECT rowid
      FROM $tableName
      WHERE id = ?
      ORDER BY updated_at DESC
    ''';

    final records = await _database.customSelect(
      recordsQuery,
      variables: [Variable.withString(userId)],
      readsFrom: {_database.usersTable},
    ).get();

    if (records.length <= 1) return;

    // Keep first (most recent), delete rest
    final toDelete = records.skip(1).map((r) => r.read<int>('rowid')).toList();

    for (final rowid in toDelete) {
      await _database.customStatement(
        'DELETE FROM $tableName WHERE rowid = ?',
        [rowid],
      );
    }

    _logger.info(
      'Cleaned ${toDelete.length} duplicate user profile(s)',
      context: 'DATA_INTEGRITY',
      data: {'userId': userId, 'deletedCount': toDelete.length},
    );
  }

  /// Get timestamp column name for a table
  String _getTimestampColumn(String tableName) {
    switch (tableName) {
      case 'carb_loading_plans':
      case 'carb_loading_days':
        return 'local_updated_at';
      default:
        return 'updated_at';
    }
  }

  /// Get user ID column name for a table
  String _getUserIdColumn(String tableName) {
    switch (tableName) {
      case 'feedback':
      case 'feature_survey_responses':
        return 'device_id';
      case 'carb_loading_days':
        return 'carb_loading_plan_id'; // Special case - needs JOIN
      default:
        return 'user_id';
    }
  }
}
```

---

### 1.4: Extract EntityJsonConverter

**File**: `lib/shared/services/sync/converters/entity_json_converter.dart`
**Lines Saved**: ~115 lines

```dart
import '../../../features/activities/domain/activity.dart';
import '../../../features/calendar/domain/event.dart';
import '../../../features/carb_loading/domain/carb_loading_plan.dart';
import '../../../features/carb_loading/domain/carb_loading_day.dart';
import '../../../features/feedback/domain/feature_survey_response.dart';

/// Converts Drift entities to JSON for upload to Supabase
/// Handles field mapping and type conversion
class EntityJsonConverter {
  // Private constructor - all methods are static
  EntityJsonConverter._();

  /// Convert Activity to JSON
  static Map<String, dynamic> activityToJson(Activity activity) {
    return {
      'id': activity.id,
      'user_id': activity.userId,
      'activity_type': activity.activityType,
      'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
      'duration_minutes': activity.durationMinutes,
      'distance_km': activity.distanceKm,
      'distance_miles': activity.distanceMiles,
      'pace_min_per_km': activity.paceMinPerKm,
      'pace_min_per_mile': activity.paceMinPerMile,
      'elevation_gain_meters': activity.elevationGainMeters,
      'elevation_gain_feet': activity.elevationGainFeet,
      'intensity': activity.intensity,
      'completed': activity.completed,
      'actual_date_time': activity.actualDateTime?.toIso8601String(),
      'actual_duration_minutes': activity.actualDurationMinutes,
      'actual_distance_km': activity.actualDistanceKm,
      'actual_distance_miles': activity.actualDistanceMiles,
      'actual_pace_min_per_km': activity.actualPaceMinPerKm,
      'actual_pace_min_per_mile': activity.actualPaceMinPerMile,
      'notes': activity.notes,
      'created_at': activity.createdAt.toIso8601String(),
      'updated_at': activity.updatedAt.toIso8601String(),
      'deleted_at': activity.deletedAt?.toIso8601String(),
      'device_id': activity.deviceId,
      'needs_upload': activity.needsUpload,
    };
  }

  /// Convert Event to JSON
  static Map<String, dynamic> eventToJson(Event event) {
    return {
      'id': event.id,
      'user_id': event.userId,
      'activity_id': event.activityId,
      'name': event.name,
      'event_date': event.eventDate.toIso8601String(),
      'event_type': event.eventType,
      'distance_km': event.distanceKm,
      'distance_miles': event.distanceMiles,
      'notes': event.notes,
      'carb_loading_protocol': event.carbLoadingProtocol,
      'carb_loading_days': event.carbLoadingDays,
      'carb_loading_enabled': event.carbLoadingEnabled,
      'created_at': event.createdAt.toIso8601String(),
      'updated_at': event.updatedAt.toIso8601String(),
      'deleted_at': event.deletedAt?.toIso8601String(),
      'device_id': event.deviceId,
      'needs_upload': event.needsUpload,
    };
  }

  /// Convert CarbLoadingPlan to JSON
  static Map<String, dynamic> carbLoadingPlanToJson(
    CarbLoadingPlan plan,
  ) {
    return {
      'id': plan.id,
      'user_id': plan.userId,
      'event_id': plan.eventId,
      'protocol': plan.protocol,
      'days_count': plan.daysCount,
      'start_date': plan.startDate.toIso8601String(),
      'created_at': plan.createdAt.toIso8601String(),
      'local_updated_at': plan.localUpdatedAt.toIso8601String(),
      'deleted_at': plan.deletedAt?.toIso8601String(),
      'device_id': plan.deviceId,
      'needs_upload': plan.needsUpload,
    };
  }

  /// Convert CarbLoadingDay to JSON
  static Map<String, dynamic> carbLoadingDayToJson(CarbLoadingDay day) {
    return {
      'id': day.id,
      'carb_loading_plan_id': day.carbLoadingPlanId,
      'day_number': day.dayNumber,
      'date': day.date.toIso8601String(),
      'target_carbs_g': day.targetCarbsG,
      'actual_carbs_g': day.actualCarbsG,
      'foods': day.foods,
      'notes': day.notes,
      'created_at': day.createdAt.toIso8601String(),
      'local_updated_at': day.localUpdatedAt.toIso8601String(),
      'deleted_at': day.deletedAt?.toIso8601String(),
      'device_id': day.deviceId,
      'needs_upload': day.needsUpload,
    };
  }

  /// Convert FeatureSurveyResponse to JSON
  static Map<String, dynamic> featureSurveyToJson(
    FeatureSurveyResponse survey,
  ) {
    return {
      'id': survey.id,
      'device_id': survey.deviceId,
      'feature_name': survey.featureName,
      'rating': survey.rating,
      'feedback': survey.feedback,
      'created_at': survey.createdAt.toIso8601String(),
      'needs_upload': survey.needsUpload,
    };
  }
}
```

---

## Phase 2: Entity Services

**Duration**: 3-4 days
**Risk**: Medium
**Lines Saved**: ~1,550 lines

### Goals
- Extract entity-specific sync logic
- Create clear service boundaries
- Enable independent testing
- Prepare for upload orchestration

---

### 2.1: Create CalendarSyncService

**File**: `lib/features/calendar/data/calendar_sync_service.dart`
**Lines**: ~500

```dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/utils/sync_error_handler.dart';
import '../../../shared/services/sync/utils/type_converters.dart';
import '../../../shared/services/sync/converters/entity_json_converter.dart';

part 'calendar_sync_service.g.dart';

@Riverpod(keepAlive: true)
CalendarSyncService calendarSyncService(Ref ref) {
  return CalendarSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    errorHandler: ref.read(syncErrorHandlerProvider),
  );
}

/// Handles sync operations for calendar entities (activities and events)
class CalendarSyncService {
  const CalendarSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SyncErrorHandler errorHandler,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _errorHandler = errorHandler;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SyncErrorHandler _errorHandler;

  /// Download activities from Supabase (client-side fallback)
  Future<void> downloadActivities(String userId) async {
    final response = await _supabase
        .from('activities')
        .select('*')
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    _logger.info(
      'Downloaded ${response.length} activities',
      context: 'CALENDAR_SYNC',
      data: {'userId': userId, 'count': response.length},
    );

    for (final activity in response) {
      await _errorHandler.withErrorLogging(
        'Upserting activity',
        'CALENDAR_SYNC',
        () => upsertActivity(activity as Map<String, dynamic>, userId),
        metadata: {'activityId': activity['id']},
      );
    }
  }

  /// Download events from Supabase (client-side fallback)
  Future<void> downloadEvents(String userId) async {
    final response = await _supabase
        .from('events')
        .select('*')
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    _logger.info(
      'Downloaded ${response.length} events',
      context: 'CALENDAR_SYNC',
      data: {'userId': userId, 'count': response.length},
    );

    for (final event in response) {
      await _errorHandler.withErrorLogging(
        'Upserting event',
        'CALENDAR_SYNC',
        () => upsertEvent(event as Map<String, dynamic>, userId),
        metadata: {'eventId': event['id']},
      );
    }
  }

  /// Upsert activity to local database
  Future<void> upsertActivity(
    Map<String, dynamic> data,
    String userId,
  ) async {
    final activityId = TypeConverters.toRequiredStringId(data['id'], 'id');

    // Check if exists
    final existingActivity = await (_database.select(_database.activitiesTable)
          ..where((tbl) => tbl.id.equals(activityId)))
        .getSingleOrNull();

    // CRITICAL: Preserve dirty records (local changes not yet uploaded)
    if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
      _logger.info(
        'Skipping activity upsert - local changes pending upload',
        context: 'CALENDAR_SYNC',
        data: {'activityId': activityId},
      );
      return;
    }

    // Check if remote is newer
    final supabaseUpdatedAt = TypeConverters.parseRequiredDateTime(
      data['updated_at'],
      'updated_at',
    );

    if (existingActivity != null &&
        !existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
      return; // Local is same or newer
    }

    // Build companion
    final companion = ActivitiesTableCompanion.insert(
      id: Value(activityId),
      userId: userId,
      activityType: data['activity_type'] as String,
      scheduledDateTime: TypeConverters.parseRequiredDateTime(
        data['scheduled_date_time'],
        'scheduled_date_time',
      ),
      durationMinutes: Value(data['duration_minutes'] as int?),
      distanceKm: Value(data['distance_km'] as double?),
      distanceMiles: Value(data['distance_miles'] as double?),
      paceMinPerKm: Value(data['pace_min_per_km'] as double?),
      paceMinPerMile: Value(data['pace_min_per_mile'] as double?),
      elevationGainMeters: Value(data['elevation_gain_meters'] as int?),
      elevationGainFeet: Value(data['elevation_gain_feet'] as int?),
      intensity: Value(data['intensity'] as String?),
      completed: Value(TypeConverters.toBool(data['completed'])),
      actualDateTime: Value(TypeConverters.parseOptionalDateTime(
        data['actual_date_time'],
      )),
      actualDurationMinutes: Value(data['actual_duration_minutes'] as int?),
      actualDistanceKm: Value(data['actual_distance_km'] as double?),
      actualDistanceMiles: Value(data['actual_distance_miles'] as double?),
      actualPaceMinPerKm: Value(data['actual_pace_min_per_km'] as double?),
      actualPaceMinPerMile: Value(data['actual_pace_min_per_mile'] as double?),
      notes: Value(data['notes'] as String?),
      createdAt: TypeConverters.parseRequiredDateTime(
        data['created_at'],
        'created_at',
      ),
      updatedAt: supabaseUpdatedAt,
      deletedAt: Value(TypeConverters.parseOptionalDateTime(data['deleted_at'])),
      deviceId: Value(data['device_id'] as String?),
      needsUpload: const Value(false), // Just synced from server
    );

    await _database
        .into(_database.activitiesTable)
        .insert(companion, mode: InsertMode.insertOrReplace);

    _logger.info(
      'Upserted activity',
      context: 'CALENDAR_SYNC',
      data: {'activityId': activityId},
    );
  }

  /// Upsert event to local database
  Future<void> upsertEvent(Map<String, dynamic> data, String userId) async {
    final eventId = TypeConverters.toRequiredStringId(data['id'], 'id');

    // Verify linked activity exists and belongs to user
    final activityId = TypeConverters.toStringId(data['activity_id']);
    if (activityId != null) {
      final activity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .getSingleOrNull();

      if (activity == null || activity.userId != userId) {
        _logger.warning(
          'Event references non-existent or unauthorized activity',
          context: 'CALENDAR_SYNC',
          data: {'eventId': eventId, 'activityId': activityId},
        );
        return;
      }
    }

    // Check if exists
    final existingEvent = await (_database.select(_database.eventsTable)
          ..where((tbl) => tbl.id.equals(eventId)))
        .getSingleOrNull();

    // Check if remote is newer
    final supabaseUpdatedAt = TypeConverters.parseRequiredDateTime(
      data['updated_at'],
      'updated_at',
    );

    if (existingEvent != null &&
        !existingEvent.updatedAt.isBefore(supabaseUpdatedAt)) {
      return; // Local is same or newer
    }

    // Build companion
    final companion = EventsTableCompanion.insert(
      id: Value(eventId),
      userId: userId,
      activityId: Value(activityId),
      name: data['name'] as String,
      eventDate: TypeConverters.parseRequiredDateTime(
        data['event_date'],
        'event_date',
      ),
      eventType: Value(data['event_type'] as String?),
      distanceKm: Value(data['distance_km'] as double?),
      distanceMiles: Value(data['distance_miles'] as double?),
      notes: Value(data['notes'] as String?),
      carbLoadingProtocol: Value(data['carb_loading_protocol'] as String?),
      carbLoadingDays: Value(data['carb_loading_days'] as int?),
      carbLoadingEnabled: Value(
        TypeConverters.toBool(data['carb_loading_enabled']),
      ),
      createdAt: TypeConverters.parseRequiredDateTime(
        data['created_at'],
        'created_at',
      ),
      updatedAt: supabaseUpdatedAt,
      deletedAt: Value(TypeConverters.parseOptionalDateTime(data['deleted_at'])),
      deviceId: Value(data['device_id'] as String?),
      needsUpload: const Value(false),
    );

    await _database
        .into(_database.eventsTable)
        .insert(companion, mode: InsertMode.insertOrReplace);

    _logger.info(
      'Upserted event',
      context: 'CALENDAR_SYNC',
      data: {'eventId': eventId},
    );
  }

  /// Collect dirty records for upload
  Future<Map<String, List<Map<String, dynamic>>>> collectDirtyRecords(
    String userId,
  ) async {
    final result = <String, List<Map<String, dynamic>>>{};

    // Collect dirty activities
    final dirtyActivities = await (_database.select(_database.activitiesTable)
          ..where((tbl) => tbl.userId.equals(userId))
          ..where((tbl) => tbl.needsUpload.equals(true)))
        .get();

    if (dirtyActivities.isNotEmpty) {
      result['activities'] = dirtyActivities
          .map((a) => EntityJsonConverter.activityToJson(a))
          .toList();
    }

    // Collect dirty events
    final dirtyEvents = await (_database.select(_database.eventsTable)
          ..where((tbl) => tbl.userId.equals(userId))
          ..where((tbl) => tbl.needsUpload.equals(true)))
        .get();

    if (dirtyEvents.isNotEmpty) {
      result['events'] =
          dirtyEvents.map((e) => EntityJsonConverter.eventToJson(e)).toList();
    }

    _logger.info(
      'Collected dirty calendar records',
      context: 'CALENDAR_SYNC',
      data: {
        'userId': userId,
        'activities': dirtyActivities.length,
        'events': dirtyEvents.length,
      },
    );

    return result;
  }

  /// Clear upload flags after successful upload
  Future<void> clearUploadFlags(String userId) async {
    await _database.customStatement(
      'UPDATE activities SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
      [userId],
    );

    await _database.customStatement(
      'UPDATE events SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
      [userId],
    );

    _logger.info(
      'Cleared calendar upload flags',
      context: 'CALENDAR_SYNC',
      data: {'userId': userId},
    );
  }
}
```

---

### 2.2: Create CarbLoadingSyncService

**File**: `lib/features/carb_loading/data/carb_loading_sync_service.dart`
**Lines**: ~350

**Implementation**: Similar pattern to CalendarSyncService

**Key Methods**:
- `downloadPlansAndDays(String userId)`
- `upsertPlan(Map<String, dynamic> data, String userId)`
- `upsertDay(Map<String, dynamic> data)`
- `collectDirtyRecords(String userId)`
- `clearUploadFlags(String userId)`

**Special Handling**:
- Uses `local_updated_at` instead of `updated_at`
- When syncing plan, also updates linked event's carb loading flags
- Days have FK to plans, requires plan to exist first

---

### 2.3: Create CoachDataSyncService

**File**: `lib/features/coach_mode/data/coach_sync_service.dart`
**Lines**: ~300

**Key Methods**:
- `syncCoachRecord(Map<String, dynamic> data)`
- `syncCoachAthleteRelationships(List<dynamic> data)`
- `syncCoachMessages(List<dynamic> data)`
- `syncAthleteEvents(List<dynamic> data)`
- `syncAthleteActivities(List<dynamic> data)`
- `syncAthleteProfiles(List<dynamic> data)`
- `syncAthleteCarbLoadingPlans(List<dynamic> data)`
- `collectDirtyRecords(String coachId)`
- `clearUploadFlags(String coachId)`

**Special Handling**:
- Conditional sync (only if user is approved coach)
- Limited athlete profile fields (privacy)
- Coach-athlete relationship status handling

---

### 2.4: Create UserProfileSyncService

**File**: `lib/features/auth/data/user_profile_sync_service.dart`
**Lines**: ~400

**Key Methods**:
- `syncUserProfile(String userId)` - Main entry point
- `_fetchRemoteProfile(String userId)`
- `_saveRemoteProfileLocally(Map<String, dynamic> data, String userId)`
- `uploadUserProfile(String userId)`
- `syncFoodPreferences(Map<String, dynamic> data, String userId)`
- `uploadFoodPreferences(String userId)`

**Special Handling**:
- Multi-device support (fetch from Supabase if local doesn't match auth)
- Sign-back-in flow (refresh profile after re-login)
- Schema differences between dev/prod
- JSONB food_preferences in users table + normalized food_preferences table

---

## Phase 3: Core Refactoring

**Duration**: 2-3 days
**Risk**: Medium-High
**Lines Saved**: ~300 + major simplification

### Goals
- Create upload orchestrator
- Simplify main DataSyncService
- Complete refactoring
- Validate with tests

---

### 3.1: Create UploadOrchestratorService

**File**: `lib/shared/services/sync/upload_orchestrator_service.dart`
**Lines**: ~300

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import 'utils/sync_error_handler.dart';
import '../../../features/calendar/data/calendar_sync_service.dart';
import '../../../features/carb_loading/data/carb_loading_sync_service.dart';
import '../../../features/coach_mode/data/coach_sync_service.dart';
import '../../../features/auth/data/user_profile_sync_service.dart';

part 'upload_orchestrator_service.g.dart';

@Riverpod(keepAlive: true)
UploadOrchestratorService uploadOrchestratorService(Ref ref) {
  return UploadOrchestratorService(
    supabase: Supabase.instance.client,
    logger: ref.read(appLoggerProvider),
    errorHandler: ref.read(syncErrorHandlerProvider),
    calendarSync: ref.read(calendarSyncServiceProvider),
    carbLoadingSync: ref.read(carbLoadingSyncServiceProvider),
    coachSync: ref.read(coachSyncServiceProvider),
    userProfileSync: ref.read(userProfileSyncServiceProvider),
  );
}

/// Orchestrates uploading dirty records from all entities to Supabase
/// Uses single edge function call for efficiency
class UploadOrchestratorService {
  const UploadOrchestratorService({
    required SupabaseClient supabase,
    required AppLogger logger,
    required SyncErrorHandler errorHandler,
    required CalendarSyncService calendarSync,
    required CarbLoadingSyncService carbLoadingSync,
    required CoachDataSyncService coachSync,
    required UserProfileSyncService userProfileSync,
  })  : _supabase = supabase,
        _logger = logger,
        _errorHandler = errorHandler,
        _calendarSync = calendarSync,
        _carbLoadingSync = carbLoadingSync,
        _coachSync = coachSync,
        _userProfileSync = userProfileSync;

  final SupabaseClient _supabase;
  final AppLogger _logger;
  final SyncErrorHandler _errorHandler;
  final CalendarSyncService _calendarSync;
  final CarbLoadingSyncService _carbLoadingSync;
  final CoachDataSyncService _coachSync;
  final UserProfileSyncService _userProfileSync;

  /// Upload all dirty records via edge function
  /// Returns true if successful, false otherwise
  Future<bool> uploadAllDirtyRecords(String userId) async {
    _logger.info(
      'Starting dirty records upload',
      context: 'UPLOAD_ORCHESTRATOR',
      data: {'userId': userId},
    );

    // Step 1: Collect dirty records from all services
    final payload = <String, dynamic>{};

    // Calendar (activities, events)
    final calendarRecords = await _calendarSync.collectDirtyRecords(userId);
    payload.addAll(calendarRecords);

    // Carb Loading (plans, days)
    final carbLoadingRecords = await _carbLoadingSync.collectDirtyRecords(userId);
    payload.addAll(carbLoadingRecords);

    // Coach Mode (if applicable)
    final coachRecords = await _coachSync.collectDirtyRecords(userId);
    payload.addAll(coachRecords);

    // User Profile & Food Preferences
    final userRecords = await _userProfileSync.collectDirtyRecords(userId);
    payload.addAll(userRecords);

    // Check if anything to upload
    if (payload.isEmpty) {
      _logger.info(
        'No dirty records to upload',
        context: 'UPLOAD_ORCHESTRATOR',
        data: {'userId': userId},
      );
      return true; // Nothing to do
    }

    // Step 2: Call edge function
    final success = await _errorHandler.withErrorLoggingAndDefault(
      'Uploading dirty records via edge function',
      'UPLOAD_ORCHESTRATOR',
      () => _uploadViaEdgeFunction(userId, payload),
      false,
      metadata: {'userId': userId, 'recordCount': _countRecords(payload)},
    );

    if (!success) {
      return false; // Upload failed
    }

    // Step 3: Clear upload flags on success
    await Future.wait([
      _calendarSync.clearUploadFlags(userId),
      _carbLoadingSync.clearUploadFlags(userId),
      _coachSync.clearUploadFlags(userId),
      _userProfileSync.clearUploadFlags(userId),
    ]);

    _logger.info(
      'Dirty records upload complete',
      context: 'UPLOAD_ORCHESTRATOR',
      data: {'userId': userId, 'recordCount': _countRecords(payload)},
    );

    return true;
  }

  /// Call edge function to upload dirty records
  Future<bool> _uploadViaEdgeFunction(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase.functions.invoke(
        'upload-all-data',
        body: {
          'user_id': userId,
          'dirty_records': payload,
        },
      );
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Edge function upload failed',
        context: 'UPLOAD_ORCHESTRATOR',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return false;
    }
  }

  /// Count total records in payload
  int _countRecords(Map<String, dynamic> payload) {
    var count = 0;
    for (final value in payload.values) {
      if (value is List) {
        count += value.length;
      }
    }
    return count;
  }
}
```

---

### 3.2: Simplified DataSyncService

**File**: `lib/shared/services/sync/data_sync_service.dart`
**Target Lines**: ~400 (down from 2,508)

```dart
import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import '../food_management/product_type_mapper.dart';
import '../../../features/nutrition_plan/data/food_repository.dart';
import '../../../features/carb_loading/application/carb_loading_food_sync_service.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../features/calendar/presentation/providers/calendar_controller.dart';

// New service imports
import 'utils/type_converters.dart';
import 'utils/sync_error_handler.dart';
import 'data_integrity_service.dart';
import 'upload_orchestrator_service.dart';
import '../../../features/calendar/data/calendar_sync_service.dart';
import '../../../features/carb_loading/data/carb_loading_sync_service.dart';
import '../../../features/coach_mode/data/coach_sync_service.dart';
import '../../../features/auth/data/user_profile_sync_service.dart';

part 'data_sync_service.g.dart';

@Riverpod(keepAlive: true)
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    ref: ref,
    supabase: Supabase.instance.client,
    logger: ref.read(appLoggerProvider),
    errorHandler: ref.read(syncErrorHandlerProvider),
    dataIntegrity: ref.read(dataIntegrityServiceProvider),
    uploadOrchestrator: ref.read(uploadOrchestratorServiceProvider),
    userProfileSync: ref.read(userProfileSyncServiceProvider),
    calendarSync: ref.read(calendarSyncServiceProvider),
    carbLoadingSync: ref.read(carbLoadingSyncServiceProvider),
    coachSync: ref.read(coachSyncServiceProvider),
    foodRepository: ref.read(foodRepositoryProvider),
    carbLoadingFoodSyncService: ref.read(carbLoadingFoodSyncServiceProvider),
  );
}

/// Unified data sync service - orchestrates all sync operations
/// Delegates to specialized services for entity-specific logic
class DataSyncService {
  const DataSyncService({
    required Ref ref,
    required SupabaseClient supabase,
    required AppLogger logger,
    required SyncErrorHandler errorHandler,
    required DataIntegrityService dataIntegrity,
    required UploadOrchestratorService uploadOrchestrator,
    required UserProfileSyncService userProfileSync,
    required CalendarSyncService calendarSync,
    required CarbLoadingSyncService carbLoadingSync,
    required CoachDataSyncService coachSync,
    required FoodRepository foodRepository,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
  })  : _ref = ref,
        _supabase = supabase,
        _logger = logger,
        _errorHandler = errorHandler,
        _dataIntegrity = dataIntegrity,
        _uploadOrchestrator = uploadOrchestrator,
        _userProfileSync = userProfileSync,
        _calendarSync = calendarSync,
        _carbLoadingSync = carbLoadingSync,
        _coachSync = coachSync,
        _foodRepository = foodRepository,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService;

  final Ref _ref;
  final SupabaseClient _supabase;
  final AppLogger _logger;
  final SyncErrorHandler _errorHandler;
  final DataIntegrityService _dataIntegrity;
  final UploadOrchestratorService _uploadOrchestrator;
  final UserProfileSyncService _userProfileSync;
  final CalendarSyncService _calendarSync;
  final CarbLoadingSyncService _carbLoadingSync;
  final CoachDataSyncService _coachSync;
  final FoodRepository _foodRepository;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;

  /// Main sync entry point - hybrid edge function + client-side fallback
  /// Returns true if sync successful, false otherwise
  /// Non-blocking: app continues with cached data if sync fails
  Future<bool> syncAllData(String userId) async {
    try {
      // Get last sync timestamp
      final prefs = _ref.read(sharedPreferencesProvider);
      final lastSyncTimestamp = prefs.getString('last_sync_timestamp_$userId');

      // STEP 0: User profile first (prevents FK violations)
      await _userProfileSync.syncUserProfile(userId);

      // STEP 1: Upload dirty records first (prevents data loss)
      await _uploadOrchestrator.uploadAllDirtyRecords(userId);

      // STEP 2: Clean duplicates before download
      await _dataIntegrity.cleanAllDuplicates(userId);

      // STEP 3: Try edge function for fast parallel download
      final edgeFunctionSuccess = await _tryEdgeFunctionSync(
        userId,
        lastSyncTimestamp,
      );

      if (edgeFunctionSuccess) {
        // Update timestamp
        await prefs.setString(
          'last_sync_timestamp_$userId',
          DateTime.now().toIso8601String(),
        );

        // Refresh UI
        _invalidateCalendarProviders();
        return true;
      }

      // STEP 4: Fallback to client-side download
      await _clientSideDownload(userId);

      // Update timestamp
      await prefs.setString(
        'last_sync_timestamp_$userId',
        DateTime.now().toIso8601String(),
      );

      // Refresh UI
      _invalidateCalendarProviders();
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Sync failed - app continuing with cached data',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Try syncing via edge function (fast, single network call)
  Future<bool> _tryEdgeFunctionSync(
    String userId,
    String? lastSyncTimestamp,
  ) async {
    return await _errorHandler.withErrorLoggingAndDefault(
      'Edge function sync',
      'DATA_SYNC',
      () async {
        final response = await _supabase.functions
            .invoke(
              'sync-all-data',
              body: {
                'user_id': userId,
                if (lastSyncTimestamp != null)
                  'last_sync_timestamp': lastSyncTimestamp,
              },
            )
            .timeout(const Duration(seconds: 30));

        if (response.status != 200) {
          throw Exception('Edge function returned ${response.status}');
        }

        // Process response
        await _syncDataFromEdgeFunction(response.data, userId);
        return true;
      },
      false, // Default to false on error
      metadata: {'userId': userId},
    );
  }

  /// Process edge function response and sync to local database
  Future<void> _syncDataFromEdgeFunction(
    Map<String, dynamic> data,
    String userId,
  ) async {
    // Activities
    if (data['activities'] != null) {
      for (final activity in data['activities'] as List) {
        await _calendarSync.upsertActivity(
          activity as Map<String, dynamic>,
          userId,
        );
      }
    }

    // Events
    if (data['events'] != null) {
      for (final event in data['events'] as List) {
        await _calendarSync.upsertEvent(
          event as Map<String, dynamic>,
          userId,
        );
      }
    }

    // Carb Loading Plans
    if (data['carb_loading_plans'] != null) {
      for (final plan in data['carb_loading_plans'] as List) {
        await _carbLoadingSync.upsertPlan(
          plan as Map<String, dynamic>,
          userId,
        );
      }
    }

    // Carb Loading Days
    if (data['carb_loading_days'] != null) {
      for (final day in data['carb_loading_days'] as List) {
        await _carbLoadingSync.upsertDay(
          day as Map<String, dynamic>,
        );
      }
    }

    // Foods (nutrition)
    if (data['foods'] != null) {
      await _foodRepository.syncFoodsFromData(
        data['foods'] as List,
        userId,
      );
    }

    // Carb Loading Foods
    if (data['carb_loading_foods'] != null) {
      await _carbLoadingFoodSyncService.syncFoodsFromData(
        data['carb_loading_foods'] as List,
        userId,
      );
    }

    // Food Preferences
    if (data['food_preferences'] != null) {
      await _userProfileSync.syncFoodPreferences(
        data,
        userId,
      );
    }

    // Coach Mode Data (if applicable)
    if (data['coach'] != null) {
      await _coachSync.syncCoachRecord(
        data['coach'] as Map<String, dynamic>,
      );
    }

    if (data['coach_athlete_relationships'] != null) {
      await _coachSync.syncCoachAthleteRelationships(
        data['coach_athlete_relationships'] as List,
      );
    }

    if (data['coach_messages'] != null) {
      await _coachSync.syncCoachMessages(
        data['coach_messages'] as List,
      );
    }

    // Athlete data for coaches
    if (data['athlete_events'] != null) {
      await _coachSync.syncAthleteEvents(
        data['athlete_events'] as List,
      );
    }

    if (data['athlete_activities'] != null) {
      await _coachSync.syncAthleteActivities(
        data['athlete_activities'] as List,
      );
    }

    if (data['athlete_profiles'] != null) {
      await _coachSync.syncAthleteProfiles(
        data['athlete_profiles'] as List,
      );
    }

    if (data['athlete_carb_loading_plans'] != null) {
      await _coachSync.syncAthleteCarbLoadingPlans(
        data['athlete_carb_loading_plans'] as List,
      );
    }

    _logger.info(
      'Edge function sync complete',
      context: 'DATA_SYNC',
      data: {'userId': userId},
    );
  }

  /// Fallback: Client-side download (slower but reliable)
  Future<void> _clientSideDownload(String userId) async {
    _logger.info(
      'Using client-side download fallback',
      context: 'DATA_SYNC',
      data: {'userId': userId},
    );

    await Future.wait([
      _calendarSync.downloadActivities(userId),
      _calendarSync.downloadEvents(userId),
      _carbLoadingSync.downloadPlansAndDays(userId),
      _foodRepository.syncFoods(userId),
      _carbLoadingFoodSyncService.syncFoods(userId),
    ]);

    _logger.info(
      'Client-side download complete',
      context: 'DATA_SYNC',
      data: {'userId': userId},
    );
  }

  /// Detect if full sync is needed (schema version mismatch)
  Future<bool> needsFullSync(String userId) async {
    // Implementation moved from lines 2457-2497
    // Check schema versions, etc.
    return false; // Placeholder
  }

  /// Refresh UI after sync
  void _invalidateCalendarProviders() {
    try {
      _ref.invalidate(calendarControllerProvider);
    } catch (e) {
      // Providers might not be initialized yet
      _logger.warning(
        'Could not invalidate calendar providers',
        context: 'DATA_SYNC',
      );
    }
  }

  /// Expose TypeConverters static methods for backward compatibility
  static String? toStringId(dynamic value) => TypeConverters.toStringId(value);
  static String toRequiredStringId(dynamic value, String fieldName) =>
      TypeConverters.toRequiredStringId(value, fieldName);
  static bool toBool(dynamic value) => TypeConverters.toBool(value);
}
```

---

## Testing Strategy

### Phase 1 Testing
- [ ] Unit tests for `TypeConverters` utility
- [ ] Unit tests for `SyncErrorHandler`
- [ ] Integration tests for `DataIntegrityService`
- [ ] Verify duplicate cleanup works on test data

### Phase 2 Testing
- [ ] Unit tests for each entity service
- [ ] Integration tests for download → upsert flow
- [ ] Integration tests for dirty record collection
- [ ] Verify FK constraints respected

### Phase 3 Testing
- [ ] Integration tests for upload orchestration
- [ ] End-to-end sync test (upload → edge function → download)
- [ ] Multi-device sync test
- [ ] Sign-out/sign-in flow test

### Regression Testing
- [ ] All existing integration tests still pass
- [ ] Manual testing of sync flow in dev environment
- [ ] Verify no data loss during sync
- [ ] Check that dirty records are preserved

---

## Rollback Plan

### Per-Phase Rollback
Each phase is independent and can be rolled back:

**Phase 1**: Remove utility classes, revert to inline code
**Phase 2**: Remove entity services, revert to monolithic methods
**Phase 3**: Remove orchestrator, revert to Phase 2 state

### Feature Flags (Optional)
If gradual rollout is needed, use feature flags:

```dart
if (featureFlags.useRefactoredSync) {
  // Use new services
} else {
  // Use old monolithic approach
}
```

### Database Rollback
No schema changes in this refactoring, so no database rollback needed.

---

## Implementation Checklist

See [implementation-checklist.md](./implementation-checklist.md) for detailed step-by-step tasks.

---

## Success Metrics

- [ ] Main service reduced to <500 lines
- [ ] All code duplication eliminated
- [ ] 90%+ test coverage on new services
- [ ] No sync regressions
- [ ] CI/CD pipeline passes
- [ ] Code review approved

---

**Next Steps**: Start with Phase 1.1 (TypeConverters utility)
