import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import '../../../features/nutrition_plan/data/food_repository.dart';
import '../../../features/carb_loading/application/carb_loading_food_sync_service.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../features/calendar/presentation/providers/calendar_controller.dart';

import 'duplicate_cleanup_service.dart';
import 'entity_sync/entity_sync.dart';

part 'data_sync_service.g.dart';

@Riverpod(keepAlive: true)
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    ref: ref,
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    foodRepository: ref.read(foodRepositoryProvider),
    carbLoadingFoodSyncService: ref.read(carbLoadingFoodSyncServiceProvider),
    duplicateCleanupService: ref.read(duplicateCleanupServiceProvider),
    activitySyncHandler: ref.read(activitySyncHandlerProvider),
    eventSyncHandler: ref.read(eventSyncHandlerProvider),
    carbLoadingSyncHandler: ref.read(carbLoadingSyncHandlerProvider),
    coachSyncHandler: ref.read(coachSyncHandlerProvider),
    userSyncHandler: ref.read(userSyncHandlerProvider),
    foodPreferenceSyncHandler: ref.read(foodPreferenceSyncHandlerProvider),
  );
}

/// Unified data sync service - single network call to sync-all-data.
///
/// This is a thin orchestrator that delegates to specialized entity handlers.
/// Syncs ALL app data including calendar, nutrition foods, and carb loading foods.
/// Eliminates redundant network calls - everything comes from sync-all-data edge function.
class DataSyncService {
  const DataSyncService({
    required Ref ref,
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required FoodRepository foodRepository,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
    required DuplicateCleanupService duplicateCleanupService,
    required ActivitySyncHandler activitySyncHandler,
    required EventSyncHandler eventSyncHandler,
    required CarbLoadingSyncHandler carbLoadingSyncHandler,
    required CoachSyncHandler coachSyncHandler,
    required UserSyncHandler userSyncHandler,
    required FoodPreferenceSyncHandler foodPreferenceSyncHandler,
  })  : _ref = ref,
        _supabase = supabase,
        _database = database,
        _logger = logger,
        _foodRepository = foodRepository,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService,
        _duplicateCleanupService = duplicateCleanupService,
        _activitySyncHandler = activitySyncHandler,
        _eventSyncHandler = eventSyncHandler,
        _carbLoadingSyncHandler = carbLoadingSyncHandler,
        _coachSyncHandler = coachSyncHandler,
        _userSyncHandler = userSyncHandler,
        _foodPreferenceSyncHandler = foodPreferenceSyncHandler;

  final Ref _ref;
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final FoodRepository _foodRepository;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;
  final DuplicateCleanupService _duplicateCleanupService;

  // Entity sync handlers
  final ActivitySyncHandler _activitySyncHandler;
  final EventSyncHandler _eventSyncHandler;
  final CarbLoadingSyncHandler _carbLoadingSyncHandler;
  final CoachSyncHandler _coachSyncHandler;
  final UserSyncHandler _userSyncHandler;
  final FoodPreferenceSyncHandler _foodPreferenceSyncHandler;

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// HYBRID SYNC: Try edge function first, fallback to client-side.
  /// Returns true if sync was successful, false otherwise.
  /// Non-blocking: app continues with cached data if sync fails.
  Future<bool> syncAllData(String userId) async {
    try {
      // Get last sync timestamp
      final prefs = _ref.read(sharedPreferencesProvider);
      final lastSyncTimestamp = prefs.getString('last_sync_timestamp_$userId');

      // STEP 0: CRITICAL - Sync user profile first to prevent FK violations
      await _userSyncHandler.syncUsers(userId);

      // STEP 1: CRITICAL - Upload dirty records FIRST to prevent data loss
      await uploadDirtyRecords(userId);

      // STEP 2: Try edge function for fast parallel download
      final edgeFunctionSuccess = await _tryEdgeFunctionSync(userId, lastSyncTimestamp);

      if (edgeFunctionSuccess) {
        _invalidateCalendarProviders();
        return true;
      }

      // STEP 3: Fallback to client-side download if edge function fails
      await _clientSideDownload(userId);

      // Update timestamp on successful client-side sync too
      await prefs.setString('last_sync_timestamp_$userId', DateTime.now().toIso8601String());

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

  /// Sync coach messages for a specific activity from Supabase.
  Future<void> syncCoachMessagesForActivity(String activityId) async {
    await _coachSyncHandler.syncCoachMessagesForActivity(activityId);
  }

  /// Sync data for a specific athlete (lightweight, on-demand).
  Future<void> syncAthleteData(String athleteUserId) async {
    await _coachSyncHandler.syncAthleteData(athleteUserId);
  }

  /// Ensure user profile exists in Supabase before syncing dependent records.
  Future<void> syncUsers(String userId) async {
    await _userSyncHandler.syncUsers(userId);
  }

  /// Upload dirty records to Supabase (upload-first pattern).
  /// Returns map of table -> upload success for monitoring/retry logic.
  Future<Map<String, bool>> uploadDirtyRecords(String userId) async {
    final uploadResults = <String, bool>{};

    try {
      await _database.ensureUserDataSyncColumns();

      // Clean duplicates from Drift before collecting records
      await _duplicateCleanupService.cleanAllDuplicates(userId);

      // Collect dirty records from all tables
      final dirtyUserProfiles = await (_database.select(_database.userProfilesTable)
            ..where((tbl) => tbl.needsUpload.equals(true) & tbl.id.equals(userId)))
          .get();
      final dirtyUserProfile = dirtyUserProfiles.isNotEmpty ? dirtyUserProfiles.first : null;

      final dirtyActivities = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.needsUpload.equals(true) & tbl.userId.equals(userId)))
          .get();

      final dirtyEvents = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.needsUpload.equals(true) & tbl.userId.equals(userId)))
          .get();

