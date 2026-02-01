/// Final Surge workout data transformer
///
/// Transforms Final Surge API workout responses into Mealvana Activity models.
/// Handles pace parsing, unit conversion, and sensible defaults.
///
/// Key transformations:
/// - PlannedTime is in SECONDS, convert to minutes
/// - Pace info is in WorkoutDescription as "@ 9:12 - 10:01" format
/// - Walk workouts map to ActivityType.running with IntensityLevel.easy
/// - Swimming distance stored in meters
/// - Missing data gets sensible defaults
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../../nutrition_plan/domain/intensity_distribution.dart';
import '../domain/final_surge_defaults.dart';
import '../domain/intensity_distribution_mapper.dart';

/// Result of transforming a Final Surge workout
/// Includes Activity fields plus sync metadata (for Phase 1 schema additions)
class FinalSurgeTransformResult {
  const FinalSurgeTransformResult({
    required this.activity,
    required this.syncedFromProvider,
    required this.providerWorkoutId,
    this.providerWorkoutUrl,
    required this.lastSyncedAt,
    this.workoutSubtype,
    this.paceMinMinutesPerMile,
    this.paceMaxMinutesPerMile,
    this.distanceMeters,
    this.intensityDistribution,
  });

  /// The transformed Activity object
  final Activity activity;

  /// Provider name (always 'final_surge')
  final String syncedFromProvider;

  /// Unique workout ID from provider (WorkoutKey)
  final String providerWorkoutId;

  /// URL to view workout in Final Surge
  final String? providerWorkoutUrl;

  /// When this sync occurred
  final DateTime lastSyncedAt;

  /// Workout subtype from Final Surge (e.g., "Tempo", "Long Run", "Walk")
  final String? workoutSubtype;

  /// Minimum pace for range (e.g., 9.2 for "9:12-10:01")
  final double? paceMinMinutesPerMile;

  /// Maximum pace for range
  final double? paceMaxMinutesPerMile;

  /// Swimming distance in meters (for swimming workouts)
  final double? distanceMeters;

  /// Inferred intensity distribution from workout metadata
  final IntensityDistribution? intensityDistribution;
}

/// Transforms Final Surge workouts to Mealvana Activities
class FinalSurgeTransformer {
  const FinalSurgeTransformer();

  static const _uuid = Uuid();

  /// Supported workout types that we import
  static const supportedTypes = ['Run', 'Walk', 'Bike', 'Swim'];

