/// TrainingPeaks workout data transformer
///
/// Transforms TrainingPeaks API workout responses into Mealvana Activity models.
/// Handles unit conversion, sport type mapping, and sensible defaults.
///
/// CRITICAL DIFFERENCES FROM FINAL SURGE:
/// - Distance is ALWAYS in METERS (convert to miles: m * 0.000621371)
/// - TotalTime is in DECIMAL HOURS (convert to minutes: h * 60)
/// - Workout ID is Int64 (store as String for safety)
/// - Pace is NOT provided (calculate from distance/time)
/// - Has event sync data (unique feature!)
library;

import 'package:uuid/uuid.dart';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../domain/training_peaks_defaults.dart';

/// Result of transforming a TrainingPeaks workout
/// Includes Activity fields plus sync metadata
class TrainingPeaksTransformResult {
  const TrainingPeaksTransformResult({
    required this.activity,
    required this.syncedFromProvider,
    required this.providerWorkoutId,
    this.providerWorkoutUrl,
    required this.lastSyncedAt,
    this.workoutSubtype,
    this.distanceMeters,
    this.tssPlanned,
    this.ifPlanned,
  });

  /// The transformed Activity object
  final Activity activity;

  /// Provider name (always 'training_peaks')
  final String syncedFromProvider;

  /// Unique workout ID from provider (Int64 as String)
  final String providerWorkoutId;

  /// URL to view workout in TrainingPeaks
  final String? providerWorkoutUrl;

  /// When this sync occurred
  final DateTime lastSyncedAt;

  /// Workout subtype/title from TrainingPeaks
  final String? workoutSubtype;

  /// Distance in meters (TrainingPeaks native format)
  final double? distanceMeters;

  /// Training Stress Score (TrainingPeaks-specific)
  final double? tssPlanned;

  /// Intensity Factor (TrainingPeaks-specific)
  final double? ifPlanned;
}

/// Result of transforming a TrainingPeaks event
class TrainingPeaksEventResult {
  const TrainingPeaksEventResult({
    required this.eventId,
    required this.eventDate,
    required this.eventType,
    required this.eventName,
    this.description,
    this.goals,
    this.workoutIds,
  });

  /// Event ID from TrainingPeaks
  final String eventId;

  /// Event date
  final DateTime eventDate;

  /// Event type (e.g., Marathon, Triathlon, RoadCycling)
  final String eventType;

  /// Event name
  final String eventName;

  /// Event description
  final String? description;

  /// Event goals (distance, time, place, PR)
  final List<TrainingPeaksGoal>? goals;

  /// Associated workout IDs
  final List<String>? workoutIds;

  /// Map event type to Mealvana activity type
  ActivityType get activityType {
    switch (eventType.toLowerCase()) {
      // Running events
      case 'roadrunning':
      case 'trailrunning':
      case 'trackrunning':
      case 'crosscountry':
      case 'running':
      case 'marathon':
        return ActivityType.running;

      // Cycling events
      case 'roadcycling':
      case 'mountainbiking':
      case 'cyclocross':
      case 'trackcycling':
      case 'cycling':
      case 'mtb':
        return ActivityType.cycling;

      // Swimming events
      case 'openwaterswimming':
      case 'poolswimming':
      case 'swimming':
      case 'swim':
        return ActivityType.swimming;

      // Multisport events
      case 'triathlon':
      case 'xterra':
        return ActivityType.triathlon;
      case 'duathlon':
        return ActivityType.duathlon;
      case 'aquabike':
      case 'aquathon':
      case 'multisport':
        return ActivityType.multisport;

      default:
        // Default to running for unknown event types
        return ActivityType.running;
    }
  }

  /// Extract distance from goals if present (in miles)
  double? get goalDistanceMiles {
    if (goals == null) return null;
    final distanceGoal = goals!.firstWhere(
      (g) => g.goalType == 'Distance',
      orElse: () => const TrainingPeaksGoal(goalType: '', value: 0),
    );
    if (distanceGoal.goalType.isEmpty) return null;

    // Distance goal unit is typically Miles
    if (distanceGoal.unit?.toLowerCase() == 'miles') {
      return distanceGoal.value;
    }
    // Convert km to miles if needed
    if (distanceGoal.unit?.toLowerCase() == 'km' ||
        distanceGoal.unit?.toLowerCase() == 'kilometers') {
      return distanceGoal.value * TrainingPeaksDefaults.kmToMiles;
    }
    return distanceGoal.value;
  }