      final dirtyCarbLoadingPlans = await (_database.select(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.needsUpload.equals(true) & tbl.userId.equals(userId)))
          .get();

      final dirtyCarbLoadingDays = await (_database.select(_database.carbLoadingDaysTable).join([
        innerJoin(
          _database.carbLoadingPlansTable,
          _database.carbLoadingPlansTable.id.equalsExp(_database.carbLoadingDaysTable.carbLoadingPlanId),
        )
      ])
            ..where(_database.carbLoadingDaysTable.needsUpload.equals(true) &
                _database.carbLoadingPlansTable.userId.equals(userId)))
          .map((row) => row.readTable(_database.carbLoadingDaysTable))
          .get();

      // User foods use raw queries
      List<QueryRow> dirtyUserFoods = const [];
      try {
        dirtyUserFoods = await _database
            .customSelect(
              'SELECT * FROM user_foods WHERE needs_upload = 1 AND user_id = ?',
              variables: [Variable.withString(userId)],
            )
            .get();
      } catch (e) {
        // Table might not exist yet
      }

      final dirtyFeedback = await _database
          .customSelect(
            'SELECT * FROM feedback WHERE needs_upload = 1 AND device_id = ?',
            variables: [Variable.withString(userId)],
          )
          .get();

      // Check if there are any dirty records for edge function
      final hasEdgeFunctionRecords = dirtyActivities.isNotEmpty ||
          dirtyEvents.isNotEmpty ||
          dirtyCarbLoadingPlans.isNotEmpty ||
          dirtyCarbLoadingDays.isNotEmpty ||
          dirtyUserFoods.isNotEmpty ||
          dirtyFeedback.isNotEmpty;

      // If nothing to upload via edge function, handle user profile separately
      if (!hasEdgeFunctionRecords) {
        if (dirtyUserProfile != null) {
          try {
            await _userSyncHandler.uploadUserProfile(dirtyUserProfile);
            uploadResults['users'] = true;
            await _userSyncHandler.uploadFoodPreferences(dirtyUserProfile.id);
            uploadResults['food_preferences'] = true;
          } catch (e, stackTrace) {
            _logger.error(
              'Failed to upload user profile',
              context: 'DATA_SYNC',
              error: e,
              stackTrace: stackTrace,
            );
            uploadResults['users'] = false;
          }
        }
        return uploadResults;
      }

      // CRITICAL: Ensure user exists in Supabase FIRST to satisfy FK constraints
      // This checks if user exists remotely and uploads if not (regardless of dirty flag)
      try {
        await _userSyncHandler.syncUsers(userId);
        uploadResults['users'] = true;

        // Also upload dirty user profile if it has pending changes
        if (dirtyUserProfile != null) {
          await _userSyncHandler.uploadUserProfile(dirtyUserProfile);
          await _userSyncHandler.uploadFoodPreferences(dirtyUserProfile.id);
          uploadResults['food_preferences'] = true;
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to ensure user exists in Supabase (required for FK constraints)',
          context: 'DATA_SYNC',
          error: e,
          stackTrace: stackTrace,
        );
        uploadResults['users'] = false;
        // Don't continue with activities if user sync failed - FK errors are guaranteed
        return uploadResults;
      }

