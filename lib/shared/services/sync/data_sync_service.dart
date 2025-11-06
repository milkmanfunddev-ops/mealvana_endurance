import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import '../../../features/activities/application/calendar_sync_service.dart';
import '../../../features/nutrition_plan/data/food_repository.dart';
import '../../../features/carb_loading/application/carb_loading_food_sync_service.dart';

part 'data_sync_service.g.dart';

@riverpod
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    calendarSyncService: ref.read(calendarSyncServiceProvider),
    foodRepository: ref.read(foodRepositoryProvider),
    carbLoadingFoodSyncService: ref.read(carbLoadingFoodSyncServiceProvider),
  );
}

/// Unified data sync service - single network call to sync-all-data
/// Phase 2B: Syncs ALL app data including calendar, nutrition foods, and carb loading foods
/// Eliminates redundant network calls - everything comes from sync-all-data edge function
class DataSyncService {
  const DataSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CalendarSyncService calendarSyncService,
    required FoodRepository foodRepository,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _calendarSyncService = calendarSyncService,
        _foodRepository = foodRepository,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final CalendarSyncService _calendarSyncService;
  final FoodRepository _foodRepository;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;

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
      _logger.debug('Merging downloaded data into Drift', context: 'DATA_SYNC');

      // Run all merges in parallel for maximum speed
      await Future.wait([
        // Calendar data (activities, events, carb loading plans/days, completions)
        _calendarSyncService.syncFromDownloadedData(
          activities: data['activities'] as List<dynamic>,
          events: data['events'] as List<dynamic>,
          carbLoadingPlans: data['carb_loading_plans'] as List<dynamic>,
          carbLoadingDays: data['carb_loading_days'] as List<dynamic>,
          activityCompletions: data['activity_completions'] as List<dynamic>,
        ),

        // Nutrition plan foods (from sync-all-data, updates seed data)
        _foodRepository.syncFromDownloadedData(
          foods: data['nutrition_foods'] as List<dynamic>,
        ),

        // Carb loading foods and meal types (from sync-all-data, updates seed data)
        _carbLoadingFoodSyncService.syncFromDownloadedData(
          carbLoadingFoods: data['carb_loading_foods'] as List<dynamic>,
          mealTypes: data['meal_types'] as List<dynamic>,
        ),
      ]);

      _logger.debug('Successfully merged all data', context: 'DATA_SYNC');
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