  /// Extract time goal if present (in hours)
  double? get goalTimeHours {
    if (goals == null) return null;
    final timeGoal = goals!.firstWhere(
      (g) => g.goalType == 'Time',
      orElse: () => const TrainingPeaksGoal(goalType: '', value: 0),
    );
    if (timeGoal.goalType.isEmpty) return null;

    // Time goal unit is typically Hours
    return timeGoal.value;
  }
}

/// A goal from TrainingPeaks event
class TrainingPeaksGoal {
  const TrainingPeaksGoal({
    required this.goalType,
    required this.value,
    this.unit,
  });

  final String goalType; // Distance, Time, Place, Pr
  final double value;
  final String? unit;

  factory TrainingPeaksGoal.fromJson(Map<String, dynamic> json) {
    return TrainingPeaksGoal(
      goalType: json['GoalType'] as String? ?? '',
      value: (json['Value'] as num?)?.toDouble() ?? 0,
      unit: json['Unit'] as String?,
    );
  }
}

/// Transforms TrainingPeaks workouts and events to Mealvana models
class TrainingPeaksTransformer {
  const TrainingPeaksTransformer();

  static const _uuid = Uuid();

  /// Supported workout types that we import
  /// TrainingPeaks types: swim, bike, run, x-train, mtb, strength, xc-ski, rowing, walk, other
  static const supportedTypes = ['Swim', 'Bike', 'Run', 'Walk', 'Rowing', 'MTB'];

