import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import '../../../features/nutrition_plan/data/food_repository.dart';
import '../../../features/carb_loading/application/carb_loading_food_sync_service.dart';

part 'data_sync_service.g.dart';

@riverpod
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
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
    required FoodRepository foodRepository,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _foodRepository = foodRepository,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final FoodRepository _foodRepository;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;

  /// HYBRID SYNC: Try edge function first, fallback to client-side
  /// Returns true if sync was successful, false otherwise
  /// Non-blocking: app continues with cached data if sync fails
  Future<bool> syncAllData(String userId) async {
    try {
      _logger.info('Starting hybrid sync', context: 'DATA_SYNC');

      // STEP 0: CRITICAL - Sync user profile first to prevent FK violations
      await syncUsers(userId);

      // STEP 1: CRITICAL - Upload dirty records FIRST to prevent data loss
      // This ensures local changes are saved before downloading fresh data
      await _uploadDirtyRecords(userId);
      _logger.info('Local changes uploaded successfully', context: 'DATA_SYNC');

      // STEP 2: Try edge function for fast parallel download
      final edgeFunctionSuccess = await _tryEdgeFunctionSync(userId);

      if (edgeFunctionSuccess) {
        _logger.info('Edge function sync completed successfully', context: 'DATA_SYNC');
        return true;
      }

      // STEP 3: Fallback to client-side download if edge function fails
      _logger.info('Using client-side fallback sync', context: 'DATA_SYNC');
      await _clientSideDownload(userId);

      _logger.info('Client-side sync completed successfully', context: 'DATA_SYNC');
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

  /// PHASE 1 FIX: Ensure user profile exists in Supabase before syncing dependent records
  /// This prevents foreign key violations on activities, events, etc.
  /// SIMPLIFIED: Only syncs core fields to handle dev/prod schema differences
  Future<void> syncUsers(String userId) async {
    try {
      _logger.debug('[USER_SYNC] Starting user profile sync');

      // Get the current user profile from local database
      final localUser = await _database.getCurrentUserProfile();

      if (localUser == null) {
        _logger.warning('[USER_SYNC] No local user profile found - skipping sync');
        return;
      }

      // Sync ALL fields that exist in PRODUCTION schema (source of truth)
      // Based on /docs/prod_schema.txt lines 1-60
      // CRITICAL: Use userId (auth UUID) as the primary id, not localUser.id
      // This aligns with the user_id refactoring (replaced device_id pattern)
      final userData = {
        'id': userId, // Use Supabase Auth UUID as primary key
        'device_id': userId, // Keep for backward compatibility, but same as id now
        'gender': localUser.gender.name,
        'birthday': localUser.birthday.toIso8601String().split('T')[0],
        'height_feet': localUser.heightFeet,
        'height_inches': localUser.heightInches,
        'weight_pounds': localUser.weightPounds,
        'runs_with_water_bottle': localUser.runsWithWaterBottle,
        'gut_training_level': localUser.gutTraining.name,
        'onboarding_completed': localUser.onboardingCompleted,
        'app_version': localUser.appVersion,
        'created_at': localUser.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        // Production has these columns (lines 27-30 in prod_schema.txt)
        'cycling_ftp_watts': localUser.ftpWatts,
        'prefers_cycling_power': false, // Not in domain model, default
        'swimming_css_seconds_per_100m': localUser.cssPacePer100mSeconds,
        'prefers_swimming_pace': false, // Not in domain model, default
      };

      // Upsert user profile to Supabase
      // CRITICAL: During migration, we must resolve conflicts on device_id
      // Old records may have different id but same device_id, causing constraint violations
      // Using device_id ensures we UPDATE the existing record instead of INSERT attempt
      await _supabase.from('users').upsert(
        userData,
        onConflict: 'device_id', // Resolve on device_id during migration from device_id -> id pattern
      );

      _logger.info('[USER_SYNC] User profile synced successfully', data: {
        'userId': localUser.id,
        'deviceId': userId,
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync user profile - this may cause FK violations',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw to prevent syncing dependent records if user sync fails
      rethrow;
    }
  }

  /// Try to sync using the edge function with timeout
  /// Returns true if successful, false if failed (so we can fallback to client-side)
  Future<bool> _tryEdgeFunctionSync(String userId) async {
    try {
      _logger.debug('[EDGE_SYNC] Attempting edge function sync', data: {'userId': userId});

      final response = await _supabase.functions
          .invoke('sync-all-data', body: {'user_id': userId})
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Edge function timed out after 15 seconds');
            },
          );

      if (response.status != 200) {
        _logger.warning('[EDGE_SYNC] Edge function returned non-200 status: ${response.status}');
        return false;
      }

      if (response.data == null) {
        _logger.warning('[EDGE_SYNC] Edge function returned null data');
        return false;
      }

      final data = response.data as Map<String, dynamic>;

      // Check if sync was successful
      if (data['success'] != true) {
        _logger.warning('[EDGE_SYNC] Edge function reported failure',
          data: {'errors': data['errors']});
        return false;
      }

      // Sync the data to local database
      await _syncDataFromEdgeFunction(data['data'] as Map<String, dynamic>);

      _logger.info('[EDGE_SYNC] Edge function sync successful');
      return true;
    } on TimeoutException catch (e) {
      _logger.warning('[EDGE_SYNC] Edge function timeout', error: e);
      return false;
    } catch (e, stackTrace) {
      _logger.warning('[EDGE_SYNC] Edge function failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Sync data from edge function response to local database
  Future<void> _syncDataFromEdgeFunction(Map<String, dynamic> data) async {
    try {
      // Sync foods (nutrition_foods from edge function)
      final nutritionFoods = data['nutrition_foods'] as List<dynamic>?;
      if (nutritionFoods != null && nutritionFoods.isNotEmpty) {
        await _foodRepository.syncFromDownloadedData(foods: nutritionFoods);
        _logger.debug('[EDGE_SYNC] Synced ${nutritionFoods.length} nutrition foods');
      }

      // Sync carb loading foods
      final carbLoadingFoods = data['carb_loading_foods'] as List<dynamic>?;
      if (carbLoadingFoods != null && carbLoadingFoods.isNotEmpty) {
        await _carbLoadingFoodSyncService.syncFromDownloadedData(
          carbLoadingFoods: carbLoadingFoods,
        );
        _logger.debug('[EDGE_SYNC] Synced ${carbLoadingFoods.length} carb loading foods');
      }

      // Sync activities
      final activities = data['activities'] as List<dynamic>?;
      if (activities != null) {
        for (final activityData in activities) {
          await _upsertActivity(activityData as Map<String, dynamic>);
        }
        _logger.debug('[EDGE_SYNC] Synced ${activities.length} activities');
      }

      // Sync events
      final events = data['events'] as List<dynamic>?;
      if (events != null) {
        for (final eventData in events) {
          await _upsertEvent(eventData as Map<String, dynamic>,
            (eventData as Map<String, dynamic>)['user_id'] as String);
        }
        _logger.debug('[EDGE_SYNC] Synced ${events.length} events');
      }

      // Sync carb loading plans
      final carbLoadingPlans = data['carb_loading_plans'] as List<dynamic>?;
      if (carbLoadingPlans != null) {
        for (final planData in carbLoadingPlans) {
          await _upsertCarbLoadingPlan(planData as Map<String, dynamic>);
        }
        _logger.debug('[EDGE_SYNC] Synced ${carbLoadingPlans.length} carb loading plans');
      }

      // Sync carb loading days
      final carbLoadingDays = data['carb_loading_days'] as List<dynamic>?;
      if (carbLoadingDays != null) {
        for (final dayData in carbLoadingDays) {
          await _upsertCarbLoadingDay(dayData as Map<String, dynamic>);
        }
        _logger.debug('[EDGE_SYNC] Synced ${carbLoadingDays.length} carb loading days');
      }

      _logger.info('[EDGE_SYNC] All data synced to local database');
    } catch (e, stackTrace) {
      _logger.error('[EDGE_SYNC] Failed to sync edge function data to local DB',
        context: 'EDGE_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Client-side download fallback - direct Supabase queries
  Future<void> _clientSideDownload(String userId) async {
    try {
      _logger.debug('[CLIENT_SYNC] Starting client-side download');

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

      _logger.info('[CLIENT_SYNC] Client-side download completed');
    } catch (e, stackTrace) {
      _logger.error('[CLIENT_SYNC] Client-side download failed',
        context: 'CLIENT_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// CLIENT-SIDE: Download nutrition foods directly from Supabase
  Future<void> _downloadFoods() async {
    try {
      final response = await _supabase.from('foods').select('*');
      final foods = response as List<dynamic>;

      // Use existing FoodRepository to sync
      await _foodRepository.syncFromDownloadedData(foods: foods);

      _logger.info('[FOOD_SYNC] Synced ${foods.length} nutrition foods');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download foods',
        context: 'FOOD_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// CLIENT-SIDE: Download carb loading foods directly from Supabase
  Future<void> _downloadCarbLoadingFoods() async {
    try {
      final response = await _supabase.from('carb_loading_foods').select('*');
      final carbFoods = response as List<dynamic>;

      // Use existing CarbLoadingFoodSyncService
      await _carbLoadingFoodSyncService.syncFromDownloadedData(
        carbLoadingFoods: carbFoods,
      );

      _logger.info('[CARB_FOOD_SYNC] Synced ${carbFoods.length} carb loading foods');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download carb loading foods',
        context: 'CARB_FOOD_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// CLIENT-SIDE: Download activities directly from Supabase
  Future<void> _downloadActivities(String userId) async {
    try {
      final response = await _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .order('scheduled_date_time', ascending: false);

      final allActivities = response as List<dynamic>;

      // Filter out soft-deleted activities client-side
      final activities = allActivities.where((a) => a['deleted_at'] == null).toList();

      // Upsert each activity into local database
      for (final activityData in activities) {
        await _upsertActivity(activityData);
      }

      _logger.info('[ACTIVITY_SYNC] Synced ${activities.length} activities');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download activities',
        context: 'ACTIVITY_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// CLIENT-SIDE: Download events directly from Supabase
  Future<void> _downloadEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final events = response as List<dynamic>;

      // Upsert each event into local database
      for (final eventData in events) {
        await _upsertEvent(eventData, userId);
      }

      _logger.info('[EVENT_SYNC] Synced ${events.length} events');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download events',
        context: 'EVENT_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// CLIENT-SIDE: Download carb loading plans and days directly from Supabase
  Future<void> _downloadCarbLoadingPlans(String userId) async {
    try {
      // Download plans
      final plansResponse = await _supabase
          .from('carb_loading_plans')
          .select('*')
          .eq('user_id', userId);

      final plans = plansResponse as List<dynamic>;

      // Upsert each plan
      for (final planData in plans) {
        await _upsertCarbLoadingPlan(planData);
      }

      // Download days for this user's plans
      final daysResponse = await _supabase
          .from('carb_loading_days')
          .select('*, carb_loading_plans!inner(user_id)')
          .eq('carb_loading_plans.user_id', userId);

      final days = daysResponse as List<dynamic>;

      // Upsert each day
      for (final dayData in days) {
        await _upsertCarbLoadingDay(dayData);
      }

      _logger.info('[CARB_PLAN_SYNC] Synced ${plans.length} plans and ${days.length} days');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download carb loading plans',
        context: 'CARB_PLAN_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  Future<void> _upsertActivity(Map<String, dynamic> data) async {
    try {
      final activityId = data['id'] as int;
      final existingActivity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
        final companion = ActivitiesTableCompanion.insert(
          id: Value(activityId),
          userId: data['user_id'] as String,
          activityType: data['activity_type'] as String,
          title: data['title'] as String,
          scheduledDateTime: DateTime.parse(data['scheduled_date_time'] as String),
          status: Value(data['status'] as String? ?? 'planned'),
          distanceMiles: Value((data['distance_miles'] as num?)?.toDouble()),
          durationMinutes: Value(data['duration_minutes'] as int?),
          paceTargetMinutesPerMile: Value((data['pace_target_minutes_per_mile'] as num?)?.toDouble()),
          intensityLevel: Value(data['intensity_level'] as String?),
          cyclingSpeedMph: Value((data['cycling_speed_mph'] as num?)?.toDouble()),
          cyclingTerrain: Value(data['cycling_terrain'] as String?),
          cyclingIndoorOutdoor: Value(data['cycling_indoor_outdoor'] as String?),
          cyclingElevationGainFt: Value(data['cycling_elevation_gain_ft'] as int?),
          cyclingSessionGoal: Value(data['cycling_session_goal'] as String?),
          swimmingPacePer100mSeconds: Value(data['swimming_pace_per_100m_seconds'] as int?),
          swimmingPoolOrOpenWater: Value(data['swimming_pool_or_open_water'] as String?),
          swimmingWaterTempC: Value((data['swimming_water_temp_c'] as num?)?.toDouble()),
          intensityTarget: Value(data['intensity_target'] as String?),
          timeBeforeMinutes: Value(data['time_before_minutes'] as int?),
          completedAt: Value(
            data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
          ),
          completionRating: Value(data['completion_rating'] as int?),
          completionNotes: Value(data['completion_notes'] as String?),
          actualDistanceMiles: Value((data['actual_distance_miles'] as num?)?.toDouble()),
          actualDurationMinutes: Value(data['actual_duration_minutes'] as int?),
          nutritionPlanData: Value(data['nutrition_plan_data'] as String?),
          notes: Value(data['notes'] as String?),
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: supabaseUpdatedAt,
        );

        await _database
            .into(_database.activitiesTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert activity',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': data['id']},
      );
    }
  }

  Future<void> _upsertEvent(Map<String, dynamic> data, String userId) async {
    try {
      final eventId = data['id'] as int;
      final existingEvent = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      if (existingEvent == null || existingEvent.updatedAt.isBefore(supabaseUpdatedAt)) {
        int? activityId;
        if (data['activity_id'] != null) {
          final activity = await (_database.select(_database.activitiesTable)
                ..where((tbl) => tbl.id.equals(data['activity_id'] as int)))
              .getSingleOrNull();
          if (activity == null || activity.userId != userId) {
            return;
          }
          activityId = activity.id;
        }

        final companion = EventsTableCompanion.insert(
          id: Value(eventId),
          userId: data['user_id'] as String? ?? userId,
          activityId: Value(activityId),
          eventType: data['event_type'] as String,
          eventSubtype: Value(data['event_subtype'] as String?),
          eventName: Value(data['event_name'] as String?),
          location: Value(data['location'] as String?),
          registrationUrl: Value(data['registration_url'] as String?),
          startTime: Value(data['start_time'] as String?),
          goalTimeMinutes: Value(data['goal_time_minutes'] as int?),
          goalPaceMinutesPerMile: Value((data['goal_pace_minutes_per_mile'] as num?)?.toDouble()),
          predictedFinishTimeMinutes: Value(data['predicted_finish_time_minutes'] as int?),
          hasCarbLoading: Value(data['has_carb_loading'] as bool? ?? false),
          carbLoadingDays: Value(data['carb_loading_days'] as int?),
          carbLoadingStartDate: Value(
            data['carb_loading_start_date'] != null
                ? DateTime.parse(data['carb_loading_start_date'] as String)
                : null,
          ),
          hasNutritionPlan: Value(data['has_nutrition_plan'] as bool? ?? false),
          bibNumber: Value(data['bib_number'] as String?),
          waveStartTime: Value(data['wave_start_time'] as String?),
          packetPickupInfo: Value(data['packet_pickup_info'] as String?),
          actualFinishTimeMinutes: Value(data['actual_finish_time_minutes'] as int?),
          finalPlacement: Value(data['final_placement'] as int?),
          ageGroupPlacement: Value(data['age_group_placement'] as int?),
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: supabaseUpdatedAt,
        );

        await _database
            .into(_database.eventsTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert event',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'eventId': data['id']},
      );
    }
  }

  Future<void> _upsertCarbLoadingPlan(Map<String, dynamic> data) async {
    try {
      final planId = data['id'] as int;
      final existingPlan = await (_database.select(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.id.equals(planId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      if (existingPlan == null || (existingPlan.localUpdatedAt != null && existingPlan.localUpdatedAt!.isBefore(supabaseUpdatedAt))) {
        final companion = CarbLoadingPlansTableCompanion.insert(
          id: Value(planId),
          eventId: Value(data['event_id'] as int?),
          userId: data['user_id'] as String,
          totalDays: data['total_days'] as int,
          startDate: DateTime.parse(data['start_date'] as String),
          endDate: DateTime.parse(data['end_date'] as String),
          dailyCarbTargetGrams: data['daily_carb_target_grams'] as int,
          dailyCalorieTarget: Value(data['daily_calorie_target'] as int?),
          generatedAt: DateTime.parse(data['generated_at'] as String),
          algorithmVersion: Value(data['algorithm_version'] as String? ?? 'v1.0'),
          adherenceScore: Value((data['adherence_score'] as num?)?.toDouble()),
          completedAt: Value(
            data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
          ),
          needsUpload: const Value(false),
          localUpdatedAt: Value(DateTime.now()),
        );

        await _database
            .into(_database.carbLoadingPlansTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert carb loading plan',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'planId': data['id']},
      );
    }
  }

  Future<void> _upsertCarbLoadingDay(Map<String, dynamic> data) async {
    try {
      final dayId = data['id'] as int;
      final existingDay = await (_database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.id.equals(dayId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      if (existingDay == null || (existingDay.localUpdatedAt != null && existingDay.localUpdatedAt!.isBefore(supabaseUpdatedAt))) {
        final companion = CarbLoadingDaysTableCompanion.insert(
          id: Value(dayId),
          carbLoadingPlanId: data['carb_loading_plan_id'] as int,
          planDate: DateTime.parse(data['plan_date'] as String),
          dayNumber: data['day_number'] as int,
          carbTargetGrams: data['carb_target_grams'] as int,
          carbProtocolGPerKg: (data['carb_protocol_g_per_kg'] as num).toDouble(),
          calorieTarget: Value(data['calorie_target'] as int?),
          mealCount: Value(data['meal_count'] as int? ?? 6),
          breakfastPercent: Value((data['breakfast_percent'] as num?)?.toDouble() ?? 0.25),
          morningSnackPercent: Value((data['morning_snack_percent'] as num?)?.toDouble() ?? 0.10),
          lunchPercent: Value((data['lunch_percent'] as num?)?.toDouble() ?? 0.25),
          afternoonSnackPercent: Value((data['afternoon_snack_percent'] as num?)?.toDouble() ?? 0.15),
          dinnerPercent: Value((data['dinner_percent'] as num?)?.toDouble() ?? 0.20),
          eveningSnackPercent: Value((data['evening_snack_percent'] as num?)?.toDouble() ?? 0.05),
          loggedCarbsGrams: Value(data['logged_carbs_grams'] as int? ?? 0),
          loggedCalories: Value(data['logged_calories'] as int? ?? 0),
          completed: Value(data['completed'] as bool? ?? false),
          needsUpload: const Value(false),
          localUpdatedAt: Value(DateTime.now()),
        );

        await _database
            .into(_database.carbLoadingDaysTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert carb loading day',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'dayId': data['id']},
      );
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
      // Use direct Supabase upsert instead of edge function
      // This is more reliable and consistent with how we handle events
      // NOTE: Do NOT include local_updated_at or needs_upload - these are Drift-only tracking columns
      await _supabase.from('activities').upsert({
        'id': activity.id.toString(),
        'user_id': activity.userId,
        'activity_type': activity.activityType,
        'title': activity.title,
        'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
        'status': activity.status,
        'distance_miles': activity.distanceMiles,
        'duration_minutes': activity.durationMinutes,
        'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
        'intensity_level': activity.intensityLevel,
        'intensity_target': activity.intensityTarget,
        'time_before_minutes': activity.timeBeforeMinutes,
        'notes': activity.notes,
        // Cycling fields
        'cycling_speed_mph': activity.cyclingSpeedMph,
        'cycling_terrain': activity.cyclingTerrain,
        'cycling_indoor_outdoor': activity.cyclingIndoorOutdoor,
        'cycling_elevation_gain_ft': activity.cyclingElevationGainFt,
        'cycling_session_goal': activity.cyclingSessionGoal,
        // Swimming fields
        'swimming_pace_per_100m_seconds': activity.swimmingPacePer100mSeconds,
        'swimming_pool_or_open_water': activity.swimmingPoolOrOpenWater,
        'swimming_water_temp_c': activity.swimmingWaterTempC,
        // Completion fields (if activity is completed)
        'completed_at': activity.completedAt?.toIso8601String(),
        'actual_distance_miles': activity.actualDistanceMiles,
        'actual_duration_minutes': activity.actualDurationMinutes,
        'completion_rating': activity.completionRating,
        'completion_notes': activity.completionNotes,
        // Nutrition plan data (embedded JSON)
        'nutrition_plan_data': activity.nutritionPlanData,
        // Timestamps
        'created_at': activity.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Clear dirty flag on successful upload
      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activity.id)))
          .write(const ActivitiesTableCompanion(needsUpload: Value(false)));
    } catch (e) {
      _logger.warning('Failed to upload activity ${activity.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadEvent(String userId, Event event) async {
    try {
      // For sync, use direct Supabase upsert (event already created locally)
      // This is more reliable than edge function for sync operations
      // NOTE: Do NOT include local_updated_at or needs_upload - these are Drift-only tracking columns
      final response = await _supabase
          .from('events')
          .upsert({
            'id': event.id,
            'user_id': event.userId,
            'activity_id': event.activityId,
            'event_type': event.eventType,
            'event_subtype': event.eventSubtype,
            'event_name': event.eventName,
            'location': event.location,
            'registration_url': event.registrationUrl,
            'start_time': event.startTime,
            'goal_time_minutes': event.goalTimeMinutes,
            'goal_pace_minutes_per_mile': event.goalPaceMinutesPerMile,
            'predicted_finish_time_minutes': event.predictedFinishTimeMinutes,
            'has_carb_loading': event.hasCarbLoading,
            'carb_loading_days': event.carbLoadingDays,
            'carb_loading_start_date': event.carbLoadingStartDate?.toIso8601String(),
            'has_nutrition_plan': event.hasNutritionPlan,
            'bib_number': event.bibNumber,
            'wave_start_time': event.waveStartTime,
            'packet_pickup_info': event.packetPickupInfo,
            'actual_finish_time_minutes': event.actualFinishTimeMinutes,
            'final_placement': event.finalPlacement,
            'age_group_placement': event.ageGroupPlacement,
          });

      // Check for error
      if (response.error == null) {
        await (_database.update(_database.eventsTable)
              ..where((tbl) => tbl.id.equals(event.id)))
            .write(const EventsTableCompanion(needsUpload: Value(false)));
      } else {
        throw response.error!;
      }
    } catch (e) {
      _logger.warning('Failed to upload event ${event.id}', context: 'DATA_SYNC', error: e);
    }
  }

  Future<void> _uploadCarbLoadingPlan(String userId, CarbLoadingPlan plan) async {
    try {
      // For sync, use direct Supabase upsert (plan already created locally)
      // The edge function's 'create' operation expects raw input data we don't have
      // NOTE: Do NOT include local_updated_at or needs_upload - these are Drift-only tracking columns
      final response = await _supabase
          .from('carb_loading_plans')
          .upsert({
            'id': plan.id,
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
      // NOTE: Do NOT include local_updated_at or needs_upload - these are Drift-only tracking columns
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

  // _uploadUserFood method removed - UserFoodsTable doesn't have needsUpload column
  // User foods are synced via other mechanisms (barcode scanning service, etc.)
}
