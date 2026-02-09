import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/logging_service.dart';
import '../../nutrition_plan/domain/intensity_distribution.dart';
import '../domain/activity.dart' as domain;
import '../domain/brick_metadata.dart';

/// Centralized mapping and parsing logic for activities.
///
/// Eliminates duplication between Drift→Domain, JSON→Domain,
/// Domain→Drift, and Domain→Supabase conversions.
class ActivityMapper {
  const ActivityMapper({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  // ========================================================================
  // Core Mapping: Source → Domain
  // ========================================================================

  /// Map a Drift [Activity] row to domain [Activity].
  domain.Activity fromDriftRow(Activity row) {
    return _buildDomainActivity(
      id: row.id,
      userId: row.userId,
      activityType: row.activityType,
      title: row.title,
      scheduledDateTime: row.scheduledDateTime,
      status: row.status,
      distanceMiles: row.distanceMiles,
      durationMinutes: row.durationMinutes,
      paceTargetMinutesPerMile: row.paceTargetMinutesPerMile,
      intensityLevel: row.intensityLevel,
      intensityZ1Z2Pct: row.intensityZ1Z2Pct,
      intensityZ3Z4Pct: row.intensityZ3Z4Pct,
      intensityZ5Pct: row.intensityZ5Pct,
      cyclingSpeedMph: row.cyclingSpeedMph,
      cyclingTerrain: row.cyclingTerrain,
      cyclingIndoorOutdoor: row.cyclingIndoorOutdoor,
      cyclingElevationGainFt: row.cyclingElevationGainFt,
      cyclingSessionGoal: row.cyclingSessionGoal,
      swimmingPacePer100mSeconds: row.swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: row.swimmingPoolOrOpenWater,
      swimmingWaterTempC: row.swimmingWaterTempC,
      intensityTarget: row.intensityTarget,
      timeBeforeMinutes: row.timeBeforeMinutes,
      completedAt: row.completedAt,
      completionRating: row.completionRating,
      completionNotes: row.completionNotes,
      actualDistanceMiles: row.actualDistanceMiles,
      actualDurationMinutes: row.actualDurationMinutes,
      nutritionPlanDataRaw: row.nutritionPlanData,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      reminderEnabled: row.reminderEnabled,
      reminderDaysBefore: row.reminderDaysBefore,
      reminderTimeOfDay: row.reminderTimeOfDay,
      reminderRecurring: row.reminderRecurring,
      brickMetadataRaw: row.brickMetadata,
      brickId: row.brickId,
      needsUpload: row.needsUpload ?? false,
      localUpdatedAt: row.localUpdatedAt,
      syncedFromProvider: row.syncedFromProvider,
      providerWorkoutId: row.providerWorkoutId,
      providerWorkoutUrl: row.providerWorkoutUrl,
      lastSyncedAt: row.lastSyncedAt,
      workoutSubtype: row.workoutSubtype,
      paceMinMinutesPerMile: row.paceMinMinutesPerMile,
      paceMaxMinutesPerMile: row.paceMaxMinutesPerMile,
      needsNutritionRefresh: row.needsNutritionRefresh,
      providerDeletedAt: row.providerDeletedAt,
      providerScheduledAt: row.providerScheduledAt,
      scheduleChangedAt: row.scheduleChangedAt,
    );
  }

  /// Map a Supabase JSON map to domain [Activity].
  domain.Activity fromJson(Map<String, dynamic> json) {
    return _buildDomainActivity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      activityType: json['activity_type'] as String,
      title: json['title'] as String,
      scheduledDateTime: DateTime.parse(json['scheduled_date_time'] as String),
      status: json['status'],
      distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      paceTargetMinutesPerMile:
          (json['pace_target_minutes_per_mile'] as num?)?.toDouble(),
      intensityLevel: json['intensity_level'] as String?,
      intensityZ1Z2Pct: (json['intensity_z1_z2_pct'] as num?)?.toInt(),
      intensityZ3Z4Pct: (json['intensity_z3_z4_pct'] as num?)?.toInt(),
      intensityZ5Pct: (json['intensity_z5_pct'] as num?)?.toInt(),
      cyclingSpeedMph: (json['cycling_speed_mph'] as num?)?.toDouble(),
      cyclingTerrain: json['cycling_terrain'] as String?,
      cyclingIndoorOutdoor: json['cycling_indoor_outdoor'] as String?,
      cyclingElevationGainFt:
          (json['cycling_elevation_gain_ft'] as num?)?.toInt(),
      cyclingSessionGoal: json['cycling_session_goal'] as String?,
      swimmingPacePer100mSeconds:
          (json['swimming_pace_per_100m_seconds'] as num?)?.toInt(),
      swimmingPoolOrOpenWater: json['swimming_pool_or_open_water'] as String?,
      swimmingWaterTempC: (json['swimming_water_temp_c'] as num?)?.toDouble(),
      intensityTarget: json['intensity_target'] as String?,
      timeBeforeMinutes: (json['time_before_minutes'] as num?)?.toInt(),
      completedAt: parseDateTime(json['completed_at']),
      completionRating: (json['completion_rating'] as num?)?.toInt(),
      completionNotes: json['completion_notes'] as String?,
      actualDistanceMiles:
          (json['actual_distance_miles'] as num?)?.toDouble(),
      actualDurationMinutes:
          (json['actual_duration_minutes'] as num?)?.toInt(),
      nutritionPlanDataRaw: json['nutrition_plan_data'],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: parseDateTime(json['deleted_at']),
      reminderEnabled: false,
      brickMetadataRaw: json['brick_metadata'],
      brickId: json['brick_id'] as String?,
      needsUpload: false,
      localUpdatedAt: DateTime.now(),
      syncedFromProvider: json['synced_from_provider'] as String?,
      providerWorkoutId: json['provider_workout_id'] as String?,
      providerWorkoutUrl: json['provider_workout_url'] as String?,
      lastSyncedAt: parseDateTime(json['last_synced_at']),
      workoutSubtype: json['workout_subtype'] as String?,
      paceMinMinutesPerMile:
          (json['pace_min_minutes_per_mile'] as num?)?.toDouble(),
      paceMaxMinutesPerMile:
          (json['pace_max_minutes_per_mile'] as num?)?.toDouble(),
      needsNutritionRefresh:
          (json['needs_nutrition_refresh'] as bool?) ?? false,
      providerDeletedAt: parseDateTime(json['provider_deleted_at']),
      providerScheduledAt: parseDateTime(json['provider_scheduled_at']),
      scheduleChangedAt: parseDateTime(json['schedule_changed_at']),
    );
  }

  /// Shared builder called by both [fromDriftRow] and [fromJson].
  ///
  /// All raw values are pre-extracted by the caller; this method handles
  /// parsing enums, JSON blobs, and constructing the domain model.
  domain.Activity _buildDomainActivity({
    required String id,
    required String userId,
    required String activityType,
    required String title,
    required DateTime scheduledDateTime,
    required dynamic status,
    required double? distanceMiles,
    required int? durationMinutes,
    required double? paceTargetMinutesPerMile,
    required String? intensityLevel,
    required int? intensityZ1Z2Pct,
    required int? intensityZ3Z4Pct,
    required int? intensityZ5Pct,
    required double? cyclingSpeedMph,
    required String? cyclingTerrain,
    required String? cyclingIndoorOutdoor,
    required int? cyclingElevationGainFt,
    required String? cyclingSessionGoal,
    required int? swimmingPacePer100mSeconds,
    required String? swimmingPoolOrOpenWater,
    required double? swimmingWaterTempC,
    required String? intensityTarget,
    required int? timeBeforeMinutes,
    required DateTime? completedAt,
    required int? completionRating,
    required String? completionNotes,
    required double? actualDistanceMiles,
    required int? actualDurationMinutes,
    required dynamic nutritionPlanDataRaw,
    required String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required bool reminderEnabled,
    int? reminderDaysBefore,
    String? reminderTimeOfDay,
    bool? reminderRecurring,
    required dynamic brickMetadataRaw,
    required String? brickId,
    required bool needsUpload,
    required DateTime? localUpdatedAt,
    required String? syncedFromProvider,
    required String? providerWorkoutId,
    required String? providerWorkoutUrl,
    required DateTime? lastSyncedAt,
    required String? workoutSubtype,
    required double? paceMinMinutesPerMile,
    required double? paceMaxMinutesPerMile,
    required bool needsNutritionRefresh,
    required DateTime? providerDeletedAt,
    required DateTime? providerScheduledAt,
    required DateTime? scheduleChangedAt,
  }) {
    // Parse intensity distribution
    IntensityDistribution? intensityDistribution;
    if (intensityZ1Z2Pct != null &&
        intensityZ3Z4Pct != null &&
        intensityZ5Pct != null) {
      try {
        intensityDistribution = IntensityDistribution(
          conversationalPct: intensityZ1Z2Pct,
          tempoPct: intensityZ3Z4Pct,
          allOutPct: intensityZ5Pct,
        );
      } catch (e) {
        _logger.warning(
          'Failed to parse intensity distribution',
          context: 'ACTIVITY_MAPPER',
          error: e,
          data: {
            'activityId': id,
            'z1z2': intensityZ1Z2Pct,
            'z3z4': intensityZ3Z4Pct,
            'z5': intensityZ5Pct,
          },
        );
      }
    }

    return domain.Activity(
      id: id,
      userId: userId,
      activityType: ActivityType.fromDbValue(activityType),
      title: title,
      scheduledDateTime: scheduledDateTime,
      status: parseActivityStatus(status),
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      paceTargetMinutesPerMile: paceTargetMinutesPerMile,
      intensityLevel: intensityLevel != null
          ? domain.IntensityLevel.values.firstWhere(
              (level) => level.name == intensityLevel,
              orElse: () => domain.IntensityLevel.moderate,
            )
          : null,
      intensityDistribution: intensityDistribution,
      cyclingSpeedMph: cyclingSpeedMph,
      cyclingTerrain: cyclingTerrain,
      cyclingIndoorOutdoor: cyclingIndoorOutdoor,
      cyclingElevationGainFt: cyclingElevationGainFt,
      cyclingSessionGoal: cyclingSessionGoal,
      swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
      swimmingWaterTempC: swimmingWaterTempC,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
      completedAt: completedAt,
      completionRating: completionRating,
      completionNotes: completionNotes,
      actualDistanceMiles: actualDistanceMiles,
      actualDurationMinutes: actualDurationMinutes,
      nutritionPlanData: parseNutritionPlanDataValue(nutritionPlanDataRaw),
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: reminderDaysBefore,
      reminderTimeOfDay: reminderTimeOfDay,
      reminderRecurring: reminderRecurring ?? false,
      brickMetadata: parseBrickMetadataValue(brickMetadataRaw),
      brickId: brickId,
      needsUpload: needsUpload,
      localUpdatedAt: localUpdatedAt,
      syncedFromProvider: syncedFromProvider,
      providerWorkoutId: providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl,
      lastSyncedAt: lastSyncedAt,
      workoutSubtype: workoutSubtype,
      paceMinMinutesPerMile: paceMinMinutesPerMile,
      paceMaxMinutesPerMile: paceMaxMinutesPerMile,
      needsNutritionRefresh: needsNutritionRefresh,
      providerDeletedAt: providerDeletedAt,
      providerScheduledAt: providerScheduledAt,
      scheduleChangedAt: scheduleChangedAt,
    );
  }

  // ========================================================================
  // Domain → Drift Companion
  // ========================================================================

  /// Map domain [Activity] to [ActivitiesTableCompanion] for Drift operations.
  ///
  /// Set [forInsert] to true for new activities to use Value.absent()
  /// for id and deletedAt, triggering auto-generation and proper defaults.
  ActivitiesTableCompanion toCompanion(
    domain.Activity activity, {
    bool forInsert = false,
  }) {
    return ActivitiesTableCompanion(
      id: forInsert ? const Value.absent() : Value(activity.id),
      userId: Value(activity.userId),
      activityType: Value(activity.activityType.name),
      title: Value(activity.title),
      scheduledDateTime: Value(activity.scheduledDateTime),
      status: Value(activity.status.name),
      distanceMiles: Value(activity.distanceMiles),
      durationMinutes: Value(activity.durationMinutes),
      paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
      intensityLevel: Value(activity.intensityLevel?.name),
      intensityTarget: Value(activity.intensityTarget),
      intensityZ1Z2Pct: Value(
        activity.intensityDistribution?.conversationalPct,
      ),
      intensityZ3Z4Pct: Value(activity.intensityDistribution?.tempoPct),
      intensityZ5Pct: Value(activity.intensityDistribution?.allOutPct),
      timeBeforeMinutes: Value(activity.timeBeforeMinutes),
      notes: Value(activity.notes),
      cyclingSpeedMph: Value(activity.cyclingSpeedMph),
      cyclingTerrain: Value(activity.cyclingTerrain),
      cyclingIndoorOutdoor: Value(activity.cyclingIndoorOutdoor),
      cyclingElevationGainFt: Value(activity.cyclingElevationGainFt),
      cyclingSessionGoal: Value(activity.cyclingSessionGoal),
      swimmingPacePer100mSeconds: Value(activity.swimmingPacePer100mSeconds),
      swimmingPoolOrOpenWater: Value(activity.swimmingPoolOrOpenWater),
      swimmingWaterTempC: Value(activity.swimmingWaterTempC),
      completedAt: Value(activity.completedAt),
      actualDistanceMiles: Value(activity.actualDistanceMiles),
      actualDurationMinutes: Value(activity.actualDurationMinutes),
      completionRating: Value(activity.completionRating),
      completionNotes: Value(activity.completionNotes),
      nutritionPlanData: Value(
        activity.nutritionPlanData != null
            ? jsonEncode(activity.nutritionPlanData)
            : null,
      ),
      reminderEnabled: Value(activity.reminderEnabled),
      reminderDaysBefore: Value(activity.reminderDaysBefore),
      reminderTimeOfDay: Value(activity.reminderTimeOfDay),
      reminderRecurring: Value(activity.reminderRecurring),
      brickMetadata: Value(
        activity.brickMetadata != null
            ? jsonEncode(activity.brickMetadata!.toJson())
            : null,
      ),
      brickId: Value(activity.brickId),
      syncedFromProvider: Value(activity.syncedFromProvider),
      providerWorkoutId: Value(activity.providerWorkoutId),
      providerWorkoutUrl: Value(activity.providerWorkoutUrl),
      lastSyncedAt: Value(activity.lastSyncedAt),
      needsNutritionRefresh: Value(activity.needsNutritionRefresh),
      providerDeletedAt: Value(activity.providerDeletedAt),
      providerScheduledAt: Value(activity.providerScheduledAt),
      scheduleChangedAt: Value(activity.scheduleChangedAt),
      workoutSubtype: Value(activity.workoutSubtype),
      paceMinMinutesPerMile: Value(activity.paceMinMinutesPerMile),
      paceMaxMinutesPerMile: Value(activity.paceMaxMinutesPerMile),
      createdAt: Value(activity.createdAt),
      updatedAt: Value(activity.updatedAt),
      deletedAt: forInsert ? const Value.absent() : Value(activity.deletedAt),
      needsUpload: Value(activity.needsUpload ?? false),
      localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
    );
  }

  // ========================================================================
  // Domain → Supabase JSON Payloads
  // ========================================================================

  /// Build Supabase JSON payload from domain [Activity].
  ///
  /// Set [includeCreatedAt] to true for insert operations, false for updates.
  Map<String, dynamic> buildSupabasePayload(
    domain.Activity activity, {
    bool includeCreatedAt = false,
  }) {
    return {
      'id': activity.id,
      'user_id': activity.userId,
      'activity_type': activity.activityType.dbValue,
      'title': activity.title,
      'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
      'status': activityStatusToDbValue(activity.status.name),
      'distance_miles': activity.distanceMiles,
      'duration_minutes': activity.durationMinutes,
      'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
      'intensity_level': activity.intensityLevel?.name,
      'intensity_target': activity.intensityTarget,
      'intensity_z1_z2_pct': activity.intensityDistribution?.conversationalPct,
      'intensity_z3_z4_pct': activity.intensityDistribution?.tempoPct,
      'intensity_z5_pct': activity.intensityDistribution?.allOutPct,
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
      'synced_from_provider': activity.syncedFromProvider,
      'provider_workout_id': activity.providerWorkoutId,
      'provider_workout_url': activity.providerWorkoutUrl,
      'last_synced_at': activity.lastSyncedAt?.toIso8601String(),
      'workout_subtype': activity.workoutSubtype,
      'pace_min_minutes_per_mile': activity.paceMinMinutesPerMile,
      'pace_max_minutes_per_mile': activity.paceMaxMinutesPerMile,
      'provider_deleted_at': activity.providerDeletedAt?.toIso8601String(),
      'provider_scheduled_at':
          activity.providerScheduledAt?.toIso8601String(),
      'schedule_changed_at': activity.scheduleChangedAt?.toIso8601String(),
      'brick_metadata': activity.brickMetadata?.toJson(),
      'brick_id': activity.brickId,
      if (includeCreatedAt)
        'created_at': activity.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Build Supabase JSON payload from a Drift [Activity] row (for dirty record uploads).
  Map<String, dynamic> buildUploadPayloadFromRow(Activity record) {
    return {
      'id': record.id,
      'user_id': record.userId,
      'activity_type': record.activityType,
      'title': record.title,
      'scheduled_date_time': record.scheduledDateTime.toIso8601String(),
      'status': activityStatusToDbValue(record.status),
      'distance_miles': record.distanceMiles,
      'duration_minutes': record.durationMinutes,
      'pace_target_minutes_per_mile': record.paceTargetMinutesPerMile,
      'intensity_level': record.intensityLevel,
      'intensity_target': record.intensityTarget,
      'intensity_z1_z2_pct': record.intensityZ1Z2Pct,
      'intensity_z3_z4_pct': record.intensityZ3Z4Pct,
      'intensity_z5_pct': record.intensityZ5Pct,
      'time_before_minutes': record.timeBeforeMinutes,
      'notes': record.notes,
      'cycling_speed_mph': record.cyclingSpeedMph,
      'cycling_terrain': record.cyclingTerrain,
      'cycling_indoor_outdoor': record.cyclingIndoorOutdoor,
      'cycling_elevation_gain_ft': record.cyclingElevationGainFt,
      'cycling_session_goal': record.cyclingSessionGoal,
      'swimming_pace_per_100m_seconds': record.swimmingPacePer100mSeconds,
      'swimming_pool_or_open_water': record.swimmingPoolOrOpenWater,
      'swimming_water_temp_c': record.swimmingWaterTempC,
      'completed_at': record.completedAt?.toIso8601String(),
      'actual_distance_miles': record.actualDistanceMiles,
      'actual_duration_minutes': record.actualDurationMinutes,
      'completion_rating': record.completionRating,
      'completion_notes': record.completionNotes,
      'nutrition_plan_data': decodeJsonObject(
        record.nutritionPlanData,
        fieldName: 'nutrition_plan_data',
        activityId: record.id,
      ),
      'synced_from_provider': record.syncedFromProvider,
      'provider_workout_id': record.providerWorkoutId,
      'provider_workout_url': record.providerWorkoutUrl,
      'last_synced_at': record.lastSyncedAt?.toIso8601String(),
      'workout_subtype': record.workoutSubtype,
      'pace_min_minutes_per_mile': record.paceMinMinutesPerMile,
      'pace_max_minutes_per_mile': record.paceMaxMinutesPerMile,
      'provider_deleted_at': record.providerDeletedAt?.toIso8601String(),
      'provider_scheduled_at':
          record.providerScheduledAt?.toIso8601String(),
      'schedule_changed_at': record.scheduleChangedAt?.toIso8601String(),
      'brick_metadata': decodeJsonObject(
        record.brickMetadata,
        fieldName: 'brick_metadata',
        activityId: record.id,
      ),
      'brick_id': record.brickId,
      'created_at': record.createdAt.toIso8601String(),
      'updated_at': record.updatedAt.toIso8601String(),
    };
  }

  // ========================================================================
  // Parsing Utilities
  // ========================================================================

  /// Parse activity status from Supabase or local database values.
  /// Supports both snake_case (Supabase) and camelCase (local) formats.
  domain.ActivityStatus parseActivityStatus(dynamic value) {
    final status = (value ?? '').toString();
    switch (status) {
      case 'draft':
        return domain.ActivityStatus.draft;
      case 'planned':
        return domain.ActivityStatus.planned;
      case 'in_progress':
      case 'inProgress':
        return domain.ActivityStatus.inProgress;
      case 'completed':
        return domain.ActivityStatus.completed;
      case 'skipped':
        return domain.ActivityStatus.skipped;
      case 'archived_for_brick':
      case 'archivedForBrick':
        return domain.ActivityStatus.archivedForBrick;
      default:
        return domain.ActivityStatus.planned;
    }
  }

  /// Convert local activity status string to Supabase enum value.
  String activityStatusToDbValue(String status) {
    switch (status) {
      case 'inProgress':
        return 'in_progress';
      case 'archivedForBrick':
        return 'archived_for_brick';
      default:
        return status;
    }
  }

  /// Parse DateTime values that may come as String or DateTime.
  DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return null;
  }

  /// Parse nutrition plan data from any source (JSONB map, JSON string, or null).
  Map<String, dynamic>? parseNutritionPlanDataValue(dynamic value) {
    try {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      if (value is String && value.isNotEmpty) {
        return _decodeJsonMap(value);
      }
      return null;
    } catch (e) {
      _logger.warning(
        'Failed to parse nutrition plan data',
        context: 'ACTIVITY_MAPPER',
        error: e,
      );
      return null;
    }
  }

  /// Parse brick metadata from any source (JSONB map, JSON string, or null).
  BrickMetadata? parseBrickMetadataValue(dynamic value) {
    try {
      if (value == null) return null;
      if (value is Map<String, dynamic>) {
        return BrickMetadata.fromJson(value);
      }
      if (value is Map) {
        final normalized = value.map(
          (key, val) => MapEntry(key.toString(), val),
        );
        return BrickMetadata.fromJson(normalized);
      }
      if (value is String && value.isNotEmpty) {
        final map = _decodeJsonMap(value);
        return map != null ? BrickMetadata.fromJson(map) : null;
      }
      return null;
    } catch (e) {
      _logger.warning(
        'Failed to parse brick metadata',
        context: 'ACTIVITY_MAPPER',
        error: e,
      );
      return null;
    }
  }

  /// Decode a JSON object string from Drift for JSONB Supabase columns.
  /// Handles both standard JSON object strings and double-encoded JSON strings.
  Map<String, dynamic>? decodeJsonObject(
    String? jsonString, {
    required String fieldName,
    String? activityId,
  }) {
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      if (decoded is String && decoded.isNotEmpty) {
        final nested = jsonDecode(decoded);
        if (nested is Map<String, dynamic>) {
          return nested;
        }
        if (nested is Map) {
          return nested.map((key, value) => MapEntry(key.toString(), value));
        }
      }
    } catch (e) {
      _logger.warning(
        'Failed to decode JSON object for upload - sending null',
        context: 'ACTIVITY_MAPPER',
        error: e,
        data: {'fieldName': fieldName, 'activityId': activityId},
      );
    }

    return null;
  }

  /// Decode a JSON string to a Map, handling double-encoding.
  Map<String, dynamic>? _decodeJsonMap(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, val) => MapEntry(key.toString(), val));
      }
      // Handle double-encoded JSON
      if (decoded is String && decoded.isNotEmpty) {
        final nested = jsonDecode(decoded);
        if (nested is Map<String, dynamic>) {
          return nested;
        }
        if (nested is Map) {
          return nested.map((key, val) => MapEntry(key.toString(), val));
        }
      }
      return null;
    } catch (e) {
      _logger.error(
        'Failed to decode JSON map',
        context: 'ACTIVITY_MAPPER',
        error: e,
      );
      return null;
    }
  }
}
