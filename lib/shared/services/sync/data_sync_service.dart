import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import '../../../features/activities/application/calendar_sync_service.dart';

part 'data_sync_service.g.dart';

@riverpod
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    calendarSyncService: ref.read(calendarSyncServiceProvider),
  );
}

/// Unified data sync service with single network call + offline-first architecture
/// Phase 2A: Single network call to sync-all-data + upload dirty records
/// Note: Only syncs calendar data (activities, events, carb loading plans/days, completions)
/// Food syncing is handled by app startup service via checkAndRefreshFoodData()
class DataSyncService {
  const DataSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CalendarSyncService calendarSyncService,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _calendarSyncService = calendarSyncService;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final CalendarSyncService _calendarSyncService;

  /// Sync all app data using single network call + upload dirty records
  /// Returns true if sync was successful, false otherwise
  /// Non-blocking: app continues with cached data if sync fails
  Future<bool> syncAllData(String userId) async {
    try {
      // STEP 1: DOWNLOAD - Single network call to sync-all-data edge function
      final downloadData = await _downloadAllDataFromSupabase(userId);

      // STEP 2: MERGE - Update local Drift database with downloaded data
      await _mergeDownloadedData(downloadData);

      // STEP 3: UPLOAD - Push dirty records to Supabase
      await _uploadDirtyRecords(userId);

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Unified data sync failed - app continuing with cached data',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Download all data from Supabase using single network call
  Future<Map<String, dynamic>> _downloadAllDataFromSupabase(String userId) async {
    try {
      final response = await _supabase.functions.invoke(
        'sync-all-data',
        body: {'user_id': userId},
      );

      if (response.status != 200) {
        throw Exception('sync-all-data failed: ${response.data}');
      }

      final data = response.data['data'] as Map<String, dynamic>;

      return data;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download data from Supabase',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Merge downloaded data into local Drift database
  Future<void> _mergeDownloadedData(Map<String, dynamic> data) async {
    try {
      // Sync calendar data (activities, events, carb loading, completions)
      await _calendarSyncService.syncFromDownloadedData(
        activities: data['activities'] as List<dynamic>,
        events: data['events'] as List<dynamic>,
        carbLoadingPlans: data['carb_loading_plans'] as List<dynamic>,
        carbLoadingDays: data['carb_loading_days'] as List<dynamic>,
        activityCompletions: data['activity_completions'] as List<dynamic>,
      );

      // Note: Food syncing (carb loading foods and nutrition foods) is handled
      // by app startup service via checkAndRefreshFoodData()
      // This avoids duplicate syncing and keeps the sync-all-data focused on calendar data
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to merge downloaded data',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _uploadDirtyRecords(String userId) async {
    try {
      final dirtyActivities = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final dirtyEvents = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final dirtyCarbLoadingPlans = await (_database.select(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final dirtyCarbLoadingDays = await (_database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final dirtyCompletions = await (_database.select(_database.activityCompletionsTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final uploadTasks = <Future<void>>[];

      for (final activity in dirtyActivities) {
        uploadTasks.add(_uploadActivity(userId, activity));
      }

      for (final event in dirtyEvents) {
        uploadTasks.add(_uploadEvent(userId, event));
      }

      for (final plan in dirtyCarbLoadingPlans) {
        uploadTasks.add(_uploadCarbLoadingPlan(userId, plan));
      }

      for (final day in dirtyCarbLoadingDays) {
        uploadTasks.add(_uploadCarbLoadingDay(userId, day));
      }

      for (final completion in dirtyCompletions) {
        uploadTasks.add(_uploadCompletion(userId, completion));
      }

      // Note: User foods upload removed - table doesn't have needsUpload column
      // User foods are synced via other mechanisms

      await Future.wait(uploadTasks);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty records',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _uploadActivity(String userId, Activity activity) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-calendar-activity',
        body: {
          'device_id': userId,
          'activity_id': activity.id,
          'user_id': activity.userId,
          'activity_type': activity.activityType,
          'title': activity.title,
          'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
          'distance_miles': activity.distanceMiles,
          'duration_minutes': activity.durationMinutes,
          'status': activity.status,
          'notes': activity.notes,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await (_database.update(_database.activitiesTable)
              ..where((tbl) => tbl.id.equals(activity.id)))
            .write(const ActivitiesTableCompanion(needsUpload: Value(false)));
      }
    } catch (e) {
      _logger.warning('Failed to upload activity ${activity.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadEvent(String userId, Event event) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-calendar-event',
        body: {
          'device_id': userId,
          'event_id': event.id,
          'user_id': event.userId,
          'event_name': event.eventName,
          'event_type': event.eventType,
          'location': event.location,
          'activity_id': event.activityId,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await (_database.update(_database.eventsTable)
              ..where((tbl) => tbl.id.equals(event.id)))
            .write(const EventsTableCompanion(needsUpload: Value(false)));
      }
    } catch (e) {
      _logger.warning('Failed to upload event ${event.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadCarbLoadingPlan(String userId, CarbLoadingPlan plan) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-carb-loading-plan',
        body: {
          'device_id': userId,
          'operation': 'create',
          'plan_id': plan.id,
          'event_id': plan.eventId,
          'total_days': plan.totalDays,
          'start_date': plan.startDate.toIso8601String(),
          'end_date': plan.endDate.toIso8601String(),
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await (_database.update(_database.carbLoadingPlansTable)
              ..where((tbl) => tbl.id.equals(plan.id)))
            .write(const CarbLoadingPlansTableCompanion(needsUpload: Value(false)));
      }
    } catch (e) {
      _logger.warning('Failed to upload carb loading plan ${plan.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadCarbLoadingDay(String userId, CarbLoadingDay day) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-carb-loading-plan',
        body: {
          'device_id': userId,
          'operation': 'update_day',
          'carb_loading_day_id': day.id,
          'updates': {
            'carb_target_grams': day.carbTargetGrams,
            'completed': day.completed,
          },
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await (_database.update(_database.carbLoadingDaysTable)
              ..where((tbl) => tbl.id.equals(day.id)))
            .write(const CarbLoadingDaysTableCompanion(needsUpload: Value(false)));
      }
    } catch (e) {
      _logger.warning('Failed to upload carb loading day ${day.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadCompletion(String userId, ActivityCompletion completion) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-activity-completion',
        body: {
          'device_id': userId,
          'completion': {
            'id': completion.id,
            'activity_id': completion.activityId,
            'user_id': completion.userId,
            'completed_at': completion.completedAt.toIso8601String(),
            'completion_type': completion.completionType,
            'actual_distance_miles': completion.actualDistanceMiles,
            'actual_duration_minutes': completion.actualDurationMinutes,
          },
          'operation': 'create',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await (_database.update(_database.activityCompletionsTable)
              ..where((tbl) => tbl.id.equals(completion.id)))
            .write(const ActivityCompletionsTableCompanion(needsUpload: Value(false)));
      }
    } catch (e) {
      _logger.warning('Failed to upload completion ${completion.id}', context: 'DATA_SYNC', error: e);
    }
  }

  // _uploadUserFood method removed - UserFoodsTable doesn't have needsUpload column
  // User foods are synced via other mechanisms (barcode scanning service, etc.)
}
