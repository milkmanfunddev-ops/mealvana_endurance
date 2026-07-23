import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';

/// Result of transforming a single VDOT workout to a Mealvana Activity.
class VdotTransformResult {
  const VdotTransformResult({
    required this.activity,
    required this.providerWorkoutId,
    required this.lastSyncedAt,
    this.workoutSubtype,
  });

  final Activity activity;
  final String providerWorkoutId;
  final DateTime lastSyncedAt;
  final String? workoutSubtype;
}

/// Transforms VDOT (V.O2) workouts to Mealvana Activities.
///
/// VDOT documents three event types:
///  - `easyPace` — easy run
///  - `qualitySession` — quality / interval workout
///  - `crossTraining` — cross-training (bike, swim, strength, etc.)
///
/// Schema reference: https://github.com/VDOT-O2/V.O2-API/wiki
class VdotTransformer {
  const VdotTransformer();

  static const _uuid = Uuid();
  static const _metersPerMile = 1609.344;

  /// Transform a single VdotWorkout JSON payload to an [Activity].
  ///
  /// Returns null when the workout cannot be represented (e.g., missing
  /// eventId, unsupported status, or unmapped cross-training type).
  VdotTransformResult? transform(Map<String, dynamic> workout, String userId) {
    final eventId = workout['eventId'] as String?;
    if (eventId == null || eventId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ [vdot] Skipping workout with no eventId');
      }
      return null;
    }

    final status = _parseStatus(workout['status'] as String?);
    if (status == null) {
      // 'skipped' workouts → ignore. We only import planned/completed/modified.
      return null;
    }

    final eventType = workout['eventType'] as String?;
    final crossTrainingType = workout['crossTrainingType'] as String?;
    final crossTrainingEffort = workout['crossTrainingEffort'] as String?;

    final activityType = _mapActivityType(eventType, crossTrainingType);
    if (activityType == null) {
      // Unsupported cross-training type (e.g. strength, yoga) — skip.
      return null;
    }

    final scheduledDateTime = _parseLocalDateTime(
      workout['eventDate'] as String?,
    );
    if (scheduledDateTime == null) {
      if (kDebugMode) {
        print(
          '⚠️ [vdot] Skipping workout with unparseable eventDate: ${workout['eventDate']}',
        );
      }
      return null;
    }

    final plannedTime = (workout['plannedTime'] as num?)?.toInt();
    final plannedDistance = (workout['plannedDistance'] as num?)?.toDouble();

    final durationMinutes = plannedTime != null && plannedTime > 0
        ? (plannedTime / 60).round()
        : null;
    final distanceMiles = plannedDistance != null && plannedDistance > 0
        ? plannedDistance / _metersPerMile
        : null;

    final title = _buildTitle(
      workout: workout,
      eventType: eventType,
      crossTrainingType: crossTrainingType,
    );
    final workoutSubtype = _buildSubtype(
      eventType: eventType,
      crossTrainingType: crossTrainingType,
    );

    final intensityLevel = _inferIntensityLevel(
      eventType: eventType,
      crossTrainingEffort: crossTrainingEffort,
    );

    final stepsNote = _renderStepsSummary(workout['steps'] as List?);

    final now = DateTime.now();
    final activity = Activity(
      id: _uuid.v4(),
      userId: userId,
      activityType: activityType,
      title: title,
      scheduledDateTime: scheduledDateTime,
      status: status,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      intensityLevel: intensityLevel,
      notes: stepsNote,
      syncedFromProvider: 'vdot',
      providerWorkoutId: eventId,
      lastSyncedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    return VdotTransformResult(
      activity: activity,
      providerWorkoutId: eventId,
      lastSyncedAt: now,
      workoutSubtype: workoutSubtype,
    );
  }