  /// Transform a TrainingPeaks workout JSON to a Mealvana Activity
  ///
  /// Returns null if the workout type is not supported
  TrainingPeaksTransformResult? transform(
    Map<String, dynamic> workout,
    String userId,
  ) {
    final workoutType = workout['WorkoutType'] as String?;

    // Filter out unsupported workout types
    if (workoutType == null ||
        !supportedTypes.any((t) => t.toLowerCase() == workoutType.toLowerCase())) {
      return null;
    }

    final activityType = _mapActivityType(workoutType);
    final isWalk = workoutType.toLowerCase() == 'walk';
    final now = DateTime.now();

    // Get duration (TotalTime is in DECIMAL HOURS - critical difference!)
    final durationMinutes = _getDurationMinutes(workout, activityType);

    // Get distance (Distance is ALWAYS in METERS - critical difference!)
    final distanceMeters = _getDistanceMeters(workout, activityType);
    final distanceMiles = activityType == ActivityType.swimming
        ? null
        : distanceMeters * TrainingPeaksDefaults.metersToMiles;

    // Calculate pace from distance and time (TrainingPeaks doesn't provide pace)
    final paceMinPerMile = _calculatePace(distanceMiles, durationMinutes, activityType);

    // Extract provider info
    final providerWorkoutId = extractWorkoutId(workout);
    final providerWorkoutUrl = _buildWorkoutUrl(workout);

    // Create the Activity with provider sync fields
    // Use 'planned' status since synced workouts are confirmed by external platform
    final activity = Activity(
      id: _uuid.v4(),
      userId: userId,
      activityType: activityType,
      title: _getTitle(workout, workoutType),
      scheduledDateTime: _parseScheduledDate(
        workout['WorkoutDay'] as String?,
        workout['StartTime'] as String? ?? workout['StartTimePlanned'] as String?,
      ),
      status: ActivityStatus.planned,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      paceTargetMinutesPerMile: paceMinPerMile,
      intensityLevel: isWalk ? IntensityLevel.easy : _inferIntensity(workout),
      swimmingPacePer100mSeconds: activityType == ActivityType.swimming
          ? _calculateSwimmingPace(distanceMeters, durationMinutes)
          : null,
      notes: workout['Description'] as String?,
      // Provider sync fields
      syncedFromProvider: 'training_peaks',
      providerWorkoutId: providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl,
      lastSyncedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    return TrainingPeaksTransformResult(
      activity: activity,
      syncedFromProvider: 'training_peaks',
      providerWorkoutId: providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl,
      lastSyncedAt: now,
      workoutSubtype: isWalk ? 'Walk' : workout['Title'] as String?,
      distanceMeters: distanceMeters,
      tssPlanned: (workout['TSSPlanned'] as num?)?.toDouble(),
      ifPlanned: (workout['IFPlanned'] as num?)?.toDouble(),
    );
  }

  /// Transform a TrainingPeaks event JSON to Mealvana event data
  TrainingPeaksEventResult? transformEvent(Map<String, dynamic> event) {
    final eventId = event['Id'];
    final eventDate = event['EventDate'] as String?;
    final eventType = event['EventType'] as String?;
    final eventName = event['Name'] as String?;

    if (eventId == null || eventDate == null || eventType == null) {
      return null;
    }

    // Parse goals
    final goalsJson = event['Goals'] as List?;
    final goals = goalsJson?.map((g) {
      return TrainingPeaksGoal.fromJson(g as Map<String, dynamic>);
    }).toList();

    // Parse workout IDs
    final workoutIdsJson = event['WorkoutIds'] as List?;
    final workoutIds = workoutIdsJson?.map((id) => id.toString()).toList();

    return TrainingPeaksEventResult(
      eventId: eventId.toString(),
      eventDate: DateTime.tryParse(eventDate) ?? DateTime.now(),
      eventType: eventType,
      eventName: eventName ?? 'Unnamed Event',
      description: event['Description'] as String?,
      goals: goals,
      workoutIds: workoutIds,
    );
  }

  /// Extract workout ID from workout data
  /// TrainingPeaks uses Int64, so store as String for safety
  String extractWorkoutId(Map<String, dynamic> workout) {
    final id = workout['Id'];
    if (id != null) {
      return id.toString();
    }

    // Fallback: use hash of the workout date + type
    final date = workout['WorkoutDay'] ?? '';
    final type = workout['WorkoutType'] ?? '';
    return '${date}_$type'.hashCode.toString();
  }

  /// Build URL to view workout in TrainingPeaks
  String? _buildWorkoutUrl(Map<String, dynamic> workout) {
    final id = workout['Id'];
    if (id == null) return null;
    // TrainingPeaks workout URL format
    return 'https://www.trainingpeaks.com/workout/$id';
  }

  /// Map TrainingPeaks workout type to Mealvana ActivityType
  ActivityType _mapActivityType(String workoutType) {
    switch (workoutType.toLowerCase()) {
      case 'run':
      case 'walk': // Walk maps to running with easy intensity
        return ActivityType.running;
      case 'bike':
      case 'mtb':
        return ActivityType.cycling;
      case 'swim':
        return ActivityType.swimming;
      case 'rowing':
        // Rowing maps to cycling for nutrition purposes (similar metabolic profile)
        return ActivityType.cycling;
      default:
        return ActivityType.running;
    }
  }

  /// Get title from workout, with fallbacks
  String _getTitle(Map<String, dynamic> workout, String workoutType) {
    final title = workout['Title'] as String?;
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return workoutType;
  }

  /// Parse scheduled date and time from ISO strings
  DateTime _parseScheduledDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }

    var date = DateTime.tryParse(dateStr) ?? DateTime.now();