      // Build request payload
      final dirtyRecords = <String, dynamic>{};

      if (dirtyActivities.isNotEmpty) {
        dirtyRecords['activities'] =
            dirtyActivities.map((a) => _activitySyncHandler.activityToJson(a)).toList();
      }

      if (dirtyEvents.isNotEmpty) {
        dirtyRecords['events'] =
            dirtyEvents.map((e) => _eventSyncHandler.eventToJson(e)).toList();
      }

      if (dirtyCarbLoadingPlans.isNotEmpty) {
        dirtyRecords['carb_loading_plans'] = dirtyCarbLoadingPlans
            .map((p) => _carbLoadingSyncHandler.carbLoadingPlanToJson(p))
            .toList();
      }

      if (dirtyCarbLoadingDays.isNotEmpty) {
        dirtyRecords['carb_loading_days'] = dirtyCarbLoadingDays
            .map((d) => _carbLoadingSyncHandler.carbLoadingDayToJson(d))
            .toList();
      }

      if (dirtyUserFoods.isNotEmpty) {
        dirtyRecords['user_foods'] = dirtyUserFoods.map((row) => row.data).toList();
      }

      if (dirtyFeedback.isNotEmpty) {
        dirtyRecords['feedback'] = dirtyFeedback.map((row) => row.data).toList();
      }

      // Call upload-all-data edge function
      final response = await _supabase.functions.invoke(
        'upload-all-data',
        body: {
          'user_id': userId,
          'dirty_records': dirtyRecords,
        },
      );

