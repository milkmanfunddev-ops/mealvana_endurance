import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';
import '../../../features/nutrition_plan/data/food_repository.dart';
import '../../../features/carb_loading/application/carb_loading_food_sync_service.dart';

import '../../../shared/services/preferences_service.dart';

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
  );
}

/// Unified data sync service - single network call to sync-all-data
/// Phase 2B: Syncs ALL app data including calendar, nutrition foods, and carb loading foods
/// Eliminates redundant network calls - everything comes from sync-all-data edge function
class DataSyncService {
  const DataSyncService({
    required Ref ref,
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required FoodRepository foodRepository,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
  })  : _ref = ref,
        _supabase = supabase,
        _database = database,
        _logger = logger,
        _foodRepository = foodRepository,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService;

  final Ref _ref;
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final FoodRepository _foodRepository;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;

  /// Helper to convert SQLite integer timestamps to ISO8601 strings
  /// Drift stores DateTimeColumn as milliseconds since epoch in SQLite
  /// When using customSelect, we get raw int values, not DateTime objects
  String? _intToIso8601(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return null;
  }

  /// HYBRID SYNC: Try edge function first, fallback to client-side
  /// Returns true if sync was successful, false otherwise
  /// Non-blocking: app continues with cached data if sync fails
  Future<bool> syncAllData(String userId) async {
    try {
      // Get last sync timestamp
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      final lastSyncTimestamp = prefs.getString('last_sync_timestamp_$userId');

      // STEP 0: CRITICAL - Sync user profile first to prevent FK violations
      await syncUsers(userId);

      // STEP 1: CRITICAL - Upload dirty records FIRST to prevent data loss
      await _uploadDirtyRecords(userId);

      // STEP 2: Try edge function for fast parallel download
      final edgeFunctionSuccess = await _tryEdgeFunctionSync(userId, lastSyncTimestamp);

      if (edgeFunctionSuccess) {
        return true;
      }

      // STEP 3: Fallback to client-side download if edge function fails
      await _clientSideDownload(userId);

      // Update timestamp on successful client-side sync too
      await prefs.setString('last_sync_timestamp_$userId', DateTime.now().toIso8601String());

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

      // Get the current user profile from local database
      final localUser = await _database.getCurrentUserProfile();

      if (localUser == null) {
        return; // No local user profile - skipping sync
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
      // CRITICAL: Use 'id' (primary key) for conflict resolution to prevent duplicate key violations
      // Both id and device_id are set to the same userId value (Supabase Auth UUID)
      // Using 'id' ensures proper UPDATE behavior when record already exists
      await _supabase.from('users').upsert(
        userData,
        onConflict: 'id', // Resolve on primary key to prevent duplicate key violations
      );
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
  Future<bool> _tryEdgeFunctionSync(String userId, String? lastSyncTimestamp) async {
    try {
      final response = await _supabase.functions
          .invoke('sync-all-data', body: {
            'user_id': userId,
            if (lastSyncTimestamp != null) 'last_sync_timestamp': lastSyncTimestamp,
          })
          .timeout(
            const Duration(seconds: 30),  // Increased from 15s for large datasets
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

      // Check if sync was successful
      if (data['success'] != true) {
        return false;
      }

      // Sync the data to local database
      await _syncDataFromEdgeFunction(data['data'] as Map<String, dynamic>);

      // Update last sync timestamp
      if (data['timestamp'] != null) {
        final prefs = await _ref.read(sharedPreferencesProvider.future);
        await prefs.setString('last_sync_timestamp_$userId', data['timestamp'] as String);
      }

      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
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
          await _upsertActivity(activityData as Map<String, dynamic>);
        }
      }

      // Sync events
      final events = data['events'] as List<dynamic>?;
      if (events != null) {
        for (final eventData in events) {
          final eventMap = eventData as Map<String, dynamic>;
          await _upsertEvent(eventMap, eventMap['user_id'] as String);
        }
      }

      // Sync carb loading plans
      final carbLoadingPlans = data['carb_loading_plans'] as List<dynamic>?;
      if (carbLoadingPlans != null) {
        for (final planData in carbLoadingPlans) {
          await _upsertCarbLoadingPlan(planData as Map<String, dynamic>);
        }
      }

      // Sync carb loading days
      final carbLoadingDays = data['carb_loading_days'] as List<dynamic>?;
      if (carbLoadingDays != null) {
        for (final dayData in carbLoadingDays) {
          await _upsertCarbLoadingDay(dayData as Map<String, dynamic>);
        }
      }
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

      // CRITICAL: Preserve local data if it has pending changes (needsUpload = true)
      // Phone data is the source of truth - never overwrite local changes
      if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
        return; // Keep local version with pending changes
      }

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

      final remoteUpdatedAt = (data['local_updated_at'] as String?) != null
          ? DateTime.parse(data['local_updated_at'] as String)
          : null;

      // Only upsert if we don't have it locally or the server copy is newer
      final shouldUpsert = existingPlan == null ||
          (remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(existingPlan.localUpdatedAt));

      if (shouldUpsert) {
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
          localUpdatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
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

      final remoteUpdatedAt = (data['local_updated_at'] as String?) != null
          ? DateTime.parse(data['local_updated_at'] as String)
          : null;

      final shouldUpsert = existingDay == null ||
          (remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(existingDay.localUpdatedAt));

      if (shouldUpsert) {
        final companion = CarbLoadingDaysTableCompanion.insert(
          id: Value(dayId),
          carbLoadingPlanId: data['carb_loading_plan_id'] as int,
          planDate: DateTime.parse(data['plan_date'] as String),
          dayNumber: data['day_number'] as int,
          carbTargetGrams: data['carb_target_grams'] as int,
          carbProtocolGPerKg: Value(
            (data['carb_protocol_g_per_kg'] as num?)?.toDouble() ?? 8.0,
          ),
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
          localUpdatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
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
      await _database.ensureUserDataSyncColumns();

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

      // User foods and preferences/feedback/surveys use raw queries for newly added sync columns
      List<QueryRow> dirtyUserFoods = const [];
      try {
        dirtyUserFoods = await _database
            .customSelect('SELECT * FROM user_foods WHERE needs_upload = 1')
            .get();
      } catch (e) {
        // user_foods table missing - skip upload of custom foods
      }

      // food_preferences is server-managed with immediate sync - no background sync needed

      final dirtyFeedback = await _database
          .customSelect('SELECT * FROM feedback WHERE needs_upload = 1')
          .get();

      final dirtyFeatureSurvey = await _database
          .customSelect('SELECT * FROM feature_survey_responses WHERE needs_upload = 1')
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

      for (final row in dirtyUserFoods) {
        uploadTasks.add(_uploadUserFoodRow(row.data));
      }

      // food_preferences handled by immediate sync - no background upload needed

      for (final row in dirtyFeedback) {
        uploadTasks.add(_uploadFeedbackRow(row.data));
      }

      for (final row in dirtyFeatureSurvey) {
        uploadTasks.add(_uploadFeatureSurveyRow(row.data));
      }

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
      final payload = {
        'user_id': userId,
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
      };

      Map<String, dynamic>? updateResponse;

      try {
        // Try to update by existing ID (covers already-synced activities)
        updateResponse = await _supabase
            .from('activities')
            .update(payload)
            .eq('id', activity.id)
            .eq('user_id', userId)
            .select('id')
            .maybeSingle();
      } catch (e) {
        // Activity update attempt failed, will fall back to insert
      }

      int serverId;
      if (updateResponse != null && updateResponse['id'] != null) {
        serverId = updateResponse['id'] as int;
      } else {
        final insertResponse = await _supabase
            .from('activities')
            .insert(payload)
            .select('id')
            .single();
        serverId = insertResponse['id'] as int;
      }

      if (serverId != activity.id) {
        await _rekeyActivityLocally(activity.id, serverId);
      }

      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(serverId)))
          .write(const ActivitiesTableCompanion(needsUpload: Value(false)));
    } catch (e, stackTrace) {
      _logger.error('Failed to upload activity ${activity.id}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _rekeyActivityLocally(int oldId, int newId) async {
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE events SET activity_id = ? WHERE activity_id = ?',
        [newId, oldId],
      );
      await _database.customStatement(
        'UPDATE activities SET id = ? WHERE id = ?',
        [newId, oldId],
      );
    });
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

      // Check for error (handle null response safely)
      if (response?.error == null) {
        await (_database.update(_database.eventsTable)
              ..where((tbl) => tbl.id.equals(event.id)))
            .write(const EventsTableCompanion(needsUpload: Value(false)));
      } else if (response != null) {
        throw response.error!;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to upload event ${event.id}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _uploadCarbLoadingPlan(String userId, CarbLoadingPlan plan) async {
    try {
      final payload = {
        'event_id': plan.eventId,
        'user_id': plan.userId,
        'total_days': plan.totalDays,
        'start_date': plan.startDate.toIso8601String().split('T')[0],
        'end_date': plan.endDate.toIso8601String().split('T')[0],
        'daily_carb_target_grams': plan.dailyCarbTargetGrams,
        'daily_calorie_target': plan.dailyCalorieTarget,
        'generated_at': plan.generatedAt.toIso8601String(),
        'algorithm_version': plan.algorithmVersion,
        'adherence_score': plan.adherenceScore,
        'completed_at': plan.completedAt?.toIso8601String(),
        'local_updated_at': plan.localUpdatedAt.toIso8601String(),
      };

      Map<String, dynamic>? updateResponse;
      try {
        updateResponse = await _supabase
            .from('carb_loading_plans')
            .update(payload)
            .eq('id', plan.id)
            .eq('user_id', plan.userId)
            .select('id')
            .maybeSingle();
      } catch (e) {
        // Carb plan update failed, will insert new server ID
      }

      int serverPlanId;
      if (updateResponse != null && updateResponse['id'] != null) {
        serverPlanId = updateResponse['id'] as int;
      } else {
        final insertResponse = await _supabase
            .from('carb_loading_plans')
            .insert(payload)
            .select('id')
            .single();
        serverPlanId = insertResponse['id'] as int;
      }

      if (serverPlanId != plan.id) {
        await _rekeyPlanLocally(plan.id, serverPlanId);
      }

      await (_database.update(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.id.equals(serverPlanId)))
          .write(const CarbLoadingPlansTableCompanion(needsUpload: Value(false)));
    } catch (e, stackTrace) {
      _logger.error('Failed to upload carb loading plan ${plan.id}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _uploadCarbLoadingDay(String userId, CarbLoadingDay day) async {
    try {
      final payload = {
        'carb_loading_plan_id': day.carbLoadingPlanId,
        'plan_date': day.planDate.toIso8601String().split('T')[0],
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
        'local_updated_at': day.localUpdatedAt.toIso8601String(),
      };

      Map<String, dynamic>? updateResponse;
      try {
        updateResponse = await _supabase
            .from('carb_loading_days')
            .update(payload)
            .eq('id', day.id)
            .eq('carb_loading_plan_id', day.carbLoadingPlanId)
            .select('id')
            .maybeSingle();
      } catch (e) {
        // Carb day update failed, will insert new server ID
      }

      int serverDayId;
      if (updateResponse != null && updateResponse['id'] != null) {
        serverDayId = updateResponse['id'] as int;
      } else {
        final insertResponse = await _supabase
            .from('carb_loading_days')
            .insert(payload)
            .select('id')
            .single();
        serverDayId = insertResponse['id'] as int;
      }

      if (serverDayId != day.id) {
        await _rekeyDayLocally(day.id, serverDayId);
      }

      await (_database.update(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.id.equals(serverDayId)))
          .write(const CarbLoadingDaysTableCompanion(needsUpload: Value(false)));
    } catch (e, stackTrace) {
      _logger.error('Failed to upload carb loading day ${day.id}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  // _uploadUserFood method removed - UserFoodsTable doesn't have needsUpload column
  // User foods are synced via other mechanisms (barcode scanning service, etc.)

  Future<void> _rekeyPlanLocally(int oldId, int newId) async {
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE carb_loading_days SET carb_loading_plan_id = ? WHERE carb_loading_plan_id = ?',
        [newId, oldId],
      );
      await _database.customStatement(
        'UPDATE carb_loading_plans SET id = ? WHERE id = ?',
        [newId, oldId],
      );
    });
  }

  Future<void> _rekeyDayLocally(int oldId, int newId) async {
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE carb_loading_day_meals SET carb_loading_day_id = ? WHERE carb_loading_day_id = ?',
        [newId, oldId],
      );
      await _database.customStatement(
        'UPDATE carb_loading_days SET id = ? WHERE id = ?',
        [newId, oldId],
      );
    });
  }

  Future<void> _uploadUserFoodRow(Map<String, dynamic> row) async {
    try {
      final categories = _parsePgArray(row['categories'] as String?);
      final activityTypes = _parsePgArray(row['activity_types'] as String?);

      await _supabase.from('user_foods').upsert({
        'id': row['id'],
        'device_id': row['device_id'],
        'user_id': row['user_id'],
        'client_food_id': row['client_food_id'],
        'barcode': row['barcode'],
        'name': row['name'],
        'display_name': row['display_name'],
        'display_name_plural': row['display_name_plural'],
        'description': row['description'],
        'image_address': row['image_address'],
        'serving_amount': row['serving_amount'],
        'serving_unit': row['serving_unit'],
        'calories_per_serving': row['calories_per_serving'],
        'carbs_per_serving': row['carbs_per_serving'],
        'protein_per_serving': row['protein_per_serving'],
        'fat_per_serving': row['fat_per_serving'],
        'sodium_mg': row['sodium_mg'],
        'fluid_ml_per_serving': row['fluid_ml_per_serving'],
        'product_type': row['product_type_id'],
        'categories': categories,
        'activity_types': activityTypes,
        'is_electrolyte': row['is_electrolyte'] == 1 || row['is_electrolyte'] == true,
        'to_exclude_from_solver': row['to_exclude_from_solver'] == 1 || row['to_exclude_from_solver'] == true,
        'is_deleted': row['is_deleted'] == 1 || row['is_deleted'] == true,
        'created_at': _intToIso8601(row['created_at']),
        'updated_at': _intToIso8601(row['updated_at']),
        'client_updated_at': _intToIso8601(row['client_updated_at']),
      });

      await _database.customStatement(
        'UPDATE user_foods SET needs_upload = 0 WHERE id = ?',
        [row['id']],
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to upload user food ${row['id']}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  // food_preferences sync removed - table is server-managed with immediate sync in user_repository.dart

  Future<void> _uploadFeedbackRow(Map<String, dynamic> row) async {
    try {
      await _supabase.from('feedback').upsert({
        'id': row['id'],
        'satisfaction_level': row['satisfaction_level'],
        'satisfaction_emoji': row['satisfaction_emoji'],
        'satisfaction_label': row['satisfaction_label'],
        'confidence_level': row['confidence_level'],
        'confidence_label': row['confidence_label'],
        'reuse_intent': row['reuse_intent'],
        'reminder_requested': row['reminder_requested'] == 1 || row['reminder_requested'] == true,
        'missed_reasons': row['missed_reasons'],
        'missed_other': row['missed_other'],
        'reminder_day_of_week': row['reminder_day_of_week'],
        'reminder_hour': row['reminder_hour'],
        'reminder_minute': row['reminder_minute'],
        'reminder_recurring': row['reminder_recurring'] == 1 || row['reminder_recurring'] == true,
        'plan_name': row['plan_name'],
        'user_name': row['user_name'] ?? row['device_id'],
        'timestamp': _intToIso8601(row['timestamp']),
        'created_at': _intToIso8601(row['created_at']),
      });

      await _database.customStatement(
        'UPDATE feedback SET needs_upload = 0 WHERE id = ?',
        [row['id']],
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to upload feedback ${row['id']}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _uploadFeatureSurveyRow(Map<String, dynamic> row) async {
    try {
      await _supabase.from('feature_survey_responses').upsert({
        'id': row['id'],
        'user_id': row['user_id'],
        'selected_features': row['selected_features'],
        'voted_at': _intToIso8601(row['voted_at']),
      });

      await _database.customStatement(
        'UPDATE feature_survey_responses SET needs_upload = 0 WHERE id = ?',
        [row['id']],
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to upload feature survey ${row['id']}', context: 'DATA_SYNC', error: e, stackTrace: stackTrace);
    }
  }

  List<String>? _parsePgArray(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.replaceAll('{', '').replaceAll('}', '');
    if (trimmed.trim().isEmpty) return <String>[];
    return trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}