    // If we have a time string, combine it with the date
    if (timeStr != null && timeStr.isNotEmpty) {
      final time = DateTime.tryParse(timeStr);
      if (time != null) {
        date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          time.second,
        );
      }
    }

    return date;
  }

  /// Get duration in minutes (TotalTime is in DECIMAL HOURS)
  /// CRITICAL: This is different from Final Surge which uses seconds!
  int _getDurationMinutes(Map<String, dynamic> workout, ActivityType activityType) {
    final totalTimeHours = workout['TotalTime'] ?? workout['TotalTimePlanned'];
    if (totalTimeHours != null && totalTimeHours is num && totalTimeHours > 0) {
      // Convert decimal hours to minutes: hours * 60
      return (totalTimeHours * TrainingPeaksDefaults.hoursToMinutes).round();
    }

    // Apply sensible defaults based on sport type
    switch (activityType) {
      case ActivityType.running:
        return TrainingPeaksDefaults.runningDurationMinutes;
      case ActivityType.cycling:
        return TrainingPeaksDefaults.cyclingDurationMinutes;
      case ActivityType.swimming:
        return TrainingPeaksDefaults.swimmingDurationMinutes;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        // Multi-sport and brick default to running for now
        return TrainingPeaksDefaults.runningDurationMinutes;
    }
  }

  /// Get distance in meters (TrainingPeaks ALWAYS uses meters)
  /// CRITICAL: This is different from Final Surge which has PlannedDistanceType!
  double _getDistanceMeters(Map<String, dynamic> workout, ActivityType activityType) {
    final distance = workout['Distance'] ?? workout['DistancePlanned'];
    if (distance != null && distance is num && distance > 0) {
      // TrainingPeaks distance is ALWAYS in meters - no conversion needed
      return distance.toDouble();
    }

    // Apply sensible defaults based on sport type
    switch (activityType) {
      case ActivityType.running:
        return TrainingPeaksDefaults.runningDistanceMeters;
      case ActivityType.cycling:
        return TrainingPeaksDefaults.cyclingDistanceMeters;
      case ActivityType.swimming:
        return TrainingPeaksDefaults.swimmingDistanceMeters;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        // Multi-sport and brick default to running for now
        return TrainingPeaksDefaults.runningDistanceMeters;
    }
  }

  /// Calculate pace from distance and duration
  /// TrainingPeaks does NOT provide pace - we must calculate it
  double? _calculatePace(double? distanceMiles, int? durationMinutes, ActivityType activityType) {
    // Swimming doesn't use min/mile pace
    if (activityType == ActivityType.swimming) return null;

    if (distanceMiles == null || distanceMiles <= 0) return null;
    if (durationMinutes == null || durationMinutes <= 0) return null;

    final paceMinPerMile = durationMinutes / distanceMiles;

    // Sanity check: pace should be between 4:00 and 20:00 min/mile for running
    // and between 2:00 and 10:00 min/mile for cycling
    if (activityType == ActivityType.running) {
      if (paceMinPerMile < 4 || paceMinPerMile > 20) {
        return TrainingPeaksDefaults.runningPaceMinPerMile;
      }
    } else if (activityType == ActivityType.cycling) {
      // For cycling, convert to speed instead of pace
      // Just return null for cycling - we use speed instead
      return null;
    }

    return paceMinPerMile;
  }

  /// Calculate swimming pace in seconds per 100m
  int? _calculateSwimmingPace(double? distanceMeters, int? durationMinutes) {
    if (distanceMeters == null || distanceMeters <= 0) return null;
    if (durationMinutes == null || durationMinutes <= 0) return null;

    final totalSeconds = durationMinutes * 60;
    final hundreds = distanceMeters / 100;
    return (totalSeconds / hundreds).round();
  }

  /// Infer intensity level from workout data
  IntensityLevel _inferIntensity(Map<String, dynamic> workout) {
    // Check IF (Intensity Factor) if available
    final ifValue = workout['IFPlanned'] as num?;
    if (ifValue != null) {
      if (ifValue >= 1.0) return IntensityLevel.race;
      if (ifValue >= 0.9) return IntensityLevel.hard;
      if (ifValue >= 0.75) return IntensityLevel.moderate;
      return IntensityLevel.easy;
    }

    // Check TSS for intensity hints
    final tss = workout['TSSPlanned'] as num?;
    if (tss != null) {
      // High TSS for duration suggests high intensity
      final duration = (workout['TotalTimePlanned'] as num?)?.toDouble();
      if (duration != null && duration > 0) {
        final tssPerHour = tss / duration;
        if (tssPerHour >= 100) return IntensityLevel.hard;
        if (tssPerHour >= 60) return IntensityLevel.moderate;
        return IntensityLevel.easy;
      }
    }

    // Check title for keywords
    final title = (workout['Title'] as String?)?.toLowerCase();
    if (title != null) {
      if (title.contains('race') || title.contains('competition')) {
        return IntensityLevel.race;
      }
      if (title.contains('tempo') ||
          title.contains('threshold') ||
          title.contains('interval') ||
          title.contains('speed') ||
          title.contains('hard')) {
        return IntensityLevel.hard;
      }
      if (title.contains('easy') ||
          title.contains('recovery') ||
          title.contains('warm')) {
        return IntensityLevel.easy;
      }
      if (title.contains('long') || title.contains('endurance')) {
        return IntensityLevel.moderate;
      }
    }

    // Default to moderate
    return IntensityLevel.moderate;
  }
}
