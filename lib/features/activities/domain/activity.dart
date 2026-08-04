import '../../../shared/domain/activity_type.dart';
import '../../../shared/utils/unit_formatter.dart';
import '../../nutrition_plan/domain/intensity_distribution.dart';
import 'brick_metadata.dart';

/// Activity domain model for calendar feature
class Activity {
  const Activity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.title,
    required this.scheduledDateTime,
    this.status = ActivityStatus.planned,

    // Activity parameters (shared)
    this.distanceMiles,
    this.durationMinutes,
    this.paceTargetMinutesPerMile,
    this.intensityLevel,

    // Cycling-specific parameters
    this.cyclingSpeedMph,
    this.cyclingTerrain,
    this.cyclingIndoorOutdoor,
    this.cyclingElevationGainFt,
    this.cyclingSessionGoal,

    // Swimming-specific parameters
    this.swimmingPacePer100mSeconds,
    this.swimmingPoolOrOpenWater,
    this.swimmingWaterTempC,

    // Shared intensity and timing
    this.intensityTarget,
    this.intensityDistribution,
    this.timeBeforeMinutes,

    // Fasted state the nutrition plan was generated with
    this.isFasted = false,

    // Completion data
    this.completedAt,
    this.completionRating,
    this.nutritionRating,
    this.completionNotes,
    this.actualDistanceMiles,
    this.actualDurationMinutes,

    // Nutrition plan data (embedded JSON from activities.nutrition_plan_data)
    this.nutritionPlanData,

    // Fuel log data (actual consumption logged on completion)
    this.fuelLogData,

    // Metadata
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,

    // Reminder settings
    this.reminderEnabled = false,
    this.reminderDaysBefore,
    this.reminderTimeOfDay,
    this.reminderRecurring = false,

    // Sync tracking (offline-first architecture)
    this.needsUpload,
    this.localUpdatedAt,

    // External provider sync tracking (Final Surge, etc.)
    this.syncedFromProvider,
    this.providerWorkoutId,
    this.providerWorkoutUrl,
    this.lastSyncedAt,
    this.workoutSubtype,
    this.paceMinMinutesPerMile,
    this.paceMaxMinutesPerMile,

    // Integration sync change tracking (Phase 1)
    this.needsNutritionRefresh = false,
    this.providerDeletedAt,
    this.providerScheduledAt,
    this.scheduleChangedAt,

    // Brick workout fields
    this.brickMetadata,
    this.brickId,

