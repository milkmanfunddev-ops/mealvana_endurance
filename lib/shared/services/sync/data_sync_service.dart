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
import '../../../features/auth/domain/user_preferences.dart';

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
      _logger.info(
        'Starting syncAllData',
        context: 'DATA_SYNC',
        data: {'userId': userId},
      );

      // Get last sync timestamp
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      final lastSyncTimestamp = prefs.getString('last_sync_timestamp_$userId');

      // STEP 0: CRITICAL - Sync user profile first to prevent FK violations
      _logger.info('STEP 0: Syncing user profile', context: 'DATA_SYNC');
      await syncUsers(userId);

      // STEP 1: CRITICAL - Upload dirty records FIRST to prevent data loss
      _logger.info('STEP 1: Uploading dirty records', context: 'DATA_SYNC');
      await _uploadDirtyRecords(userId);

      // STEP 2: Try edge function for fast parallel download
      _logger.info('STEP 2: Trying edge function sync', context: 'DATA_SYNC');
      final edgeFunctionSuccess = await _tryEdgeFunctionSync(userId, lastSyncTimestamp);

      if (edgeFunctionSuccess) {
        _logger.info(
          'Edge function sync completed successfully',
          context: 'DATA_SYNC',
          data: {'userId': userId},
        );
        return true;
      }

      // STEP 3: Fallback to client-side download if edge function fails
      _logger.info('STEP 3: Falling back to client-side download', context: 'DATA_SYNC');
      await _clientSideDownload(userId);

      // Update timestamp on successful client-side sync too
      await prefs.setString('last_sync_timestamp_$userId', DateTime.now().toIso8601String());

      _logger.info(
        'Client-side sync completed successfully',
        context: 'DATA_SYNC',
        data: {'userId': userId},
      );
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
  ///
  /// MULTI-DEVICE FIX: If no local user profile exists but user is authenticated,
  /// fetch the profile from Supabase first (important for new device login)
  ///
  /// SIGN-BACK-IN FIX: If local user ID doesn't match the auth user ID,
  /// fetch the correct profile from Supabase (important for sign-out/sign-in flow)
  Future<void> syncUsers(String userId) async {
    try {

      // Get the current user profile from local database
      var localUser = await _database.getCurrentUserProfile();

      // SIGN-BACK-IN FIX: Check if local user ID matches the auth user ID
      // After sign-out, local DB has anonymous user, but we're syncing as OAuth user
      final needsRemoteFetch = localUser == null ||
          localUser.id.toLowerCase() != userId.toLowerCase();

      if (needsRemoteFetch) {
        _logger.info(
          'Local user profile missing or mismatched - fetching from Supabase',
          context: 'USER_SYNC',
          data: {
            'userId': userId,
            'localUserId': localUser?.id,
            'reason': localUser == null ? 'no_local_profile' : 'user_id_mismatch',
          },
        );

        final remoteUser = await _supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        if (remoteUser != null) {
          _logger.info(
            'Found remote user profile - saving locally',
            context: 'USER_SYNC',
            data: {'userId': userId},
          );

          // Save the remote profile to local database
          await _saveRemoteUserProfile(remoteUser, userId);

          // Re-fetch the local user after saving
          localUser = await _database.getCurrentUserProfile();
        } else {
          _logger.info(
            'No remote user profile found - user may need to complete onboarding',
            context: 'USER_SYNC',
            data: {'userId': userId},
          );
          return; // No profile anywhere - user needs to onboard
        }
      }

      // At this point localUser should not be null
      if (localUser == null) {
        _logger.warning(
          'Failed to establish user profile after fetch attempt',
          context: 'USER_SYNC',
          data: {'userId': userId},
        );
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

  /// Save a remote user profile to the local Drift database
  /// Used when logging into a new device with an existing account
  Future<void> _saveRemoteUserProfile(
    Map<String, dynamic> remoteUser,
    String userId,
  ) async {
    try {
      // Parse the remote user data and save to local database
      // Map Supabase column names to Drift schema
      // Note: UserProfilesTableCompanion.insert requires id and deviceId as String (not Value)
      // All other fields are optional and use Value<T>
      // Note: cycling_ftp_watts and swimming_css_seconds_per_100m are in Supabase but not in local Drift schema
      // CRITICAL: Set isAnonymous to false for OAuth users (default is true)
      final companion = UserProfilesTableCompanion.insert(
        id: userId,
        deviceId: userId, // In unified auth, deviceId == userId
        isAnonymous: const Value(false), // OAuth user = not anonymous
        authProvider: const Value('google'), // OAuth provider
        gender: Value(_parseGenderString(remoteUser['gender'] as String?)),
        birthday: Value(DateTime.tryParse(remoteUser['birthday'] as String? ?? '') ??
            DateTime(1990, 1, 1)),
        heightFeet: Value(remoteUser['height_feet'] as int? ?? 5),
        heightInches: Value(remoteUser['height_inches'] as int? ?? 8),
        weightPounds: Value((remoteUser['weight_pounds'] as num?)?.toDouble() ?? 150.0),
        runsWithWaterBottle: Value(remoteUser['runs_with_water_bottle'] as bool? ?? true),
        gutTrainingLevel: Value(_parseGutTrainingString(remoteUser['gut_training_level'] as String?)),
        onboardingCompleted: Value(remoteUser['onboarding_completed'] as bool? ?? false),
        appVersion: Value(remoteUser['app_version'] as String?),
        createdAt: Value(DateTime.tryParse(remoteUser['created_at'] as String? ?? '') ??
            DateTime.now()),
        updatedAt: Value(DateTime.tryParse(remoteUser['updated_at'] as String? ?? '') ??
            DateTime.now()),
      );

      await _database
          .into(_database.userProfilesTable)
          .insert(companion, mode: InsertMode.insertOrReplace);

      _logger.info(
        'Successfully saved remote user profile to local database',
        context: 'USER_SYNC',
        data: {'userId': userId},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to save remote user profile locally',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Parse gender string to string value for database
  String _parseGenderString(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      default:
        return 'male'; // Default
    }
  }

  /// Parse gut training string to string value for database
  /// Note: GutTraining enum has: low, moderate, high (no 'none')
  String _parseGutTrainingString(String? level) {
    switch (level?.toLowerCase()) {
      case 'none':
        return 'low'; // Map 'none' to 'low' since enum doesn't have 'none'
      case 'low':
        return 'low';
      case 'moderate':
        return 'moderate';
      case 'high':
        return 'high';
      default:
        return 'moderate'; // Default
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
        _logger.info(
          'Syncing ${activities.length} activities from edge function',
          context: 'EDGE_SYNC',
        );
        for (final activityData in activities) {
          await _upsertActivity(activityData as Map<String, dynamic>);
        }
      }

      // Sync events
      final events = data['events'] as List<dynamic>?;
      if (events != null) {
        _logger.info(
          'Syncing ${events.length} events from edge function',
          context: 'EDGE_SYNC',
        );
        for (final eventData in events) {
          final eventMap = eventData as Map<String, dynamic>;
          await _upsertEvent(eventMap, eventMap['user_id'] as String);
        }
      }

      // Sync carb loading plans
      final carbLoadingPlans = data['carb_loading_plans'] as List<dynamic>?;
      if (carbLoadingPlans != null) {
        _logger.info(
          'Syncing ${carbLoadingPlans.length} carb loading plans from edge function',
          context: 'EDGE_SYNC',
        );
        for (final planData in carbLoadingPlans) {
          await _upsertCarbLoadingPlan(planData as Map<String, dynamic>);
        }
      }

      // Sync carb loading days
      final carbLoadingDays = data['carb_loading_days'] as List<dynamic>?;
      if (carbLoadingDays != null) {
        _logger.info(
          'Syncing ${carbLoadingDays.length} carb loading days from edge function',
          context: 'EDGE_SYNC',
        );
        for (final dayData in carbLoadingDays) {
          await _upsertCarbLoadingDay(dayData as Map<String, dynamic>);
        }
      }

      // Sync food preferences
      final foodPreferences = data['food_preferences'] as List<dynamic>?;
      if (foodPreferences != null && foodPreferences.isNotEmpty) {
        _logger.info(
          'Syncing ${foodPreferences.length} food preferences from edge function',
          context: 'EDGE_SYNC',
        );
        await _syncFoodPreferencesFromEdgeFunction(foodPreferences);
      }

      _logger.info(
        'Edge function data sync to local DB completed',
        context: 'EDGE_SYNC',
        data: {
          'activities': activities?.length ?? 0,
          'events': events?.length ?? 0,
          'carbLoadingPlans': carbLoadingPlans?.length ?? 0,
          'carbLoadingDays': carbLoadingDays?.length ?? 0,
          'foodPreferences': foodPreferences?.length ?? 0,
        },
      );
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
      final userId = data['user_id'] as String;

      _logger.info(
        '💾 UPSERTING activity from sync',
        context: 'DATA_SYNC',
        data: {
          'activityId': activityId,
          'userId': userId,
          'title': data['title'],
        },
      );

      final existingActivity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      // CRITICAL: Preserve local data if it has pending changes (needsUpload = true)
      // Phone data is the source of truth - never overwrite local changes
      if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
        _logger.info(
          '⏭️ Skipping activity upsert - has pending local changes',
          context: 'DATA_SYNC',
          data: {'activityId': activityId},
        );
        return; // Keep local version with pending changes
      }

      if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
        final companion = ActivitiesTableCompanion.insert(
          id: Value(activityId),
          userId: userId,
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

        _logger.info(
          '✅ Activity upserted successfully',
          context: 'DATA_SYNC',
          data: {
            'activityId': activityId,
            'userId': userId,
          },
        );
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

  /// Sync food preferences from edge function response
  /// Uses merge mode to preserve local preferences not in server response
  Future<void> _syncFoodPreferencesFromEdgeFunction(List<dynamic> foodPreferences) async {
    try {
      if (foodPreferences.isEmpty) {
        _logger.info(
          'No food preferences to sync from edge function',
          context: 'FOOD_PREF_SYNC',
        );
        return;
      }

      // Extract user_id from first preference (all should have same user_id)
      final firstPref = foodPreferences.first as Map<String, dynamic>;
      final userId = firstPref['user_id'] as String?;
      if (userId == null) {
        _logger.warning(
          'Food preferences missing user_id, skipping sync',
          context: 'FOOD_PREF_SYNC',
        );
        return;
      }

      // Convert to preference maps
      final preferences = <String, FoodPreference>{};
      final sliderLevels = <String, int>{};

      for (final prefData in foodPreferences) {
        final data = prefData as Map<String, dynamic>;
        final foodName = data['food_name'] as String?;
        final preferenceValue = data['preference'] as String?;
        final preferenceLevel = data['preference_level'] as int?;

        if (foodName == null || preferenceValue == null) continue;

        // Parse preference enum
        final preference = FoodPreference.values.firstWhere(
          (p) => p.value == preferenceValue,
          orElse: () => FoodPreference.willingToTry,
        );

        preferences[foodName] = preference;
        if (preferenceLevel != null) {
          sliderLevels[foodName] = preferenceLevel.clamp(0, 4);
        }
      }

      // SAFETY CHECK: Don't wipe local data if server returned empty
      if (preferences.isEmpty) {
        final localPrefs = await _database.getUserFoodPreferences(userId);
        if (localPrefs.isNotEmpty) {
          _logger.warning(
            'Server returned empty food_preferences but local has ${localPrefs.length} items - keeping local data',
            context: 'FOOD_PREF_SYNC',
          );
          return;
        }
      }

      // Use merge mode to preserve local preferences not in server response
      await _database.saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels.isEmpty ? null : sliderLevels,
        mergeMode: true,
      );

      _logger.info(
        'Synced ${preferences.length} food preferences from edge function',
        context: 'FOOD_PREF_SYNC',
        data: {'userId': userId, 'count': preferences.length},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync food preferences from edge function',
        context: 'FOOD_PREF_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// Upload dirty records to Supabase (upload-first pattern)
  ///
  /// Returns map of table -> upload success for monitoring/retry logic
  /// This is the first step in the sync process (upload then download)
  Future<Map<String, bool>> uploadDirtyRecords(String userId) async {
    final uploadResults = <String, bool>{};

    try {
      await _database.ensureUserDataSyncColumns();

      _logger.info(
        'Starting upload of dirty records via edge function',
        context: 'DATA_SYNC',
        data: {'userId': userId},
      );

      // Collect dirty records from all tables
      final dirtyUserProfile = await (_database.select(_database.userProfilesTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .getSingleOrNull();

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

      // User foods use raw queries
      List<QueryRow> dirtyUserFoods = const [];
      try {
        dirtyUserFoods = await _database
            .customSelect('SELECT * FROM user_foods WHERE needs_upload = 1')
            .get();
      } catch (e) {
        // Table might not exist yet
      }

      final dirtyFeedback = await _database
          .customSelect('SELECT * FROM feedback WHERE needs_upload = 1')
          .get();

      final dirtyFeatureSurvey = await _database
          .customSelect('SELECT * FROM feature_survey_responses WHERE needs_upload = 1')
          .get();

      // If nothing to upload, return early
      if (dirtyUserProfile == null &&
          dirtyActivities.isEmpty &&
          dirtyEvents.isEmpty &&
          dirtyCarbLoadingPlans.isEmpty &&
          dirtyCarbLoadingDays.isEmpty &&
          dirtyUserFoods.isEmpty &&
          dirtyFeedback.isEmpty &&
          dirtyFeatureSurvey.isEmpty) {
        _logger.info('No dirty records to upload', context: 'DATA_SYNC');
        return uploadResults;
      }

      // Build request payload
      final dirtyRecords = <String, dynamic>{};

      if (dirtyActivities.isNotEmpty) {
        dirtyRecords['activities'] = dirtyActivities.map((a) => _activityToJson(a)).toList();
      }

      if (dirtyEvents.isNotEmpty) {
        dirtyRecords['events'] = dirtyEvents.map((e) => _eventToJson(e)).toList();
      }

      if (dirtyCarbLoadingPlans.isNotEmpty) {
        dirtyRecords['carb_loading_plans'] = dirtyCarbLoadingPlans.map((p) => _carbLoadingPlanToJson(p)).toList();
      }

      if (dirtyCarbLoadingDays.isNotEmpty) {
        dirtyRecords['carb_loading_days'] = dirtyCarbLoadingDays.map((d) => _carbLoadingDayToJson(d)).toList();
      }

      if (dirtyUserFoods.isNotEmpty) {
        dirtyRecords['user_foods'] = dirtyUserFoods.map((row) => row.data).toList();
      }

      if (dirtyFeedback.isNotEmpty) {
        dirtyRecords['feedback'] = dirtyFeedback.map((row) => row.data).toList();
      }

      if (dirtyFeatureSurvey.isNotEmpty) {
        dirtyRecords['feature_survey_responses'] = dirtyFeatureSurvey.map((row) => row.data).toList();
      }

      // Call upload-all-data edge function
      _logger.info(
        'Calling upload-all-data edge function',
        context: 'DATA_SYNC',
        data: {
          'userId': userId,
          'tableCount': dirtyRecords.keys.length,
        },
      );

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
          // Clear needs_upload flag for this table
          await _clearNeedsUploadFlag(tableName, userId);

          _logger.info(
            'Successfully uploaded $tableName',
            context: 'DATA_SYNC',
            data: {'uploaded': result['uploaded']},
          );
        } else {
          _logger.warning(
            'Failed to upload $tableName',
            context: 'DATA_SYNC',
            data: {'error': result['error']},
          );
        }
      }

      // Upload user profile separately if needed (uses different endpoint)
      if (dirtyUserProfile != null) {
        try {
          await _uploadUserProfile(dirtyUserProfile);
          uploadResults['users'] = true;
        } catch (e) {
          _logger.error('Failed to upload user profile', context: 'DATA_SYNC', error: e);
          uploadResults['users'] = false;
        }
      }

      _logger.info(
        'Upload completed via edge function',
        context: 'DATA_SYNC',
        data: {
          'userId': userId,
          'successful': uploadResults.values.where((v) => v).length,
          'failed': uploadResults.values.where((v) => !v).length,
        },
      );

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

  /// Clear needs_upload flag for successfully uploaded records
  Future<void> _clearNeedsUploadFlag(String tableName, String userId) async {
    try {
      switch (tableName) {
        case 'activities':
          await _database.customStatement(
            'UPDATE activities_table SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'events':
          await _database.customStatement(
            'UPDATE events_table SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'carb_loading_plans':
          await _database.customStatement(
            'UPDATE carb_loading_plans_table SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
            [userId],
          );
          break;
        case 'carb_loading_days':
          await _database.customStatement(
            '''UPDATE carb_loading_days_table
               SET needs_upload = 0
               WHERE carb_loading_plan_id IN (
                 SELECT id FROM carb_loading_plans_table WHERE user_id = ?
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
        case 'feature_survey_responses':
          await _database.customStatement(
            'UPDATE feature_survey_responses SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
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

  /// DEPRECATED: Use uploadDirtyRecords() for upload-first pattern
  Future<void> _uploadDirtyRecords(String userId) async {
    await uploadDirtyRecords(userId);
  }

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
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

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
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

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
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

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
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

  /// Convert Activity to JSON for edge function
  Map<String, dynamic> _activityToJson(Activity activity) {
    return {
      'id': activity.id,
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
      'cycling_speed_mph': activity.cyclingSpeedMph,
      'cycling_terrain': activity.cyclingTerrain,
      'cycling_indoor_outdoor': activity.cyclingIndoorOutdoor,
      'cycling_elevation_gain_ft': activity.cyclingElevationGainFt,
      'cycling_session_goal': activity.cyclingSessionGoal,
      'swimming_pace_per_100m_seconds': activity.swimmingPacePer100mSeconds,
      'swimming_pool_or_open_water': activity.swimmingPoolOrOpenWater,
      'swimming_water_temp_c': activity.swimmingWaterTempC,
      'completed_at': activity.completedAt?.toIso8601String(),
      'actual_distance_miles': activity.actualDistanceMiles,
      'actual_duration_minutes': activity.actualDurationMinutes,
      'completion_rating': activity.completionRating,
      'completion_notes': activity.completionNotes,
      'nutrition_plan_data': activity.nutritionPlanData,
      'created_at': activity.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convert Event to JSON for edge function
  Map<String, dynamic> _eventToJson(Event event) {
    return {
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
      'created_at': event.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convert CarbLoadingPlan to JSON for edge function
  Map<String, dynamic> _carbLoadingPlanToJson(CarbLoadingPlan plan) {
    return {
      'id': plan.id,
      'user_id': plan.userId,
      'event_id': plan.eventId,
      'start_date': plan.startDate.toIso8601String(),
      'end_date': plan.endDate.toIso8601String(),
      'total_days': plan.totalDays,
      'daily_carb_target_grams': plan.dailyCarbTargetGrams,
      'daily_calorie_target': plan.dailyCalorieTarget,
      'generated_at': plan.generatedAt.toIso8601String(),
      'algorithm_version': plan.algorithmVersion,
      'adherence_score': plan.adherenceScore,
      'completed_at': plan.completedAt?.toIso8601String(),
      'local_updated_at': plan.localUpdatedAt.toIso8601String(),
    };
  }

  /// Convert CarbLoadingDay to JSON for edge function
  Map<String, dynamic> _carbLoadingDayToJson(CarbLoadingDay day) {
    return {
      'id': day.id,
      'carb_loading_plan_id': day.carbLoadingPlanId,
      'day_number': day.dayNumber,
      'plan_date': day.planDate.toIso8601String(),
      'carb_target_grams': day.carbTargetGrams,
      'carb_protocol_g_per_kg': day.carbProtocolGPerKg,
      'calorie_target': day.calorieTarget,
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
  }

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
  Future<void> _uploadUserFoodRow(Map<String, dynamic> row) async {
    try {
      final categories = _parsePgArray(row['categories'] as String?);
      final activityTypes = _parsePgArray(row['activity_types'] as String?);
      final productType = normalizeProductType(
        row['product_type'] ?? row['product_type_id'],
        logger: _logger,
      );

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
        'product_type': productType,
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

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
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

  /// DEPRECATED: Individual uploads replaced by upload-all-data edge function
  /// Kept for reference only - not called in production code
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

  /// Upload user profile to Supabase (for new user registration)
  /// Uses consolidated upsert-user-profile edge function
  Future<void> _uploadUserProfile(UserProfileEntry profile) async {
    try {
      _logger.info(
        'Uploading user profile to Supabase',
        context: 'USER_SYNC',
        data: {'userId': profile.id},
      );

      // Use Supabase direct upsert instead of edge function for simplicity
      // Edge function can be used later if needed for additional business logic
      final userData = {
        'id': profile.id,
        'device_id': profile.deviceId,
        'auth_user_id': profile.authUserId,
        'auth_provider': profile.authProvider,
        'is_anonymous': profile.isAnonymous,
        'gender': profile.gender,
        'birthday': profile.birthday?.toIso8601String().split('T')[0],
        'height_feet': profile.heightFeet,
        'height_inches': profile.heightInches,
        'weight_pounds': profile.weightPounds,
        'runs_with_water_bottle': profile.runsWithWaterBottle,
        'food_preferences': profile.foodPreferences, // CRITICAL: Sync food preferences to Supabase
        'gut_training_level': profile.gutTrainingLevel,
        'onboarding_completed': profile.onboardingCompleted,
        'app_version': profile.appVersion,
        'dietary_preference': profile.dietaryPreference,
        'allergies': profile.allergies,
        'created_at': profile.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert to Supabase
      await _supabase.from('users').upsert(
        userData,
        onConflict: 'id', // Use id as primary key for conflict resolution
      );

      // Mark as synced in local database
      await (_database.update(_database.userProfilesTable)
            ..where((tbl) => tbl.id.equals(profile.id)))
          .write(const UserProfilesTableCompanion(needsUpload: Value(false)));

      _logger.info(
        'User profile uploaded successfully',
        context: 'USER_SYNC',
        data: {'userId': profile.id},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload user profile',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': profile.id},
      );
      // Don't rethrow - allow other uploads to continue
    }
  }

  List<String>? _parsePgArray(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.replaceAll('{', '').replaceAll('}', '');
    if (trimmed.trim().isEmpty) return <String>[];
    return trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Detect if this is a fresh device (needs full sync)
  ///
  /// Checks:
  /// 1. User profile exists in local DB
  /// 2. Last sync timestamp exists
  /// 3. Sync is not too old (>30 days = treat as fresh)
  ///
  /// Returns true if full sync is needed, false otherwise
  Future<bool> needsFullSync(String userId) async {
    try {
      // Check 1: User profile exists?
      final profileCount = await (_database.select(_database.userProfilesTable)
            ..where((t) => t.id.equals(userId)))
          .get();

      if (profileCount.isEmpty) {
        _logger.info(
          'Fresh device detected - no user profile',
          context: 'DATA_SYNC',
        );
        return true;
      }

      // Check 2: Have we ever synced?
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      final lastSync = prefs.getString('last_sync_timestamp_$userId');

      if (lastSync == null) {
        _logger.info(
          'Fresh device detected - no sync timestamp',
          context: 'DATA_SYNC',
        );
        return true;
      }

      // Check 3: Is sync very old? (>30 days = treat as fresh)
      final lastSyncDate = DateTime.tryParse(lastSync);
      if (lastSyncDate == null) {
        _logger.info(
          'Fresh device detected - invalid sync timestamp',
          context: 'DATA_SYNC',
        );
        return true;
      }

      final daysSinceSync = DateTime.now().difference(lastSyncDate).inDays;

      if (daysSinceSync > 30) {
        _logger.info(
          'Sync very old ($daysSinceSync days) - treating as fresh device',
          context: 'DATA_SYNC',
        );
        return true;
      }

      _logger.info(
        'Device has recent data - incremental sync',
        context: 'DATA_SYNC',
        data: {'daysSinceSync': daysSinceSync},
      );
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
}