      final dirtyNutritionPlans = await (_database.select(_database.nutritionPlans)
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

      for (final nutritionPlan in dirtyNutritionPlans) {
        uploadTasks.add(_uploadNutritionPlan(userId, nutritionPlan));
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
      // Convert Drift Activity to JSON format expected by edge function
      final activityJson = {
        'id': activity.id,
        'userId': activity.userId,
        'activityType': activity.activityType,
        'title': activity.title,
        'scheduledDateTime': activity.scheduledDateTime.toIso8601String(),
        'status': activity.status,
        'distanceMiles': activity.distanceMiles,
        'durationMinutes': activity.durationMinutes,
        'paceTargetMinutesPerMile': activity.paceTargetMinutesPerMile,
        'intensityLevel': activity.intensityLevel,
        'intensityTarget': activity.intensityTarget,
        'timeBeforeMinutes': activity.timeBeforeMinutes,
        'notes': activity.notes,
        // Cycling fields
        'cyclingSpeedMph': activity.cyclingSpeedMph,
        'cyclingTerrain': activity.cyclingTerrain,
        'cyclingIndoorOutdoor': activity.cyclingIndoorOutdoor,
        'cyclingElevationGainFt': activity.cyclingElevationGainFt,
        'cyclingSessionGoal': activity.cyclingSessionGoal,
        // Swimming fields
        'swimmingPacePer100mSeconds': activity.swimmingPacePer100mSeconds,
        'swimmingPoolOrOpenWater': activity.swimmingPoolOrOpenWater,
        'swimmingWaterTempC': activity.swimmingWaterTempC,
        // Completion fields (if activity is completed)
        'completedAt': activity.completedAt?.toIso8601String(),
        'actualDistanceMiles': activity.actualDistanceMiles,
        'actualDurationMinutes': activity.actualDurationMinutes,
        'completionRating': activity.completionRating,
        'completionNotes': activity.completionNotes,
      };

      final response = await _supabase.functions.invoke(
        'save-calendar-activity',
        body: {
          'device_id': userId,
          'activity': activityJson,
          'operation': 'update', // Use 'update' for sync (handles both create and update)
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
      // Convert Drift Event to JSON format expected by edge function
      final eventJson = {
        'id': event.id,
        'userId': event.userId,
        'activityId': event.activityId,
        'eventType': event.eventType,
        'eventSubtype': event.eventSubtype,
        'eventName': event.eventName,
        'location': event.location,
        'registrationUrl': event.registrationUrl,
        'startTime': event.startTime, // Already a string
        'goalTimeMinutes': event.goalTimeMinutes,
        'goalPaceMinutesPerMile': event.goalPaceMinutesPerMile,
        'predictedFinishTimeMinutes': event.predictedFinishTimeMinutes,
        'hasCarbLoading': event.hasCarbLoading,
        'carbLoadingDays': event.carbLoadingDays,
        'carbLoadingStartDate': event.carbLoadingStartDate?.toIso8601String(),
        'hasNutritionPlan': event.hasNutritionPlan,
        'bibNumber': event.bibNumber,
        'waveStartTime': event.waveStartTime,
        'packetPickupInfo': event.packetPickupInfo,
        'actualFinishTimeMinutes': event.actualFinishTimeMinutes,
        'finalPlacement': event.finalPlacement,
        'ageGroupPlacement': event.ageGroupPlacement,
      };

      final response = await _supabase.functions.invoke(
        'save-calendar-event',
        body: {
          'device_id': userId,
          'event': eventJson,
          'operation': 'update', // Use 'update' for sync (handles both create and update)
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
      // For sync, use direct Supabase upsert (plan already created locally)
      // The edge function's 'create' operation expects raw input data we don't have
      final response = await _supabase
          .from('carb_loading_plans')
          .upsert({
            'id': plan.id,
            'device_id': userId,
            'event_id': plan.eventId,
            'user_id': plan.userId,
            'total_days': plan.totalDays,
            'start_date': plan.startDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
            'end_date': plan.endDate.toIso8601String().split('T')[0],
            'daily_carb_target_grams': plan.dailyCarbTargetGrams,
            'daily_calorie_target': plan.dailyCalorieTarget,
            'generated_at': plan.generatedAt.toIso8601String(),
            'algorithm_version': plan.algorithmVersion,
            'adherence_score': plan.adherenceScore,
            'completed_at': plan.completedAt?.toIso8601String(),
            'needs_upload': false,
            'local_updated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

      // Check for error
      if (response.error == null) {
        await (_database.update(_database.carbLoadingPlansTable)
              ..where((tbl) => tbl.id.equals(plan.id)))
            .write(const CarbLoadingPlansTableCompanion(needsUpload: Value(false)));
      } else {
        throw response.error!;
      }
    } catch (e) {
      _logger.warning('Failed to upload carb loading plan ${plan.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadCarbLoadingDay(String userId, CarbLoadingDay day) async {
    try {
      // Use direct Supabase upsert for carb loading days (already created locally)
      final response = await _supabase
          .from('carb_loading_days')
          .upsert({
            'id': day.id,
            'carb_loading_plan_id': day.carbLoadingPlanId,
            'plan_date': day.planDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
            'day_number': day.dayNumber,
            'carb_target_grams': day.carbTargetGrams,
            'carb_protocol_g_per_kg': day.carbProtocolGPerKg,
            'meal_count': day.mealCount,
            'breakfast_percent': day.breakfastPercent,
            'morning_snack_percent': day.morningSnackPercent,
            'lunch_percent': day.lunchPercent,
            'afternoon_snack_percent': day.afternoonSnackPercent,
            'dinner_percent': day.dinnerPercent,
            'evening_snack_percent': day.eveningSnackPercent,
            'logged_carbs_grams': day.loggedCarbsGrams,
            'logged_calories': day.loggedCalories,
            'completed': day.completed,
            'needs_upload': false,
            'local_updated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

      // Check for error
      if (response.error == null) {
        await (_database.update(_database.carbLoadingDaysTable)
              ..where((tbl) => tbl.id.equals(day.id)))
            .write(const CarbLoadingDaysTableCompanion(needsUpload: Value(false)));
      } else {
        throw response.error!;
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

  Future<void> _uploadNutritionPlan(String userId, NutritionPlanEntry plan) async {
    try {
      // Check if activity_id exists in Supabase (if plan is linked to an activity)
      String? activityIdToSync = plan.activityId;
      if (plan.activityId != null) {
        final activityExists = await _supabase
            .from('activities')
            .select('id')
            .eq('id', plan.activityId!)
            .maybeSingle();

        // If activity doesn't exist in Supabase yet, set activity_id to null for now
        // It will be updated later when the activity syncs
        if (activityExists == null) {
          activityIdToSync = null;
          _logger.debug(
            'Activity ${plan.activityId} not found in Supabase, syncing plan without activity link',
            context: 'DATA_SYNC',
          );
        }
      }

      // Use direct Supabase upsert for nutrition plans (already created locally)
      // Specify onConflict to handle the UNIQUE constraint on (device_id, plan_id)
      final response = await _supabase
          .from('nutrition_plans')
          .upsert({
            'id': plan.id,
            'device_id': plan.deviceId,
            'plan_data': plan.planData,
            'plan_id': plan.planId,
            'plan_name': plan.planName,
            'distance_miles': plan.distanceMiles,
            'pace_minutes_per_mile': plan.paceMinutesPerMile,
            'total_calories': plan.totalCalories,
            'notes': plan.notes,
            'activity_id': activityIdToSync, // Use null if activity doesn't exist yet
            'plan_type': plan.planType,
            'sport_type': plan.sportType,
            'version': plan.version,
            'last_modified_by': plan.lastModifiedBy,
            'client_updated_at': plan.clientUpdatedAt?.toIso8601String(),
            'is_deleted': plan.isDeleted,
            'conflict_resolution': plan.conflictResolution,
            'needs_upload': false,
            'local_updated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'device_id,plan_id', // Handle UNIQUE constraint on (device_id, plan_id)
        );

      // If upsert succeeds (no exception thrown), mark as synced
      await (_database.update(_database.nutritionPlans)
            ..where((tbl) => tbl.id.equals(plan.id)))
          .write(const NutritionPlansCompanion(needsUpload: Value(false)));
    } catch (e) {
      _logger.warning('Failed to upload nutrition plan ${plan.id}', context: 'DATA_SYNC', error: e);
    }
  }

  // _uploadUserFood method removed - UserFoodsTable doesn't have needsUpload column
  // User foods are synced via other mechanisms (barcode scanning service, etc.)
}
