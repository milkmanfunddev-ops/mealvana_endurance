import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';

part 'calendar_sync_service.g.dart';

@riverpod
CalendarSyncService calendarSyncService(Ref ref) {
  return CalendarSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Service responsible for downloading calendar data from Supabase on app startup
/// Implements timestamp-based conflict resolution (Supabase is source of truth)
/// Respects soft deletes and handles errors gracefully (non-blocking)
class CalendarSyncService {
  const CalendarSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Sync all calendar tables from Supabase to local database
  /// Downloads data in dependency order: activities → events → plans → days → completions
  Future<void> syncCalendarTables(String userId) async {
    try {
      // Sync in dependency order
      await _syncActivities(userId);
      await _syncEvents(userId);
      await _syncCarbLoadingPlans(userId);
      await _syncCarbLoadingDays(userId);
      await _syncActivityCompletions(userId);
    } catch (e, stackTrace) {
      _logger.error(
        'Calendar data sync failed',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if sync fails
    }
  }

  /// Sync activities from Supabase (excludes soft-deleted records)
  Future<void> _syncActivities(String userId) async {
    try {
      // Fetch activities from Supabase (excluding soft-deleted)
      final response = await _supabase
          .from('activities')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('scheduled_date_time', ascending: false);

      final activities = response as List<dynamic>;

      // Batch insert/update activities
      for (final activityData in activities) {
        await _upsertActivity(activityData as Map<String, dynamic>);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync activities',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upsert a single activity with timestamp-based conflict resolution
  Future<void> _upsertActivity(Map<String, dynamic> data) async {
    try {
      final activityId = data['id'] as String;

      // Check if activity exists locally
      final existingActivity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .getSingleOrNull();

      // Parse timestamps
      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      // Determine if we should update (Supabase wins if newer or if local doesn't exist)
      if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
        final companion = ActivitiesTableCompanion.insert(
          id: data['id'] as String,
          userId: data['user_id'] as String,
          activityType: data['activity_type'] as String,
          title: data['title'] as String,
          scheduledDateTime: DateTime.parse(data['scheduled_date_time'] as String),
          status: Value(data['status'] as String? ?? 'planned'),
          distanceMiles: Value(data['distance_miles'] as double?),
          durationMinutes: Value(data['duration_minutes'] as int?),
          paceTargetMinutesPerMile: Value(data['pace_target_minutes_per_mile'] as double?),
          intensityLevel: Value(data['intensity_level'] as String?),
          // Cycling fields
          cyclingSpeedMph: Value(data['cycling_speed_mph'] as double?),
          cyclingTerrain: Value(data['cycling_terrain'] as String?),
          cyclingIndoorOutdoor: Value(data['cycling_indoor_outdoor'] as String?),
          cyclingElevationGainFt: Value(data['cycling_elevation_gain_ft'] as int?),
          cyclingSessionGoal: Value(data['cycling_session_goal'] as String?),
          // Swimming fields
          swimmingPacePer100mSeconds: Value(data['swimming_pace_per_100m_seconds'] as int?),
          swimmingPoolOrOpenWater: Value(data['swimming_pool_or_open_water'] as String?),
          swimmingWaterTempC: Value(data['swimming_water_temp_c'] as double?),
          // Shared fields
          intensityTarget: Value(data['intensity_target'] as String?),
          timeBeforeMinutes: Value(data['time_before_minutes'] as int?),
          // Completion fields
          completedAt: Value(data['completed_at'] != null
              ? DateTime.parse(data['completed_at'] as String)
              : null),
          completionRating: Value(data['completion_rating'] as int?),
          completionNotes: Value(data['completion_notes'] as String?),
          actualDistanceMiles: Value(data['actual_distance_miles'] as double?),
          actualDurationMinutes: Value(data['actual_duration_minutes'] as int?),
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
      // Continue with other activities
    }
  }

  /// Sync events from Supabase
  Future<void> _syncEvents(String userId) async {
    try {
      // Fetch events from Supabase
      // Note: Events don't have user_id directly, we join with activities
      // For simplicity, fetch all events and filter by activity ownership later
      // Or we can use a join query with activities table

      final response = await _supabase
          .from('events')
          .select()
          .order('created_at', ascending: false);

      final events = response as List<dynamic>;

      // Batch insert/update events
      for (final eventData in events) {
        await _upsertEvent(eventData as Map<String, dynamic>, userId);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync events',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upsert a single event with timestamp-based conflict resolution
  Future<void> _upsertEvent(Map<String, dynamic> data, String userId) async {
    try {
      final eventId = data['id'] as String;

      // Check if event exists locally
      final existingEvent = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      // Parse timestamps
      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      // Determine if we should update
      if (existingEvent == null || existingEvent.updatedAt.isBefore(supabaseUpdatedAt)) {
        // Verify event ownership via activity (if activity_id exists)
        if (data['activity_id'] != null) {
          final activity = await (_database.select(_database.activitiesTable)
                ..where((tbl) => tbl.id.equals(data['activity_id'] as String)))
              .getSingleOrNull();

          // Skip if activity doesn't belong to this user
          if (activity != null && activity.userId != userId) {
            return;
          }
        }

        final companion = EventsTableCompanion.insert(
          id: data['id'] as String,
          userId: userId,
          activityId: Value(data['activity_id'] as String?),
          eventType: data['event_type'] as String,
          eventSubtype: Value(data['event_subtype'] as String?),
          eventName: Value(data['event_name'] as String?),
          location: Value(data['location'] as String?),
          registrationUrl: Value(data['registration_url'] as String?),
          startTime: Value(data['start_time'] as String?),
          goalTimeMinutes: Value(data['goal_time_minutes'] as int?),
          goalPaceMinutesPerMile: Value(data['goal_pace_minutes_per_mile'] as double?),
          predictedFinishTimeMinutes: Value(data['predicted_finish_time_minutes'] as int?),
          hasCarbLoading: Value(data['has_carb_loading'] as bool? ?? false),
          carbLoadingDays: Value(data['carb_loading_days'] as int?),
          carbLoadingStartDate: Value(data['carb_loading_start_date'] != null
              ? DateTime.parse(data['carb_loading_start_date'] as String)
              : null),
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
      // Continue with other events
    }
  }

  /// Sync carb loading plans from Supabase
  Future<void> _syncCarbLoadingPlans(String userId) async {
    try {
      final response = await _supabase
          .from('carb_loading_plans')
          .select()
          .eq('user_id', userId)
          .order('generated_at', ascending: false);

      final plans = response as List<dynamic>;

      for (final planData in plans) {
        await _upsertCarbLoadingPlan(planData as Map<String, dynamic>);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync carb loading plans',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upsert a single carb loading plan
  Future<void> _upsertCarbLoadingPlan(Map<String, dynamic> data) async {
    try {
      final planId = data['id'] as String;

      final companion = CarbLoadingPlansTableCompanion.insert(
        id: planId,
        eventId: Value(data['event_id'] as String?),
        userId: data['user_id'] as String,
        totalDays: data['total_days'] as int,
        startDate: DateTime.parse(data['start_date'] as String),
        endDate: DateTime.parse(data['end_date'] as String),
        dailyCarbTargetGrams: data['daily_carb_target_grams'] as int,
        generatedAt: DateTime.parse(data['generated_at'] as String),
      );

      await _database
          .into(_database.carbLoadingPlansTable)
          .insert(companion, mode: InsertMode.insertOrReplace);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert carb loading plan',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'planId': data['id']},
      );
      // Continue with other plans
    }
  }

  /// Sync carb loading days from Supabase
  Future<void> _syncCarbLoadingDays(String userId) async {
    try {
      // Fetch days by joining with plans (to filter by user_id)
      final response = await _supabase
          .from('carb_loading_days')
          .select('''
            *,
            carb_loading_plans!inner(user_id)
          ''')
          .eq('carb_loading_plans.user_id', userId)
          .order('plan_date', ascending: true);

      final days = response as List<dynamic>;

      for (final dayData in days) {
        await _upsertCarbLoadingDay(dayData as Map<String, dynamic>);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync carb loading days',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upsert a single carb loading day
  Future<void> _upsertCarbLoadingDay(Map<String, dynamic> data) async {
    try {
      final dayId = data['id'] as String;

      final companion = CarbLoadingDaysTableCompanion.insert(
        id: dayId,
        carbLoadingPlanId: data['carb_loading_plan_id'] as String,
        planDate: DateTime.parse(data['plan_date'] as String),
        dayNumber: data['day_number'] as int,
        carbTargetGrams: data['carb_target_grams'] as int,
        carbProtocolGPerKg: data['carb_protocol_g_per_kg'] as double? ?? 8.0,
        breakfastPercent: Value(data['breakfast_percent'] as double? ?? 0.25),
        morningSnackPercent: Value(data['morning_snack_percent'] as double? ?? 0.10),
        lunchPercent: Value(data['lunch_percent'] as double? ?? 0.25),
        afternoonSnackPercent: Value(data['afternoon_snack_percent'] as double? ?? 0.15),
        dinnerPercent: Value(data['dinner_percent'] as double? ?? 0.20),
        eveningSnackPercent: Value(data['evening_snack_percent'] as double? ?? 0.05),
        completed: Value(data['completed'] as bool? ?? false),
        loggedCarbsGrams: Value(data['logged_carbs_grams'] as int),
        loggedCalories: Value(data['logged_calories'] as int),
      );

      await _database
          .into(_database.carbLoadingDaysTable)
          .insert(companion, mode: InsertMode.insertOrReplace);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert carb loading day',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'dayId': data['id']},
      );
      // Continue with other days
    }
  }

  /// Sync activity completions from Supabase
  Future<void> _syncActivityCompletions(String userId) async {
    try {
      final response = await _supabase
          .from('activity_completions')
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      final completions = response as List<dynamic>;

      for (final completionData in completions) {
        await _upsertActivityCompletion(completionData as Map<String, dynamic>);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync activity completions',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upsert a single activity completion
  Future<void> _upsertActivityCompletion(Map<String, dynamic> data) async {
    try {
      final completionId = data['id'] as String;

      final companion = ActivityCompletionsTableCompanion.insert(
        id: completionId,
        activityId: data['activity_id'] as String,
        userId: data['user_id'] as String,
        completedAt: DateTime.parse(data['completed_at'] as String),
        completionType: Value(data['completion_type'] as String? ?? 'manual'),
        actualDistanceMiles: Value(data['actual_distance_miles'] as double?),
        actualDurationMinutes: Value(data['actual_duration_minutes'] as int?),
        averagePaceMinutesPerMile: Value(data['average_pace_minutes_per_mile'] as double?),
        maxHeartRate: Value(data['max_heart_rate'] as int?),
        averageHeartRate: Value(data['average_heart_rate'] as int?),
        caloriesBurned: Value(data['calories_burned'] as int?),
        effortRating: Value(data['effort_rating'] as int?),
        nutritionRating: Value(data['nutrition_rating'] as int?),
        overallSatisfaction: Value(data['overall_satisfaction'] as int?),
        textNotes: Value(data['text_notes'] as String?),
        voiceNoteId: Value(data['voice_note_id'] as String?),
        hasVoiceRecording: Value(data['has_voice_recording'] as bool? ?? false),
        weatherConditions: Value(data['weather_conditions'] as String?),
        temperatureFahrenheit: Value(data['temperature_fahrenheit'] as int?),
        humidityPercent: Value(data['humidity_percent'] as int?),
        nutritionAdherenceScore: Value(data['nutrition_adherence_score'] as double?),
        performanceVsTarget: Value(data['performance_vs_target'] as double?),
      );

      await _database
          .into(_database.activityCompletionsTable)
          .insert(companion, mode: InsertMode.insertOrReplace);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert activity completion',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'completionId': data['id']},
      );
      // Continue with other completions
    }
  }

  /// Sync calendar data from pre-downloaded data (single network call pattern)
  /// This method is called by DataSyncService after fetching all data in one call
  Future<void> syncFromDownloadedData({
    required List<dynamic> activities,
    required List<dynamic> events,
    required List<dynamic> carbLoadingPlans,
    required List<dynamic> carbLoadingDays,
    required List<dynamic> activityCompletions,
  }) async {
    try {
      // Sync in dependency order
      for (final activityData in activities) {
        await _upsertActivity(activityData as Map<String, dynamic>);
      }

      for (final eventData in events) {
        final eventMap = eventData as Map<String, dynamic>;
        final userId = eventMap['user_id'] as String; // Now events have user_id!
        await _upsertEvent(eventMap, userId);
      }

      for (final planData in carbLoadingPlans) {
        await _upsertCarbLoadingPlan(planData as Map<String, dynamic>);
      }

      for (final dayData in carbLoadingDays) {
        await _upsertCarbLoadingDay(dayData as Map<String, dynamic>);
      }

      for (final completionData in activityCompletions) {
        await _upsertActivityCompletion(completionData as Map<String, dynamic>);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Calendar data sync failed',
        context: 'CALENDAR_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
