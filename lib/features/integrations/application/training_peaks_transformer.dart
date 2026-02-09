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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../../nutrition_plan/domain/intensity_distribution.dart';
import '../domain/athlete_zones.dart';
import '../domain/intensity_distribution_mapper.dart';
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
    this.intensityDistribution,
    this.elevationGainMeters,
    this.caloriesPlanned,
    this.tags,
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

  /// Inferred intensity distribution from structured workout or heuristics
  final IntensityDistribution? intensityDistribution;

  /// Elevation gain planned in meters (from ElevationGainPlanned)
  final double? elevationGainMeters;

  /// Planned calories (from CaloriesPlanned)
  final double? caloriesPlanned;

  /// Tags from the workout (used for intensity inference and user reference)
  final List<String>? tags;
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
  /// Returns null if the workout type is not supported.
  /// When [zones] is provided, uses athlete zone data for more precise
  /// intensity classification of structured workouts.
  TrainingPeaksTransformResult? transform(
    Map<String, dynamic> workout,
    String userId, {
    AthleteZones? zones,
  }) {
    if (kDebugMode) {
      print('🔍 TP TRANSFORM DEBUG - Raw workout keys: ${workout.keys.toList()}');
      print('🔍 TP TRANSFORM DEBUG - Raw workout data:');
      workout.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          print('   $key: $value');
        }
      });
    }

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

    // Phase 3: Extract additional fields
    final elevationGainMeters = (workout['ElevationGainPlanned'] as num?)?.toDouble();
    final caloriesPlanned = (workout['CaloriesPlanned'] as num?)?.toDouble();
    final tagsRaw = workout['Tags'] as List?;
    final tags = tagsRaw?.map((t) => t.toString()).toList();

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
      notes: _buildNotes(
        description: workout['Description'] as String?,
        tags: tags,
        elevationGainMeters: elevationGainMeters,
        caloriesPlanned: caloriesPlanned,
      ),
      // Provider sync fields
      syncedFromProvider: 'training_peaks',
      providerWorkoutId: providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl,
      lastSyncedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Infer intensity distribution from structured workout or heuristics
    // When zones are available, use them for more precise classification
    final intensityDistribution = _inferIntensityDistribution(workout, zones: zones);

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
      intensityDistribution: intensityDistribution,
      elevationGainMeters: elevationGainMeters,
      caloriesPlanned: caloriesPlanned,
      tags: tags,
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

  /// Default hour for workouts when no time is provided
  static const int _defaultHour = 7;

  /// Parse scheduled date and time from ISO strings.
  ///
  /// When no time is provided, defaults to 7:00 AM rather than midnight.
  DateTime _parseScheduledDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }

    var date = DateTime.tryParse(dateStr) ?? DateTime.now();

    // If we have a time string, combine it with the date
    if (timeStr != null && timeStr.isNotEmpty) {
      final time = DateTime.tryParse(timeStr);
      if (time != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          time.second,
        );
      }
    }

    // No time provided — default to 7:00 AM
    return DateTime(date.year, date.month, date.day, _defaultHour);
  }

  /// Get duration in minutes (TotalTime is in DECIMAL HOURS)
  /// CRITICAL: This is different from Final Surge which uses seconds!
  int _getDurationMinutes(Map<String, dynamic> workout, ActivityType activityType) {
    final totalTime = workout['TotalTime'];
    final totalTimePlanned = workout['TotalTimePlanned'];

    if (kDebugMode) {
      print('🔍 TP DURATION DEBUG:');
      print('   TotalTime raw value: $totalTime (type: ${totalTime.runtimeType})');
      print('   TotalTimePlanned raw value: $totalTimePlanned (type: ${totalTimePlanned.runtimeType})');
      // Also print all workout keys that contain 'time' or 'Time'
      final timeKeys = workout.keys.where((k) =>
        k.toString().toLowerCase().contains('time'));
      print('   All time-related keys: $timeKeys');
      for (final key in timeKeys) {
        print('   $key: ${workout[key]}');
      }
    }

    final totalTimeHours = totalTime ?? totalTimePlanned;
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
    final distance = workout['Distance'];
    final distancePlanned = workout['DistancePlanned'];

    if (kDebugMode) {
      print('🔍 TP DISTANCE DEBUG:');
      print('   Distance raw value: $distance (type: ${distance.runtimeType})');
      print('   DistancePlanned raw value: $distancePlanned (type: ${distancePlanned.runtimeType})');
      // Also print all workout keys that contain 'distance' or 'Distance'
      final distanceKeys = workout.keys.where((k) =>
        k.toString().toLowerCase().contains('distance'));
      print('   All distance-related keys: $distanceKeys');
      for (final key in distanceKeys) {
        print('   $key: ${workout[key]}');
      }
    }

    final effectiveDistance = distance ?? distancePlanned;
    if (effectiveDistance != null && effectiveDistance is num && effectiveDistance > 0) {
      // TrainingPeaks distance is ALWAYS in meters - no conversion needed
      return effectiveDistance.toDouble();
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

  /// Build notes from description and additional metadata
  String? _buildNotes({
    String? description,
    List<String>? tags,
    double? elevationGainMeters,
    double? caloriesPlanned,
  }) {
    final parts = <String>[];

    if (description != null && description.isNotEmpty) {
      parts.add(description);
    }

    final metadata = <String>[];
    if (elevationGainMeters != null && elevationGainMeters > 0) {
      final elevationFt = (elevationGainMeters * 3.28084).round();
      metadata.add('Elevation: ${elevationFt}ft');
    }
    if (caloriesPlanned != null && caloriesPlanned > 0) {
      metadata.add('Calories: ${caloriesPlanned.round()}');
    }
    if (tags != null && tags.isNotEmpty) {
      metadata.add('Tags: ${tags.join(', ')}');
    }

    if (metadata.isNotEmpty) {
      parts.add(metadata.join(' | '));
    }

    return parts.isEmpty ? null : parts.join('\n');
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

    // Check title and tags for keywords
    final title = (workout['Title'] as String?)?.toLowerCase() ?? '';
    final tagsRaw = workout['Tags'] as List?;
    final tagsStr = tagsRaw?.map((t) => t.toString().toLowerCase()).join(' ') ?? '';
    final keywords = '$title $tagsStr'.trim();

    if (keywords.isNotEmpty) {
      if (keywords.contains('race') || keywords.contains('competition')) {
        return IntensityLevel.race;
      }
      if (keywords.contains('tempo') ||
          keywords.contains('threshold') ||
          keywords.contains('interval') ||
          keywords.contains('speed') ||
          keywords.contains('hard')) {
        return IntensityLevel.hard;
      }
      if (keywords.contains('easy') ||
          keywords.contains('recovery') ||
          keywords.contains('warm')) {
        return IntensityLevel.easy;
      }
      if (keywords.contains('long') || keywords.contains('endurance')) {
        return IntensityLevel.moderate;
      }
    }

    // Default to moderate
    return IntensityLevel.moderate;
  }

  // ===========================================================================
  // Intensity Distribution Inference
  // ===========================================================================

  /// Infer intensity distribution from workout data
  ///
  /// Priority order:
  /// 1. Parse Structure JSON if present → time-weighted distribution
  /// 2. Use IFPlanned if available → map to heuristic pattern
  /// 3. Use Title keywords → map to heuristic pattern
  /// 4. Return null if no data available
  IntensityDistribution? _inferIntensityDistribution(
    Map<String, dynamic> workout, {
    AthleteZones? zones,
  }) {
    if (kDebugMode) {
      print('🔍 TP INTENSITY DEBUG - Checking for structured workout data');
      if (zones != null) print('   📊 Athlete zones available for precision mapping');
    }

    // 1. Try to parse structured workout (uses zones for precise classification)
    final structureJson = workout['Structure'] as String?;
    if (structureJson != null && structureJson.isNotEmpty) {
      final distribution = _parseStructuredWorkout(structureJson, zones: zones);
      if (distribution != null) {
        if (kDebugMode) {
          print('   ✅ Parsed structure JSON: $distribution');
        }
        return distribution;
      }
    }

    // 2. Try IF-based inference
    final ifValue = (workout['IFPlanned'] as num?)?.toDouble();
    if (ifValue != null && ifValue > 0) {
      final distribution = IntensityDistributionMapper.fromIntensityFactor(ifValue);
      if (distribution != null) {
        if (kDebugMode) {
          print('   ✅ Inferred from IF ($ifValue): $distribution');
        }
        return distribution;
      }
    }

    // 3. Try keyword-based inference from title and tags
    final title = workout['Title'] as String?;
    final tags = workout['Tags'] as List?;
    if (title != null && title.isNotEmpty) {
      // Combine title with tags for better matching
      var keywords = title;
      if (tags != null && tags.isNotEmpty) {
        keywords += ' ${tags.join(' ')}';
      }
      final distribution = IntensityDistributionMapper.fromWorkoutType(keywords);
      if (distribution != null) {
        if (kDebugMode) {
          print('   ✅ Inferred from title/tags keywords ("$keywords"): $distribution');
        }
        return distribution;
      }
    }

    // 4. No data available
    if (kDebugMode) {
      print('   ⚠️ No intensity distribution data available');
    }
    return null;
  }

  /// Parse TrainingPeaks structured workout JSON
  ///
  /// Structure format example:
  /// ```json
  /// [
  ///   {"Type": "Step", "Length": {"Unit": "Second", "Value": 600},
  ///    "IntensityTarget": {"Unit": "PercentOfFtp", "Value": 0.60}},
  ///   {"Type": "Repetition", "RepeatCount": 4, "Steps": [...]}
  /// ]
  /// ```
  IntensityDistribution? _parseStructuredWorkout(
    String structureJson, {
    AthleteZones? zones,
  }) {
    try {
      final dynamic decoded = json.decode(structureJson);
      if (decoded is! List) return null;

      final segments = <WorkoutSegment>[];
      for (final step in decoded) {
        if (step is Map<String, dynamic>) {
          _parseStep(step, segments, zones: zones);
        }
      }

      if (segments.isEmpty) return null;

      return IntensityDistributionMapper.fromSegments(segments);
    } catch (e) {
      if (kDebugMode) {
        print('   ⚠️ Failed to parse structure JSON: $e');
      }
      return null;
    }
  }

  /// Recursively parse a workout step, handling repetitions
  ///
  /// When [zones] is available, uses actual athlete zone boundaries for
  /// more precise intensity classification. Maximum depth of 10 to prevent
  /// infinite recursion on malformed data.
  void _parseStep(
    Map<String, dynamic> step,
    List<WorkoutSegment> segments, {
    AthleteZones? zones,
    int depth = 0,
  }) {
    // Prevent infinite recursion
    if (depth > 10) return;

    final type = step['Type'] as String?;

    if (type == 'Step') {
      // Single step with duration and intensity
      final length = step['Length'] as Map<String, dynamic>?;
      final intensityTarget = step['IntensityTarget'] as Map<String, dynamic>?;

      if (length == null) return;

      // Parse duration
      final lengthUnit = length['Unit'] as String?;
      final lengthValue = (length['Value'] as num?)?.toDouble() ?? 0;

      int durationSeconds;
      switch (lengthUnit?.toLowerCase()) {
        case 'second':
        case 'seconds':
          durationSeconds = lengthValue.round();
        case 'minute':
        case 'minutes':
          durationSeconds = (lengthValue * 60).round();
        case 'hour':
        case 'hours':
          durationSeconds = (lengthValue * 3600).round();
        default:
          // Assume seconds if not specified
          durationSeconds = lengthValue.round();
      }

      if (durationSeconds <= 0) return;

      // Parse intensity - use actual zones when available
      IntensityZone zone = IntensityZone.conversational; // Default
      if (intensityTarget != null) {
        final intensityUnit = intensityTarget['Unit'] as String?;
        final intensityValue = (intensityTarget['Value'] as num?)?.toDouble() ?? 0;

        zone = _classifyIntensity(
          unit: intensityUnit,
          value: intensityValue,
          zones: zones,
        );
      }

      segments.add(WorkoutSegment(
        durationSeconds: durationSeconds,
        zone: zone,
      ));
    } else if (type == 'Repetition') {
      // Repeated block of steps
      final repeatCount = (step['RepeatCount'] as num?)?.toInt() ?? 1;
      final steps = step['Steps'] as List?;

      if (steps == null || steps.isEmpty) return;

      // Parse inner steps repeatCount times
      for (var i = 0; i < repeatCount; i++) {
        for (final innerStep in steps) {
          if (innerStep is Map<String, dynamic>) {
            _parseStep(innerStep, segments, zones: zones, depth: depth + 1);
          }
        }
      }
    }
  }

  /// Classify workout step intensity into our 3-zone model
  ///
  /// When [zones] is available, uses the athlete's actual FTP and maxHR
  /// thresholds for zone classification. Otherwise falls back to standard
  /// percentage-based thresholds.
  IntensityZone _classifyIntensity({
    required String? unit,
    required double value,
    AthleteZones? zones,
  }) {
    switch (unit?.toLowerCase()) {
      case 'percentofftp':
      case 'percentftp':
        // When we have actual FTP from zones, we can use it for context logging
        // but the percentage-based classification remains the same
        return IntensityDistributionMapper.ftpToZone(value);

      case 'percentofmax':
      case 'percentmaxhr':
      case 'percentofmaxhr':
        // When zones have actual maxHR, we could refine boundaries
        // but standard HR zone thresholds work well universally
        return IntensityDistributionMapper.maxHrToZone(value);

      case 'rpe':
        return IntensityDistributionMapper.rpeToZone(value.round());

      default:
        // If value looks like a percentage (0-1 range), treat as FTP
        if (value > 0 && value <= 1.5) {
          return IntensityDistributionMapper.ftpToZone(value);
        }
        return IntensityZone.conversational;
    }
  }
}