    // Garmin completion linkage + device attribution (brand-compliant UI)
    this.garminSummaryId,
    this.garminDeviceName,
  });

  final String id;
  final String userId;
  final ActivityType activityType;
  final String title;
  final DateTime scheduledDateTime;
  final ActivityStatus status;

  // Activity parameters (shared)
  final double? distanceMiles;
  final int? durationMinutes;
  final double? paceTargetMinutesPerMile;
  final IntensityLevel? intensityLevel;

  // Cycling-specific parameters
  final double? cyclingSpeedMph;
  final String? cyclingTerrain; // 'flat', 'rolling', 'hilly'
  final String? cyclingIndoorOutdoor; // 'indoor', 'outdoor'
  final int? cyclingElevationGainFt;
  final String? cyclingSessionGoal; // 'endurance', 'tempo', 'intervals'

  // Swimming-specific parameters
  final int? swimmingPacePer100mSeconds;
  final String? swimmingPoolOrOpenWater; // 'pool', 'open_water'
  final double? swimmingWaterTempC;

  // Shared intensity and timing
  final String? intensityTarget; // 'zone_1', 'zone_2', 'rpe_3', etc.
  final IntensityDistribution?
  intensityDistribution; // Three-zone percentage distribution
  final int? timeBeforeMinutes; // Pre-activity timing window

  // Fasted state the nutrition plan was generated with. Persisted so
  // regeneration keeps fasted macros instead of defaulting to non-fasted.
  final bool isFasted;

  // Completion data
  final DateTime? completedAt;
  final int? completionRating;
  final int? nutritionRating; // 1-5 carb feedback scale (emoji mapping)
  final String? completionNotes;
  final double? actualDistanceMiles;
  final int? actualDurationMinutes;

  // Nutrition plan data (embedded JSON from activities.nutrition_plan_data)
  final Map<String, dynamic>? nutritionPlanData;

  // Fuel log data (actual consumption logged on completion)
  final Map<String, dynamic>? fuelLogData;

  // Metadata
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Reminder settings
  final bool reminderEnabled;
  final int? reminderDaysBefore; // 1-7 days before activity
  final String? reminderTimeOfDay; // Format: "HH:mm"
  final bool reminderRecurring;

  // Sync tracking (offline-first architecture)
  final bool? needsUpload;
  final DateTime? localUpdatedAt;

  // External provider sync tracking (Final Surge, etc.)
  final String? syncedFromProvider; // 'final_surge', etc.
  final String? providerWorkoutId; // WorkoutKey from provider
  final String? providerWorkoutUrl; // URL to view workout in provider
  final DateTime? lastSyncedAt;
  final String? workoutSubtype; // 'long_run', 'interval', etc.
  final double? paceMinMinutesPerMile; // Pace range from provider
  final double? paceMaxMinutesPerMile;

  // Integration sync change tracking (Phase 1)
  final bool
  needsNutritionRefresh; // Flag when schedule changes require nutrition refresh
  final DateTime?
  providerDeletedAt; // Soft-delete timestamp when provider removes workout
  final DateTime?
  providerScheduledAt; // Original provider schedule for change detection
  final DateTime?
  scheduleChangedAt; // When change was last detected during sync

  // Brick workout fields
  final BrickMetadata? brickMetadata; // Brick segment information (JSON)
  final String? brickId; // Parent brick ID if this is an archived segment

  // Garmin completion summary id — present whenever this activity's completion
  // data came from a Garmin push (including when TP/FS planned the workout).
  // Authoritative signal for whether Garmin brand attribution is required.
  final String? garminSummaryId;

  // Garmin device model (e.g., "Forerunner 955") — used for attribution
  // where we surface Garmin-derived data per brand guidelines.
  final String? garminDeviceName;

  /// Convenience getter to check if this is a brick activity
  bool get isBrick => activityType == ActivityType.brick;

  /// True when the activity displays Garmin-sourced data and therefore
  /// requires Garmin brand attribution per the Developer API Brand Guidelines.
  ///
  /// Covers both paths: activities originally synced from Garmin AND
  /// TP/FS-planned activities completed by a Garmin push (the common case).
  bool get hasGarminData =>
      garminSummaryId != null || syncedFromProvider == 'garmin';

  /// Serialize activity to JSON for edge function payload
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'activityType': activityType.name,
      'title': title,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'status': status.name,
      'distanceMiles': distanceMiles,
      'durationMinutes': durationMinutes,
      'paceTargetMinutesPerMile': paceTargetMinutesPerMile,
      'intensityLevel': intensityLevel?.name,
      'cyclingSpeedMph': cyclingSpeedMph,
      'cyclingTerrain': cyclingTerrain,
      'cyclingIndoorOutdoor': cyclingIndoorOutdoor,
      'cyclingElevationGainFt': cyclingElevationGainFt,
      'cyclingSessionGoal': cyclingSessionGoal,
      'swimmingPacePer100mSeconds': swimmingPacePer100mSeconds,
      'swimmingPoolOrOpenWater': swimmingPoolOrOpenWater,
      'swimmingWaterTempC': swimmingWaterTempC,
      'intensityTarget': intensityTarget,
      'intensityDistribution': intensityDistribution?.toJson(),
      'timeBeforeMinutes': timeBeforeMinutes,
      'isFasted': isFasted,
      'completedAt': completedAt?.toIso8601String(),
      'completionRating': completionRating,
      'nutritionRating': nutritionRating,
      'completionNotes': completionNotes,
      'actualDistanceMiles': actualDistanceMiles,
      'actualDurationMinutes': actualDurationMinutes,
      'nutritionPlanData': nutritionPlanData,
      'fuelLogData': fuelLogData,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'reminderEnabled': reminderEnabled,
      'reminderDaysBefore': reminderDaysBefore,
      'reminderTimeOfDay': reminderTimeOfDay,
      'reminderRecurring': reminderRecurring,
      'syncedFromProvider': syncedFromProvider,
      'providerWorkoutId': providerWorkoutId,
      'providerWorkoutUrl': providerWorkoutUrl,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'workoutSubtype': workoutSubtype,
      'paceMinMinutesPerMile': paceMinMinutesPerMile,
      'paceMaxMinutesPerMile': paceMaxMinutesPerMile,
      'needsNutritionRefresh': needsNutritionRefresh,
      'providerDeletedAt': providerDeletedAt?.toIso8601String(),
      'providerScheduledAt': providerScheduledAt?.toIso8601String(),
      'scheduleChangedAt': scheduleChangedAt?.toIso8601String(),
      'brickMetadata': brickMetadata?.toJson(),
      'brickId': brickId,
      'garminSummaryId': garminSummaryId,
      'garminDeviceName': garminDeviceName,
    };
  }

  Activity copyWith({
    String? id,
    String? userId,
    ActivityType? activityType,
    String? title,
    DateTime? scheduledDateTime,
    ActivityStatus? status,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    IntensityLevel? intensityLevel,
    double? cyclingSpeedMph,
    String? cyclingTerrain,
    String? cyclingIndoorOutdoor,
    int? cyclingElevationGainFt,
    String? cyclingSessionGoal,
    int? swimmingPacePer100mSeconds,
    String? swimmingPoolOrOpenWater,
    double? swimmingWaterTempC,
    String? intensityTarget,
    IntensityDistribution? intensityDistribution,
    int? timeBeforeMinutes,
    bool? isFasted,
    DateTime? completedAt,
    int? completionRating,
    int? nutritionRating,
    String? completionNotes,
    double? actualDistanceMiles,
    int? actualDurationMinutes,
    Map<String, dynamic>? nutritionPlanData,
    Map<String, dynamic>? fuelLogData,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    String? reminderTimeOfDay,
    bool? reminderRecurring,
    bool? needsUpload,
    DateTime? localUpdatedAt,
    String? syncedFromProvider,
    String? providerWorkoutId,
    String? providerWorkoutUrl,
    DateTime? lastSyncedAt,
    String? workoutSubtype,
    double? paceMinMinutesPerMile,
    double? paceMaxMinutesPerMile,
    bool? needsNutritionRefresh,
    DateTime? providerDeletedAt,
    DateTime? providerScheduledAt,
    DateTime? scheduleChangedAt,
    BrickMetadata? brickMetadata,
    String? brickId,
    String? garminSummaryId,
    String? garminDeviceName,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      status: status ?? this.status,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      paceTargetMinutesPerMile:
          paceTargetMinutesPerMile ?? this.paceTargetMinutesPerMile,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      cyclingSpeedMph: cyclingSpeedMph ?? this.cyclingSpeedMph,
      cyclingTerrain: cyclingTerrain ?? this.cyclingTerrain,
      cyclingIndoorOutdoor: cyclingIndoorOutdoor ?? this.cyclingIndoorOutdoor,
      cyclingElevationGainFt:
          cyclingElevationGainFt ?? this.cyclingElevationGainFt,
      cyclingSessionGoal: cyclingSessionGoal ?? this.cyclingSessionGoal,
      swimmingPacePer100mSeconds:
          swimmingPacePer100mSeconds ?? this.swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater:
          swimmingPoolOrOpenWater ?? this.swimmingPoolOrOpenWater,
      swimmingWaterTempC: swimmingWaterTempC ?? this.swimmingWaterTempC,
      intensityTarget: intensityTarget ?? this.intensityTarget,
      intensityDistribution:
          intensityDistribution ?? this.intensityDistribution,
      timeBeforeMinutes: timeBeforeMinutes ?? this.timeBeforeMinutes,
      isFasted: isFasted ?? this.isFasted,
      completedAt: completedAt ?? this.completedAt,
      completionRating: completionRating ?? this.completionRating,
      nutritionRating: nutritionRating ?? this.nutritionRating,
      completionNotes: completionNotes ?? this.completionNotes,
      actualDistanceMiles: actualDistanceMiles ?? this.actualDistanceMiles,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      nutritionPlanData: nutritionPlanData ?? this.nutritionPlanData,
      fuelLogData: fuelLogData ?? this.fuelLogData,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderTimeOfDay: reminderTimeOfDay ?? this.reminderTimeOfDay,
      reminderRecurring: reminderRecurring ?? this.reminderRecurring,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncedFromProvider: syncedFromProvider ?? this.syncedFromProvider,
      providerWorkoutId: providerWorkoutId ?? this.providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl ?? this.providerWorkoutUrl,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      workoutSubtype: workoutSubtype ?? this.workoutSubtype,
      paceMinMinutesPerMile:
          paceMinMinutesPerMile ?? this.paceMinMinutesPerMile,
      paceMaxMinutesPerMile:
          paceMaxMinutesPerMile ?? this.paceMaxMinutesPerMile,
      needsNutritionRefresh:
          needsNutritionRefresh ?? this.needsNutritionRefresh,
      providerDeletedAt: providerDeletedAt ?? this.providerDeletedAt,
      providerScheduledAt: providerScheduledAt ?? this.providerScheduledAt,
      scheduleChangedAt: scheduleChangedAt ?? this.scheduleChangedAt,
      brickMetadata: brickMetadata ?? this.brickMetadata,
      brickId: brickId ?? this.brickId,
      garminSummaryId: garminSummaryId ?? this.garminSummaryId,
      garminDeviceName: garminDeviceName ?? this.garminDeviceName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Activity &&
        other.id == id &&
        other.userId == userId &&
        other.activityType == activityType &&
        other.title == title &&
        other.scheduledDateTime == scheduledDateTime &&
        other.status == status &&
        other.distanceMiles == distanceMiles &&
        other.durationMinutes == durationMinutes &&
        other.paceTargetMinutesPerMile == paceTargetMinutesPerMile &&
        other.intensityLevel == intensityLevel &&
        other.cyclingSpeedMph == cyclingSpeedMph &&
        other.cyclingTerrain == cyclingTerrain &&
        other.cyclingIndoorOutdoor == cyclingIndoorOutdoor &&
        other.cyclingElevationGainFt == cyclingElevationGainFt &&
        other.cyclingSessionGoal == cyclingSessionGoal &&
        other.swimmingPacePer100mSeconds == swimmingPacePer100mSeconds &&
        other.swimmingPoolOrOpenWater == swimmingPoolOrOpenWater &&
        other.swimmingWaterTempC == swimmingWaterTempC &&
        other.intensityTarget == intensityTarget &&
        other.intensityDistribution == intensityDistribution &&
        other.timeBeforeMinutes == timeBeforeMinutes &&
        other.isFasted == isFasted &&
        other.completedAt == completedAt &&
        other.completionRating == completionRating &&
        other.nutritionRating == nutritionRating &&
        other.completionNotes == completionNotes &&
        other.actualDistanceMiles == actualDistanceMiles &&
        other.actualDurationMinutes == actualDurationMinutes &&
        other.nutritionPlanData == nutritionPlanData &&
        other.fuelLogData == fuelLogData &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.reminderEnabled == reminderEnabled &&
        other.reminderDaysBefore == reminderDaysBefore &&
        other.reminderTimeOfDay == reminderTimeOfDay &&
        other.reminderRecurring == reminderRecurring &&
        other.syncedFromProvider == syncedFromProvider &&
        other.providerWorkoutId == providerWorkoutId &&
        other.providerWorkoutUrl == providerWorkoutUrl &&
        other.lastSyncedAt == lastSyncedAt &&
        other.workoutSubtype == workoutSubtype &&
        other.paceMinMinutesPerMile == paceMinMinutesPerMile &&
        other.paceMaxMinutesPerMile == paceMaxMinutesPerMile &&
        other.brickMetadata == brickMetadata &&
        other.brickId == brickId &&
        other.garminSummaryId == garminSummaryId &&
        other.garminDeviceName == garminDeviceName;
  }

  @override
  int get hashCode {
    return Object.hash(
          id,
          userId,
          activityType,
          title,
          scheduledDateTime,
          status,
          distanceMiles,
          durationMinutes,
          paceTargetMinutesPerMile,
          intensityLevel,
          cyclingSpeedMph,
          cyclingTerrain,
          cyclingIndoorOutdoor,
          cyclingElevationGainFt,
          cyclingSessionGoal,
          swimmingPacePer100mSeconds,
          swimmingPoolOrOpenWater,
          swimmingWaterTempC,
          intensityTarget,
          intensityDistribution,
        ) ^
        Object.hash(
          timeBeforeMinutes,
          isFasted,
          completedAt,
          completionRating,
          nutritionRating,
          completionNotes,
          actualDistanceMiles,
          actualDurationMinutes,
          nutritionPlanData,
          fuelLogData,
          notes,
          createdAt,
          updatedAt,
          deletedAt,
          reminderEnabled,
          reminderDaysBefore,
          reminderTimeOfDay,
          reminderRecurring,
        ) ^
        Object.hash(
          syncedFromProvider,
          providerWorkoutId,
          providerWorkoutUrl,
          lastSyncedAt,
          workoutSubtype,
          paceMinMinutesPerMile,
          paceMaxMinutesPerMile,
          brickMetadata,
          brickId,
          garminSummaryId,
          garminDeviceName,
        );
  }

  @override
  String toString() {
    return 'Activity(id: $id, userId: $userId, activityType: $activityType, title: $title, scheduledDateTime: $scheduledDateTime, status: $status)';
  }
}