  /// Transform a Final Surge workout JSON to a Mealvana Activity
  ///
  /// Returns null if the workout type is not supported (e.g., Rest Day).
  /// When [structuredData] is provided (from HasStructuredWorkout=true workouts),
  /// uses it for precise time-weighted intensity distribution calculation.
  FinalSurgeTransformResult? transform(
    Map<String, dynamic> workout,
    String userId, {
    Map<String, dynamic>? structuredData,
  }) {
    if (kDebugMode) {
      print('🔍 FS TRANSFORM DEBUG - Raw workout keys: ${workout.keys.toList()}');
      print('🔍 FS TRANSFORM DEBUG - Raw workout data:');
      workout.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          print('   $key: $value');
        }
      });
    }

    final workoutTypeName = workout['WorkoutTypeName'] as String?;

    // Filter out unsupported workout types
    if (workoutTypeName == null || !supportedTypes.contains(workoutTypeName)) {
      return null;
    }

    final activityType = _mapActivityType(workoutTypeName);
    final isWalk = workoutTypeName == 'Walk';
    final now = DateTime.now();

    // Get duration (PlannedTime is in SECONDS)
    final durationMinutes = _getDurationMinutes(workout, activityType);

    // Get distance
    final distanceMiles = _getDistanceMiles(workout, activityType);

    // Try to get pace from PlannedPace field first (e.g., "5:40-5:55")
    // Then fall back to calculating from distance/time
    // Then fall back to parsing from description
    final paceResult = _parsePace(
      plannedPace: workout['PlannedPace'] as String?,
      plannedPaceType: workout['PlannedPaceType'] as String?,
      description: workout['WorkoutDescription'] as String?,
      activityType: activityType,
      durationMinutes: durationMinutes,
      distanceMiles: distanceMiles,
    );
    final distanceMeters = activityType == ActivityType.swimming
        ? _getDistanceMeters(workout)
        : null;

    // Extract provider info
    final providerWorkoutId = extractWorkoutId(workout);
    final providerWorkoutUrl = workout['WorkoutURL'] as String?;

    // Create the Activity with provider sync fields
    // Use 'planned' status since synced workouts are confirmed by external platform
    final activity = Activity(
      id: _uuid.v4(),
      userId: userId,
      activityType: activityType,
      title: _getTitle(workout, workoutTypeName),
      scheduledDateTime: _parseScheduledDate(workout['WorkoutDate'] as String?),
      status: ActivityStatus.planned,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      paceTargetMinutesPerMile: paceResult.targetPace,
      intensityLevel: isWalk ? IntensityLevel.easy : _inferIntensity(workout),
      swimmingPacePer100mSeconds: activityType == ActivityType.swimming
          ? _calculateSwimmingPace(distanceMeters, durationMinutes)
          : null,
      notes: _cleanDescription(workout['WorkoutDescription'] as String?),
      // Provider sync fields
      syncedFromProvider: 'final_surge',
      providerWorkoutId: providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl,
      lastSyncedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Infer intensity distribution: prefer structured data, fall back to heuristics
    final intensityDistribution = structuredData != null
        ? _parseStructuredWorkout(structuredData) ?? _inferIntensityDistribution(workout)
        : _inferIntensityDistribution(workout);

    return FinalSurgeTransformResult(
      activity: activity,
      syncedFromProvider: 'final_surge',
      providerWorkoutId: providerWorkoutId,
      providerWorkoutUrl: providerWorkoutUrl,
      lastSyncedAt: now,
      workoutSubtype: isWalk ? 'Walk' : workout['WorkoutSubTypeName'] as String?,
      paceMinMinutesPerMile: paceResult.minPace,
      paceMaxMinutesPerMile: paceResult.maxPace,
      distanceMeters: distanceMeters,
      intensityDistribution: intensityDistribution,
    );
  }

  /// Extract workout ID from workout data
  String extractWorkoutId(Map<String, dynamic> workout) {
    // WorkoutKey is the primary ID in the API
    final workoutKey = workout['WorkoutKey'] as String?;
    if (workoutKey != null && workoutKey.isNotEmpty) {
      return workoutKey;
    }

    // Fallback: extract from URL if WorkoutKey not present
    final url = workout['WorkoutURL'] as String?;
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        return uri.queryParameters['id'] ?? url.hashCode.toString();
      }
    }

    // Last resort: use hash of the workout date + type
    final date = workout['WorkoutDate'] ?? '';
    final type = workout['WorkoutTypeName'] ?? '';
    return '${date}_$type'.hashCode.toString();
  }

  /// Map Final Surge workout type to Mealvana ActivityType
  ActivityType _mapActivityType(String workoutTypeName) {
    switch (workoutTypeName.toLowerCase()) {
      case 'run':
      case 'walk': // Walk maps to running with easy intensity
        return ActivityType.running;
      case 'bike':
        return ActivityType.cycling;
      case 'swim':
        return ActivityType.swimming;
      default:
        return ActivityType.running;
    }
  }

  /// Get title from workout, with fallbacks
  String _getTitle(Map<String, dynamic> workout, String workoutTypeName) {
    final title = workout['WorkoutTitle'] as String?;
    if (title != null && title.isNotEmpty) {
      return title;
    }

    final subType = workout['WorkoutSubTypeName'] as String?;
    if (subType != null && subType.isNotEmpty) {
      return '$workoutTypeName - $subType';
    }

    return workoutTypeName;
  }

  /// Parse scheduled date from ISO string
  DateTime _parseScheduledDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  /// Get duration in minutes (PlannedTime is in SECONDS)
  ///
  /// Priority order:
  /// 1. PlannedTime (planned workout duration in seconds)
  /// 2. ActualTime (fallback for completed workouts, also in seconds)
  /// 3. Default value based on activity type
  int _getDurationMinutes(Map<String, dynamic> workout, ActivityType activityType) {
    final plannedTimeSeconds = workout['PlannedTime'];
    final actualTimeSeconds = workout['ActualTime'];

    if (kDebugMode) {
      print('🔍 FS DURATION DEBUG:');
      print('   PlannedTime raw value: $plannedTimeSeconds (type: ${plannedTimeSeconds.runtimeType})');
      print('   ActualTime raw value: $actualTimeSeconds (type: ${actualTimeSeconds.runtimeType})');
    }

    // 1. First try PlannedTime
    if (plannedTimeSeconds != null && plannedTimeSeconds is num && plannedTimeSeconds > 0) {
      if (kDebugMode) {
        print('   ✅ Using PlannedTime: $plannedTimeSeconds seconds → ${(plannedTimeSeconds / 60).round()} minutes');
      }
      return (plannedTimeSeconds / 60).round();
    }

    // 2. Fallback to ActualTime (for completed workouts)
    if (actualTimeSeconds != null && actualTimeSeconds is num && actualTimeSeconds > 0) {
      if (kDebugMode) {
        print('   ℹ️ Using ActualTime as fallback: $actualTimeSeconds seconds → ${(actualTimeSeconds / 60).round()} minutes');
      }
      return (actualTimeSeconds / 60).round();
    }

    // 3. No duration data available - use defaults
    if (kDebugMode) {
      print('   ⚠️ No duration data available, using default for $activityType');
    }
    switch (activityType) {
      case ActivityType.running:
        return FinalSurgeDefaults.runningDurationMinutes;
      case ActivityType.cycling:
        return FinalSurgeDefaults.cyclingDurationMinutes;
      case ActivityType.swimming:
        return FinalSurgeDefaults.swimmingDurationMinutes;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        // Multi-sport and brick default to running for now
        return FinalSurgeDefaults.runningDurationMinutes;
    }
  }

  /// Get distance in miles (handles unit conversion)
  ///
  /// Priority order:
  /// 1. PlannedDistance (with PlannedDistanceType for unit conversion)
  /// 2. ActualDistanceMeters (fallback for completed workouts)
  /// 3. Default value based on activity type
  double? _getDistanceMiles(Map<String, dynamic> workout, ActivityType activityType) {
    // Swimming uses meters, not miles
    if (activityType == ActivityType.swimming) {
      return null;
    }

    final plannedDistance = workout['PlannedDistance'];
    final distanceType = workout['PlannedDistanceType'] as String?;
    final actualDistanceMeters = workout['ActualDistanceMeters'];

    if (kDebugMode) {
      print('🔍 FS DISTANCE DEBUG:');
      print('   PlannedDistance raw value: $plannedDistance (type: ${plannedDistance.runtimeType})');
      print('   PlannedDistanceType: $distanceType');
      print('   ActualDistanceMeters raw value: $actualDistanceMeters (type: ${actualDistanceMeters.runtimeType})');
      // Also print all workout keys that contain 'distance' or 'Distance'
      final distanceKeys = workout.keys.where((k) =>
        k.toString().toLowerCase().contains('distance'));
      print('   All distance-related keys: $distanceKeys');
      for (final key in distanceKeys) {
        print('   $key: ${workout[key]}');
      }
    }

    // 1. First try PlannedDistance (planned workout data)
    if (plannedDistance != null && plannedDistance is num && plannedDistance > 0) {
      if (kDebugMode) {
        print('   ✅ Using PlannedDistance: $plannedDistance $distanceType');
      }
      switch (distanceType?.toLowerCase()) {
        case 'mi':
          return plannedDistance.toDouble();
        case 'km':
          return plannedDistance * FinalSurgeDefaults.kmToMiles;
        case 'm':
          // Meters to miles (unusual for running/cycling)
          return plannedDistance / 1609.34;
        default:
          // Assume miles if not specified
          return plannedDistance.toDouble();
      }
    }

    // 2. Fallback to ActualDistanceMeters (for completed workouts)
    // This is important because completed workouts may not have PlannedDistance
    // but will have ActualDistanceMeters from GPS/device sync
    if (actualDistanceMeters != null && actualDistanceMeters is num && actualDistanceMeters > 0) {
      if (kDebugMode) {
        print('   ℹ️ Using ActualDistanceMeters as fallback: $actualDistanceMeters m → ${actualDistanceMeters / 1609.34} mi');
      }
      // ActualDistanceMeters is ALWAYS in meters - convert to miles
      return actualDistanceMeters / 1609.34;
    }

    // 3. No distance data available - use defaults
    if (kDebugMode) {
      print('   ⚠️ No distance data available, using default for $activityType');
    }
    switch (activityType) {
      case ActivityType.running:
        return FinalSurgeDefaults.runningDistanceMiles;
      case ActivityType.cycling:
        return FinalSurgeDefaults.cyclingDistanceMiles;
      case ActivityType.swimming:
        return null; // Swimming uses meters
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        // Multi-sport and brick default to running for now
        return FinalSurgeDefaults.runningDistanceMiles;
    }
  }

  /// Get distance in meters (for swimming)
  ///
  /// Priority order:
  /// 1. PlannedDistance (with PlannedDistanceType for unit conversion)
  /// 2. ActualDistanceMeters (fallback for completed workouts)
  /// 3. Default swimming distance
  double? _getDistanceMeters(Map<String, dynamic> workout) {
    final plannedDistance = workout['PlannedDistance'];
    final distanceType = workout['PlannedDistanceType'] as String?;
    final actualDistanceMeters = workout['ActualDistanceMeters'];

    // 1. First try PlannedDistance
    if (plannedDistance != null && plannedDistance is num && plannedDistance > 0) {
      switch (distanceType?.toLowerCase()) {
        case 'm':
          return plannedDistance.toDouble();
        case 'yd':
          return plannedDistance * FinalSurgeDefaults.yardsToMeters;
        case 'km':
          return plannedDistance * 1000;
        case 'mi':
          return plannedDistance * 1609.34;
        default:
          // Assume meters for swimming if not specified
          return plannedDistance.toDouble();
      }
    }

    // 2. Fallback to ActualDistanceMeters (for completed workouts)
    if (actualDistanceMeters != null && actualDistanceMeters is num && actualDistanceMeters > 0) {
      // ActualDistanceMeters is ALWAYS in meters
      return actualDistanceMeters.toDouble();
    }

    // 3. Use default
    return FinalSurgeDefaults.swimmingDistanceMeters;
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
    final subType = (workout['WorkoutSubTypeName'] as String?)?.toLowerCase();
    final isRace = workout['WorkoutRace'] == true;

    if (isRace) return IntensityLevel.race;

    if (subType != null) {
      if (subType.contains('easy') || subType.contains('recovery')) {
        return IntensityLevel.easy;
      }
      if (subType.contains('tempo') || subType.contains('threshold')) {
        return IntensityLevel.hard;
      }
      if (subType.contains('interval') || subType.contains('speed')) {
        return IntensityLevel.hard;
      }
      if (subType.contains('long')) {
        return IntensityLevel.moderate;
      }
    }

    // Default to moderate
    return IntensityLevel.moderate;
  }

  /// Clean description by removing pace info that we've already extracted
  String? _cleanDescription(String? description) {
    if (description == null || description.isEmpty) return null;

    // Remove the @ pace line at the beginning
    var cleaned = description.replaceFirst(RegExp(r'^@\s*[\d:]+(?:\s*-\s*[\d:]+)?\s*\n*'), '');
    cleaned = cleaned.trim();

    return cleaned.isEmpty ? null : cleaned;
  }

  /// Parse pace from PlannedPace field, calculate from distance/time, or parse from description
  ///
  /// Priority:
  /// 1. PlannedPace field (e.g., "5:40-5:55" with PlannedPaceType "min/mi")
  /// 2. Calculate from distance and duration (PlannedTime/PlannedDistance or Actual*)
  /// 3. Description parsing (e.g., "@ 9:12 - 10:01" format)
  /// 4. Default pace for the activity type
  _PaceParseResult _parsePace({
    String? plannedPace,
    String? plannedPaceType,
    String? description,
    required ActivityType activityType,
    int? durationMinutes,
    double? distanceMiles,
  }) {
    // 1. First try PlannedPace field if available
    if (plannedPace != null && plannedPace.isNotEmpty) {
      final result = _parsePlannedPaceField(plannedPace, plannedPaceType);
      if (result.targetPace != null) {
        if (kDebugMode) {
          print('🔍 FS PACE DEBUG: Using PlannedPace field: ${result.targetPace} min/mi');
        }
        return result;
      }
    }

    // 2. Try parsing from description (may contain "@ 8:00" or "@ 9:12 - 10:01")
    final hasPacePattern = description != null && RegExp(r'@\s*\d+:\d+').hasMatch(description);
    if (hasPacePattern) {
      final descriptionResult = _parsePaceFromDescription(description, activityType);
      if (descriptionResult.targetPace != null) {
        if (kDebugMode) {
          print('🔍 FS PACE DEBUG: Using pace from description: ${descriptionResult.targetPace} min/mi');
        }
        return descriptionResult;
      }
    }

    // 3. Calculate pace from distance and duration if both are available
    final calculatedPace = _calculatePaceFromDistanceAndTime(
      durationMinutes: durationMinutes,
      distanceMiles: distanceMiles,
      activityType: activityType,
    );
    if (calculatedPace != null) {
      if (kDebugMode) {
        print('🔍 FS PACE DEBUG: Calculated pace from distance/time: $calculatedPace min/mi');
        print('   (duration: $durationMinutes min, distance: $distanceMiles mi)');
      }
      return _PaceParseResult(targetPace: calculatedPace);
    }

    // 4. Fall back to default pace for activity type
    if (kDebugMode) {
      print('🔍 FS PACE DEBUG: Using default pace for $activityType');
    }
    return _parsePaceFromDescription(description, activityType);
  }

  /// Calculate pace (min/mile) from duration and distance
  ///
  /// Returns null if calculation is not possible (missing or invalid data)
  double? _calculatePaceFromDistanceAndTime({
    int? durationMinutes,
    double? distanceMiles,
    required ActivityType activityType,
  }) {
    // Only calculate for running/walking - cycling uses different metrics
    if (activityType != ActivityType.running) {
      return null;
    }

    // Need both duration and distance to calculate
    if (durationMinutes == null || durationMinutes <= 0) {
      return null;
    }
    if (distanceMiles == null || distanceMiles <= 0) {
      return null;
    }

    // Calculate pace: minutes per mile = total minutes / total miles
    final pace = durationMinutes / distanceMiles;

    // Sanity check: pace should be reasonable (between 4:00 and 20:00 min/mile)
    if (pace < 4.0 || pace > 20.0) {
      if (kDebugMode) {
        print('   ⚠️ Calculated pace $pace min/mi is outside reasonable range (4-20), ignoring');
      }
      return null;
    }

    return pace;
  }

  /// Parse the PlannedPace field from Final Surge API
  ///
  /// Format examples: "5:40", "5:40-5:55", "7:30 min/mi"
  _PaceParseResult _parsePlannedPaceField(String paceStr, String? paceType) {
    // Clean up the pace string - remove any "min/mi" or "min/km" suffix
    var cleanPace = paceStr.replaceAll(RegExp(r'\s*(min/mi|min/km)'), '').trim();

    // Check if it's a range (e.g., "5:40-5:55")
    if (cleanPace.contains('-')) {
      final parts = cleanPace.split('-');
      if (parts.length == 2) {
        final pace1 = _parsePaceString(parts[0].trim());
        final pace2 = _parsePaceString(parts[1].trim());

        // Convert from min/km to min/mi if needed
        final isKmPace = paceType?.toLowerCase().contains('km') == true;
        final multiplier = isKmPace ? 1.60934 : 1.0;

        final convertedPace1 = pace1 * multiplier;
        final convertedPace2 = pace2 * multiplier;

        final minPace = convertedPace1 < convertedPace2 ? convertedPace1 : convertedPace2;
        final maxPace = convertedPace1 > convertedPace2 ? convertedPace1 : convertedPace2;
        final midpoint = (minPace + maxPace) / 2;

        return _PaceParseResult(
          targetPace: midpoint,
          minPace: minPace,
          maxPace: maxPace,
        );
      }
    }

    // Single pace value
    final pace = _parsePaceString(cleanPace);
    if (pace > 0) {
      // Convert from min/km to min/mi if needed
      final isKmPace = paceType?.toLowerCase().contains('km') == true;
      final convertedPace = isKmPace ? pace * 1.60934 : pace;

      return _PaceParseResult(targetPace: convertedPace);
    }

    return const _PaceParseResult();
  }

  /// Parse pace from workout description
  ///
  /// Final Surge stores pace in WorkoutDescription as "@ 9:12 - 10:01" format
  _PaceParseResult _parsePaceFromDescription(String? description, ActivityType activityType) {
    if (description == null || description.isEmpty) {
      return _PaceParseResult(
        targetPace: activityType == ActivityType.running
            ? FinalSurgeDefaults.runningPaceMinPerMile
            : null,
      );
    }

    // Look for pace pattern: "@ 8:00" or "@ 9:12 - 10:01" or "@ 8:30-9:30"
    final pacePattern = RegExp(r'@\s*([\d]+:[\d]+)(?:\s*-\s*([\d]+:[\d]+))?');
    final match = pacePattern.firstMatch(description);

    if (match == null) {
      return _PaceParseResult(
        targetPace: activityType == ActivityType.running
            ? FinalSurgeDefaults.runningPaceMinPerMile
            : null,
      );
    }

    final pace1Str = match.group(1);
    final pace2Str = match.group(2);

    if (pace1Str == null) {
      return _PaceParseResult(
        targetPace: activityType == ActivityType.running
            ? FinalSurgeDefaults.runningPaceMinPerMile
            : null,
      );
    }

    final pace1 = _parsePaceString(pace1Str);

    // If no second pace, it's a single pace value
    if (pace2Str == null) {
      return _PaceParseResult(targetPace: pace1);
    }

    // It's a range
    final pace2 = _parsePaceString(pace2Str);
    final minPace = pace1 < pace2 ? pace1 : pace2;
    final maxPace = pace1 > pace2 ? pace1 : pace2;
    final midpoint = (minPace + maxPace) / 2;

    return _PaceParseResult(
      targetPace: midpoint,
      minPace: minPace,
      maxPace: maxPace,
    );
  }

  /// Parse pace string "8:30" to decimal minutes (8.5)
  double _parsePaceString(String pace) {
    final parts = pace.trim().split(':');
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return minutes + (seconds / 60);
  }

  // ===========================================================================
  // Intensity Distribution Inference
  // ===========================================================================

  /// Infer intensity distribution from workout metadata
  ///
  /// Priority order:
  /// 1. Check WorkoutRace flag → race pattern (10/30/60)
  /// 2. Match WorkoutSubTypeName keywords → heuristic pattern
  /// 3. Match WorkoutTitle keywords → heuristic pattern
  /// 4. Return null if no data available
  IntensityDistribution? _inferIntensityDistribution(Map<String, dynamic> workout) {
    if (kDebugMode) {
      print('🔍 FS INTENSITY DEBUG - Checking for workout intensity hints');
    }

    // 1. Check if it's a race workout
    final isRace = workout['WorkoutRace'] == true;
    if (isRace) {
      if (kDebugMode) {
        print('   ✅ WorkoutRace=true: Using race pattern');
      }
      return IntensityDistributionMapper.patternRace;
    }

    // 2. Try to match WorkoutSubTypeName
    final subTypeName = workout['WorkoutSubTypeName'] as String?;
    if (subTypeName != null && subTypeName.isNotEmpty) {
      final distribution = IntensityDistributionMapper.fromWorkoutType(subTypeName);
      if (distribution != null) {
        if (kDebugMode) {
          print('   ✅ Matched subtype "$subTypeName": $distribution');
        }
        return distribution;
      }
    }

    // 3. Try to match WorkoutTitle keywords
    final title = workout['WorkoutTitle'] as String?;
    if (title != null && title.isNotEmpty) {
      final distribution = IntensityDistributionMapper.fromWorkoutType(title);
      if (distribution != null) {
        if (kDebugMode) {
          print('   ✅ Matched title "$title": $distribution');
        }
        return distribution;
      }
    }

    // 4. No data available
    if (kDebugMode) {
      print('   ⚠️ No intensity distribution hints available');
    }
    return null;
  }

  // ===========================================================================
  // Structured Workout Parsing (Final Surge json_fs_v1 format)
  // ===========================================================================

  /// Parse Final Surge structured workout JSON into an intensity distribution
  ///
  /// Final Surge structured workouts use these step types:
  /// - WorkoutStep: single step with Duration and IntensityTarget
  /// - WorkoutRampStep: ramp from one intensity to another
  /// - WorkoutRepeatStep: repeated block of steps
  ///
  /// IntensityTarget uses values like:
  /// - PercentHRMax: 0.0-1.0 (e.g., 0.75 = 75% maxHR)
  /// - PercentFTP: 0.0-1.5 (e.g., 1.05 = 105% FTP)
  /// - RPE: 1-10
  IntensityDistribution? _parseStructuredWorkout(Map<String, dynamic> data) {
    try {
      // The steps may be at root level or under a 'Steps' key
      final stepsRaw = data['Steps'] as List? ??
          data['steps'] as List? ??
          data['WorkoutSteps'] as List?;

      if (stepsRaw == null || stepsRaw.isEmpty) return null;

      final segments = <WorkoutSegment>[];
      for (final step in stepsRaw) {
        if (step is Map<String, dynamic>) {
          _parseFsStep(step, segments);
        }
      }

      if (segments.isEmpty) return null;

      final distribution = IntensityDistributionMapper.fromSegments(segments);
      if (kDebugMode && distribution != null) {
        print('   📋 Structured workout parsed: $distribution');
      }
      return distribution;
    } catch (e) {
      if (kDebugMode) {
        print('   ⚠️ Failed to parse structured workout: $e');
      }
      return null;
    }
  }

  /// Parse a single Final Surge workout step recursively
  void _parseFsStep(
    Map<String, dynamic> step,
    List<WorkoutSegment> segments, [
    int depth = 0,
  ]) {
    if (depth > 10) return; // Prevent infinite recursion

    final type = step['Type'] as String? ??
        step['type'] as String? ??
        step['StepType'] as String?;

    switch (type?.toLowerCase()) {
      case 'workoutstep':
      case 'step':
        _parseFsSingleStep(step, segments);

      case 'workoutrampstep':
      case 'ramp':
      case 'rampstep':
        // Ramp: treat as midpoint intensity for the full duration
        _parseFsRampStep(step, segments);

      case 'workoutrepeatstep':
      case 'repeat':
      case 'repeatstep':
        final repeatCount = (step['RepeatCount'] as num?)?.toInt() ??
            (step['repeatCount'] as num?)?.toInt() ??
            1;
        final innerSteps = step['Steps'] as List? ?? step['steps'] as List? ?? [];

        for (var i = 0; i < repeatCount; i++) {
          for (final innerStep in innerSteps) {
            if (innerStep is Map<String, dynamic>) {
              _parseFsStep(innerStep, segments, depth + 1);
            }
          }
        }

      default:
        // Try as a simple step anyway
        _parseFsSingleStep(step, segments);
    }
  }

  /// Parse a single Final Surge step
  void _parseFsSingleStep(
    Map<String, dynamic> step,
    List<WorkoutSegment> segments,
  ) {
    // Parse duration
    final durationSeconds = _parseFsDuration(step);
    if (durationSeconds <= 0) return;

    // Parse intensity
    final zone = _parseFsIntensity(step);

    segments.add(WorkoutSegment(
      durationSeconds: durationSeconds,
      zone: zone,
    ));
  }

  /// Parse a ramp step (treat as midpoint intensity)
  void _parseFsRampStep(
    Map<String, dynamic> step,
    List<WorkoutSegment> segments,
  ) {
    final durationSeconds = _parseFsDuration(step);
    if (durationSeconds <= 0) return;

    // Use midpoint of start and end intensity
    final startIntensity = step['IntensityTargetStart'] as Map<String, dynamic>?;
    final endIntensity = step['IntensityTargetEnd'] as Map<String, dynamic>?;

    IntensityZone zone;
    if (startIntensity != null && endIntensity != null) {
      final startValue = (startIntensity['Value'] as num?)?.toDouble() ?? 0;
      final endValue = (endIntensity['Value'] as num?)?.toDouble() ?? 0;
      final midValue = (startValue + endValue) / 2;
      final unit = startIntensity['Unit'] as String? ?? 'PercentFTP';
      zone = _classifyFsIntensity(unit, midValue);
    } else {
      zone = _parseFsIntensity(step);
    }

    segments.add(WorkoutSegment(
      durationSeconds: durationSeconds,
      zone: zone,
    ));
  }

  /// Parse duration from a Final Surge step
  int _parseFsDuration(Map<String, dynamic> step) {
    // Try Duration object first
    final duration = step['Duration'] as Map<String, dynamic>? ??
        step['duration'] as Map<String, dynamic>? ??
        step['Length'] as Map<String, dynamic>?;

    if (duration != null) {
      final unit = (duration['Unit'] as String?)?.toLowerCase();
      final value = (duration['Value'] as num?)?.toDouble() ?? 0;

      switch (unit) {
        case 'second':
        case 'seconds':
          return value.round();
        case 'minute':
        case 'minutes':
          return (value * 60).round();
        case 'hour':
        case 'hours':
          return (value * 3600).round();
        default:
          return value.round(); // assume seconds
      }
    }

    // Try flat fields
    final seconds = step['DurationSeconds'] as num?;
    if (seconds != null) return seconds.round();

    final minutes = step['DurationMinutes'] as num?;
    if (minutes != null) return (minutes * 60).round();

    return 0;
  }

  /// Parse intensity from a Final Surge step
  IntensityZone _parseFsIntensity(Map<String, dynamic> step) {
    final target = step['IntensityTarget'] as Map<String, dynamic>? ??
        step['intensityTarget'] as Map<String, dynamic>?;

    if (target == null) return IntensityZone.conversational;

    final unit = target['Unit'] as String? ?? target['unit'] as String? ?? '';
    final value = (target['Value'] as num?)?.toDouble() ??
        (target['value'] as num?)?.toDouble() ??
        0;

    return _classifyFsIntensity(unit, value);
  }

  /// Classify intensity value into our 3-zone model
  IntensityZone _classifyFsIntensity(String unit, double value) {
    switch (unit.toLowerCase()) {
      case 'percenthrmax':
      case 'percentofmaxhr':
      case 'percentmaxhr':
        return IntensityDistributionMapper.maxHrToZone(value);
      case 'percentftp':
      case 'percentofftp':
        return IntensityDistributionMapper.ftpToZone(value);
      case 'rpe':
        return IntensityDistributionMapper.rpeToZone(value.round());
      default:
        // If it looks like a percentage, treat as FTP
        if (value > 0 && value <= 1.5) {
          return IntensityDistributionMapper.ftpToZone(value);
        }
        return IntensityZone.conversational;
    }
  }
}

/// Result of parsing pace from description
class _PaceParseResult {
  const _PaceParseResult({
    this.targetPace,
    this.minPace,
    this.maxPace,
  });

  final double? targetPace;
  final double? minPace;
  final double? maxPace;
}