  /// VDOT's `eventId` is the stable provider workout id.
  String extractWorkoutId(Map<String, dynamic> workout) {
    return workout['eventId'] as String? ?? '';
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  ActivityStatus? _parseStatus(String? raw) {
    switch (raw) {
      case 'planned':
      case 'modified':
        return ActivityStatus.planned;
      case 'completed':
        return ActivityStatus.completed;
      case 'skipped':
        return null;
      default:
        return ActivityStatus.planned;
    }
  }

  /// Map VDOT eventType (+ crossTrainingType) to Mealvana ActivityType.
  /// Returns null for unsupported cross-training kinds we can't currently model.
  ActivityType? _mapActivityType(String? eventType, String? crossTrainingType) {
    switch (eventType) {
      case 'easyPace':
      case 'qualitySession':
        return ActivityType.running;
      case 'crossTraining':
        switch (crossTrainingType) {
          case 'bike':
            return ActivityType.cycling;
          case 'swim':
            return ActivityType.swimming;
          case 'rowing':
          case 'elliptical':
          case 'stepping':
          case 'other':
            return ActivityType.cycling; // closest supported analogue
          case 'strength':
          case 'yoga':
          case 'crossFit':
          default:
            return null; // strength/yoga/etc. have no nutrition mapping yet
        }
      default:
        return ActivityType.running;
    }
  }

  /// VDOT eventDate is tz-naive (e.g. `2024-03-29T00:00:00`). Parse as LOCAL
  /// time — same gotcha as the Garmin matching bug fix from 2026-04-17.
  DateTime? _parseLocalDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Strip any trailing `Z` so DateTime.parse treats it as naive.
    final cleaned = raw.endsWith('Z') ? raw.substring(0, raw.length - 1) : raw;
    try {
      return DateTime.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  String _buildTitle({
    required Map<String, dynamic> workout,
    required String? eventType,
    required String? crossTrainingType,
  }) {
    final raw = (workout['eventName'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    switch (eventType) {
      case 'easyPace':
        return 'Easy Run';
      case 'qualitySession':
        return 'Quality Session';
      case 'crossTraining':
        return crossTrainingType != null && crossTrainingType.isNotEmpty
            ? _humanizeCrossTraining(crossTrainingType)
            : 'Cross Training';
      default:
        return 'Workout';
    }
  }

  String? _buildSubtype({
    required String? eventType,
    required String? crossTrainingType,
  }) {
    switch (eventType) {
      case 'easyPace':
        return 'Easy';
      case 'qualitySession':
        return 'Quality';
      case 'crossTraining':
        return crossTrainingType;
      default:
        return null;
    }
  }

  String _humanizeCrossTraining(String key) {
    switch (key) {
      case 'bike':
        return 'Bike';
      case 'swim':
        return 'Swim';
      case 'strength':
        return 'Strength';
      case 'rowing':
        return 'Rowing';
      case 'yoga':
        return 'Yoga';
      case 'crossFit':
        return 'CrossFit';
      case 'elliptical':
        return 'Elliptical';
      case 'stepping':
        return 'Stairs';
      case 'other':
      default:
        return 'Cross Training';
    }
  }

  IntensityLevel? _inferIntensityLevel({
    required String? eventType,
    required String? crossTrainingEffort,
  }) {
    if (eventType == 'easyPace') return IntensityLevel.easy;
    if (eventType == 'qualitySession') return IntensityLevel.hard;
    switch (crossTrainingEffort) {
      case 'easy':
        return IntensityLevel.easy;
      case 'moderate':
        return IntensityLevel.moderate;
      case 'hard':
        return IntensityLevel.hard;
    }
    return null;
  }

  /// Render the step structure as a human-readable note. VDOT step models are
  /// rich (intervals, repeats, strength) — for the scaffold we collapse them
  /// into a compact textual summary so the data isn't lost on import.
  String? _renderStepsSummary(List? steps) {
    if (steps == null || steps.isEmpty) return null;
    final lines = <String>[];
    for (final raw in steps) {
      if (raw is! Map<String, dynamic>) continue;
      final rendered = _renderStep(raw, depth: 0);
      if (rendered != null) lines.add(rendered);
    }
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  String? _renderStep(Map<String, dynamic> step, {required int depth}) {
    final indent = '  ' * depth;
    final type = step['type'] as String?;
    if (type == 'repeatStep') {
      final repeat = (step['repeatValue'] as num?)?.toInt() ?? 1;
      final inner = <String>[];
      final innerSteps = step['steps'] as List?;
      if (innerSteps != null) {
        for (final raw in innerSteps) {
          if (raw is! Map<String, dynamic>) continue;
          final line = _renderStep(raw, depth: depth + 1);
          if (line != null) inner.add(line);
        }
      }
      return '$indent${repeat}x\n${inner.join('\n')}';
    }
    // Regular step (running or strength)
    final intensity = step['intensity'] as String?;
    final duration = step['duration'] as Map<String, dynamic>?;
    final exerciseName = step['exerciseName'] as String?;
    final pieces = <String>[];
    if (intensity != null) pieces.add(intensity);
    if (duration != null) {
      final durType = duration['type'] as String?;
      final durValue = (duration['value'] as num?)?.toDouble();
      if (durValue != null) {
        if (durType == 'distance') {
          pieces.add('${durValue.toStringAsFixed(0)}m');
        } else if (durType == 'time') {
          pieces.add('${(durValue / 60).toStringAsFixed(1)}min');
        }
      }
    }
    if (exerciseName != null && exerciseName.isNotEmpty) {
      pieces.add(exerciseName);
    }
    if (pieces.isEmpty) return null;
    return '$indent- ${pieces.join(' · ')}';
  }
}