/// Activity status enum
enum ActivityStatus {
  draft, // Activity created but not finalized (no nutrition plan yet)
  planned, // Activity finalized with nutrition plan
  inProgress, // Activity in progress
  completed, // Activity completed
  skipped, // Activity skipped/cancelled
  archivedForBrick, // Activity archived as part of a brick workout
}

/// Intensity level enum
enum IntensityLevel { easy, moderate, hard, race }

/// Activity extensions for utility methods
extension ActivityExtensions on Activity {
  bool get isDraft => status == ActivityStatus.draft;
  bool get isCompleted => status == ActivityStatus.completed;
  bool get isPlanned => status == ActivityStatus.planned;
  bool get isRunning => activityType == ActivityType.running;
  bool get isCycling => activityType == ActivityType.cycling;
  bool get isSwimming => activityType == ActivityType.swimming;

  /// Get formatted pace if available
  String? get formattedPace {
    if (paceTargetMinutesPerMile == null) return null;
    // Via UnitFormatter so the minute carry is handled once — splitting
    // floor()/round() here renders 3.99995 as "3:60".
    return '${UnitFormatter.formatMinutesAsMinSec(paceTargetMinutesPerMile!)}/mi';
  }

  /// Get formatted duration if available
  String? get formattedDuration {
    if (durationMinutes == null) return null;
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    }
    return "${minutes}m";
  }

  /// Check if activity is in the past
  bool get isInPast => scheduledDateTime.isBefore(DateTime.now());

  /// Check if activity is today
  bool get isToday {
    final now = DateTime.now();
    return scheduledDateTime.year == now.year &&
        scheduledDateTime.month == now.month &&
        scheduledDateTime.day == now.day;
  }
}
