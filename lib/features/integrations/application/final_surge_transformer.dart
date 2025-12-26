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

import 'package:uuid/uuid.dart';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../domain/final_surge_defaults.dart';

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
}

/// Transforms Final Surge workouts to Mealvana Activities
class FinalSurgeTransformer {
  const FinalSurgeTransformer();

  static const _uuid = Uuid();

  /// Supported workout types that we import
  static const supportedTypes = ['Run', 'Walk', 'Bike', 'Swim'];

  /// Transform a Final Surge workout JSON to a Mealvana Activity
  ///
  /// Returns null if the workout type is not supported (e.g., Rest Day)
  FinalSurgeTransformResult? transform(
    Map<String, dynamic> workout,
    String userId,
  ) {
    final workoutTypeName = workout['WorkoutTypeName'] as String?;

    // Filter out unsupported workout types
    if (workoutTypeName == null || !supportedTypes.contains(workoutTypeName)) {
      return null;
    }

    final activityType = _mapActivityType(workoutTypeName);
    final isWalk = workoutTypeName == 'Walk';
    final now = DateTime.now();

    // Parse pace from description (Final Surge stores pace in description)
    final paceResult = _parsePaceFromDescription(
      workout['WorkoutDescription'] as String?,
      activityType,
    );

    // Get duration (PlannedTime is in SECONDS)
    final durationMinutes = _getDurationMinutes(workout, activityType);

    // Get distance
    final distanceMiles = _getDistanceMiles(workout, activityType);
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
  int _getDurationMinutes(Map<String, dynamic> workout, ActivityType activityType) {
    final plannedTimeSeconds = workout['PlannedTime'];
    if (plannedTimeSeconds != null && plannedTimeSeconds is num && plannedTimeSeconds > 0) {
      return (plannedTimeSeconds / 60).round();
    }

    // Apply sensible defaults based on sport type
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
        // Multi-sport defaults to running for now
        return FinalSurgeDefaults.runningDurationMinutes;
    }
  }

  /// Get distance in miles (handles unit conversion)
  double? _getDistanceMiles(Map<String, dynamic> workout, ActivityType activityType) {
    // Swimming uses meters, not miles
    if (activityType == ActivityType.swimming) {
      return null;
    }

    final distance = workout['PlannedDistance'];
    if (distance == null || distance is! num || distance <= 0) {
      // Apply sensible defaults based on sport type
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
          // Multi-sport defaults to running for now
          return FinalSurgeDefaults.runningDistanceMiles;
      }
    }

    final distanceType = workout['PlannedDistanceType'] as String?;

    switch (distanceType?.toLowerCase()) {
      case 'mi':
        return distance.toDouble();
      case 'km':
        return distance * FinalSurgeDefaults.kmToMiles;
      case 'm':
        // Meters to miles (unusual for running/cycling)
        return distance / 1609.34;
      default:
        // Assume miles if not specified
        return distance.toDouble();
    }
  }

  /// Get distance in meters (for swimming)
  double? _getDistanceMeters(Map<String, dynamic> workout) {
    final distance = workout['PlannedDistance'];
    if (distance == null || distance is! num || distance <= 0) {
      return FinalSurgeDefaults.swimmingDistanceMeters;
    }

    final distanceType = workout['PlannedDistanceType'] as String?;

    switch (distanceType?.toLowerCase()) {
      case 'm':
        return distance.toDouble();
      case 'yd':
        return distance * FinalSurgeDefaults.yardsToMeters;
      case 'km':
        return distance * 1000;
      case 'mi':
        return distance * 1609.34;
      default:
        // Assume meters for swimming if not specified
        return distance.toDouble();
    }
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