      if (response.status != 200) {
        throw Exception('Edge function returned status ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as Map<String, dynamic>;

      // Process results and clear needs_upload flags for successful uploads
      for (final entry in results.entries) {
        final tableName = entry.key;
        final result = entry.value as Map<String, dynamic>;
        final success = result['success'] as bool? ?? false;

        uploadResults[tableName] = success;

        if (success) {
          await _clearNeedsUploadFlag(tableName, userId);
        } else {
          _logger.warning(
            'Failed to upload $tableName',
            context: 'DATA_SYNC',
            data: {'error': result['error']},
          );
        }
      }

      return uploadResults;
    } catch (e, stackTrace) {
      _logger.error(
        'Upload via edge function failed',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      return uploadResults;
    }
  }

  /// Detect if this is a fresh device (needs full sync).
  Future<bool> needsFullSync(String userId) async {
    try {
      // Check 1: User profile exists?
      final profileCount = await (_database.select(_database.userProfilesTable)
            ..where((t) => t.id.equals(userId)))
          .get();

      if (profileCount.isEmpty) {
        return true;
      }

      // Check 2: Have we ever synced?
      final prefs = _ref.read(sharedPreferencesProvider);
      final lastSync = prefs.getString('last_sync_timestamp_$userId');

      if (lastSync == null) {
        return true;
      }

      // Check 3: Is sync very old? (>30 days = treat as fresh)
      final lastSyncDate = DateTime.tryParse(lastSync);
      if (lastSyncDate == null) {
        return true;
      }

      final daysSinceSync = DateTime.now().difference(lastSyncDate).inDays;

      if (daysSinceSync > 30) {
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.error(
        'Error checking fresh device status',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      return true; // Err on side of full sync
    }
  }

  // ============================================================================
  // PRIVATE - EDGE FUNCTION SYNC
  // ============================================================================

  /// Try to sync using the edge function with timeout.
  Future<bool> _tryEdgeFunctionSync(String userId, String? lastSyncTimestamp) async {
    try {
      final response = await _supabase.functions
          .invoke('sync-all-data', body: {
            'user_id': userId,
            if (lastSyncTimestamp != null) 'last_sync_timestamp': lastSyncTimestamp,
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Edge function timed out after 30 seconds');
            },
          );

      if (response.status != 200) {
        return false;
      }

      if (response.data == null) {
        return false;
      }

      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        return false;
      }

      // Sync the data to local database
      await _syncDataFromEdgeFunction(data['data'] as Map<String, dynamic>, userId);

      // Update last sync timestamp
      if (data['timestamp'] != null) {
        final prefs = _ref.read(sharedPreferencesProvider);
        await prefs.setString('last_sync_timestamp_$userId', data['timestamp'] as String);
      }

      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Sync data from edge function response to local database.
  Future<void> _syncDataFromEdgeFunction(Map<String, dynamic> data, String userId) async {
    try {
      // Sync foods (nutrition_foods from edge function)
      final nutritionFoods = data['nutrition_foods'] as List<dynamic>?;
      if (nutritionFoods != null && nutritionFoods.isNotEmpty) {
        await _foodRepository.syncFromDownloadedData(foods: nutritionFoods);
      }

      // Sync carb loading foods
      final carbLoadingFoods = data['carb_loading_foods'] as List<dynamic>?;
      if (carbLoadingFoods != null && carbLoadingFoods.isNotEmpty) {
        await _carbLoadingFoodSyncService.syncFromDownloadedData(
          carbLoadingFoods: carbLoadingFoods,
        );
      }

      // Sync activities
      final activities = data['activities'] as List<dynamic>?;
      if (activities != null) {
        for (final activityData in activities) {
          await _activitySyncHandler.upsertActivity(activityData as Map<String, dynamic>);
        }
      }

      // Sync events
      final events = data['events'] as List<dynamic>?;
      if (events != null) {
        for (final eventData in events) {
          final eventMap = eventData as Map<String, dynamic>;
          await _eventSyncHandler.upsertEvent(eventMap, eventMap['user_id'] as String);
        }
      }

      // Sync carb loading plans
      final carbLoadingPlans = data['carb_loading_plans'] as List<dynamic>?;
      if (carbLoadingPlans != null) {
        for (final planData in carbLoadingPlans) {
          await _carbLoadingSyncHandler.upsertCarbLoadingPlan(planData as Map<String, dynamic>);
        }
      }

      // Sync carb loading days
      final carbLoadingDays = data['carb_loading_days'] as List<dynamic>?;
      if (carbLoadingDays != null) {
        for (final dayData in carbLoadingDays) {
          await _carbLoadingSyncHandler.upsertCarbLoadingDay(dayData as Map<String, dynamic>);
        }
      }

      // Sync food preferences
      final foodPreferences = data['food_preferences'] as List<dynamic>?;
      if (foodPreferences != null && foodPreferences.isNotEmpty) {
        await _foodPreferenceSyncHandler.syncFoodPreferencesFromEdgeFunction(foodPreferences);
      }

      // Sync coach record if user is an approved coach
      final coachRecord = data['coach_record'] as Map<String, dynamic>?;
      if (coachRecord != null) {
        await _coachSyncHandler.syncCoachRecord(coachRecord);
      }

      // Sync coach-athlete relationships
      final relationships = data['coach_athlete_relationships'] as List<dynamic>?;
      if (relationships != null && relationships.isNotEmpty) {
        await _coachSyncHandler.syncCoachAthleteRelationships(relationships);
      }

      // Sync athlete data for coaches
      final athleteEvents = data['athlete_events'] as List<dynamic>?;
      if (athleteEvents != null && athleteEvents.isNotEmpty) {
        await _eventSyncHandler.syncAthleteEvents(athleteEvents);
      }

      final athleteActivities = data['athlete_activities'] as List<dynamic>?;
      if (athleteActivities != null && athleteActivities.isNotEmpty) {
        await _activitySyncHandler.syncAthleteActivities(athleteActivities);
      }

      final athleteProfiles = data['athlete_profiles'] as List<dynamic>?;
      if (athleteProfiles != null && athleteProfiles.isNotEmpty) {
        await _coachSyncHandler.syncAthleteProfiles(athleteProfiles);
      }

      final athleteCarbLoadingPlans = data['athlete_carb_loading_plans'] as List<dynamic>?;
      if (athleteCarbLoadingPlans != null && athleteCarbLoadingPlans.isNotEmpty) {
        await _carbLoadingSyncHandler.syncAthleteCarbLoadingPlans(athleteCarbLoadingPlans);
      }

      // Sync coach profiles for athletes
      final coachProfiles = data['coach_profiles'] as List<dynamic>?;
      if (coachProfiles != null && coachProfiles.isNotEmpty) {
        await _coachSyncHandler.syncCoachProfiles(coachProfiles);
      }
    } catch (e, stackTrace) {
      _logger.error(
        '[EDGE_SYNC] Failed to sync edge function data to local DB',
        context: 'EDGE_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // PRIVATE - CLIENT-SIDE DOWNLOAD (FALLBACK)
  // ============================================================================

  /// Client-side download fallback - direct Supabase queries.
  Future<void> _clientSideDownload(String userId) async {
    try {
      // STEP 1: Download reference data in parallel
      await Future.wait([
        _downloadFoods(),
        _downloadCarbLoadingFoods(),
      ]);

      // STEP 2: Download user-specific data in parallel
      await Future.wait([
        _downloadActivities(userId),
        _downloadEvents(userId),
        _downloadCarbLoadingPlans(userId),
      ]);
    } catch (e, stackTrace) {
      _logger.error(
        '[CLIENT_SYNC] Client-side download failed',
        context: 'CLIENT_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _downloadFoods() async {
    try {
      final response = await _supabase.from('foods').select('*');
      final foods = response as List<dynamic>;
      await _foodRepository.syncFromDownloadedData(foods: foods);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download foods',
        context: 'FOOD_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _downloadCarbLoadingFoods() async {
    try {
      final response = await _supabase.from('carb_loading_foods').select('*');
      final carbFoods = response as List<dynamic>;
      await _carbLoadingFoodSyncService.syncFromDownloadedData(
        carbLoadingFoods: carbFoods,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download carb loading foods',
        context: 'CARB_FOOD_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _downloadActivities(String userId) async {
    try {
      final response = await _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .order('scheduled_date_time', ascending: false);

      final allActivities = response as List<dynamic>;
      final activities = allActivities.where((a) => a['deleted_at'] == null).toList();

      for (final activityData in activities) {
        await _activitySyncHandler.upsertActivity(activityData);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download activities',
        context: 'ACTIVITY_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _downloadEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final events = response as List<dynamic>;

      for (final eventData in events) {
        await _eventSyncHandler.upsertEvent(eventData, userId);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download events',
        context: 'EVENT_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _downloadCarbLoadingPlans(String userId) async {
    try {
      // Download plans
      final plansResponse = await _supabase
          .from('carb_loading_plans')
          .select('*')
          .eq('user_id', userId);

      final plans = plansResponse as List<dynamic>;

      for (final planData in plans) {
        await _carbLoadingSyncHandler.upsertCarbLoadingPlan(planData);
      }

      // Download days for this user's plans
      final daysResponse = await _supabase
          .from('carb_loading_days')
          .select('*, carb_loading_plans!inner(user_id)')
          .eq('carb_loading_plans.user_id', userId);

      final days = daysResponse as List<dynamic>;

      for (final dayData in days) {
        await _carbLoadingSyncHandler.upsertCarbLoadingDay(dayData);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download carb loading plans',
        context: 'CARB_PLAN_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ============================================================================
  // PRIVATE - HELPERS
  // ============================================================================

  /// Clear needs_upload flag for successfully uploaded records.
  Future<void> _clearNeedsUploadFlag(String tableName, String userId) async {
    try {
      switch (tableName) {
        case 'activities':
          await _database.customStatement(
            'UPDATE activities SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'events':
          await _database.customStatement(
            'UPDATE events SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'carb_loading_plans':
          await _database.customStatement(
            'UPDATE carb_loading_plans SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'carb_loading_days':
          await _database.customStatement(
            '''UPDATE carb_loading_days
               SET needs_upload = 0
               WHERE carb_loading_plan_id IN (
                 SELECT id FROM carb_loading_plans WHERE user_id = ?
               ) AND needs_upload = 1''',
            [userId],
          );
          break;
        case 'user_foods':
          await _database.customStatement(
            'UPDATE user_foods SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'feedback':
          await _database.customStatement(
            'UPDATE feedback SET needs_upload = 0 WHERE device_id = (SELECT device_id FROM users WHERE id = ?) AND needs_upload = 1',
            [userId],
          );
          break;
      }
    } catch (e) {
      _logger.error(
        'Failed to clear needs_upload flag',
        context: 'DATA_SYNC',
        error: e,
        data: {'table': tableName},
      );
    }
  }

  /// Invalidate calendar-related providers to refresh UI after sync.
  void _invalidateCalendarProviders() {
    _ref.invalidate(calendarControllerProvider);
    _ref.invalidate(allEventsControllerProvider);
    _ref.invalidate(nextUpcomingEventProvider);
  }
}
