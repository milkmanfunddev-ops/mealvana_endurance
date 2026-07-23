import 'package:mealvana_endurance/features/nutrition_plan/domain/intensity_distribution.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Predefined workout intensity presets for the estimate mode.
///
/// Each preset maps to a fixed [IntensityDistribution] representing
/// the typical zone distribution for that workout type.
enum WorkoutPreset { easy, long, tempo, intervals, racePace, recovery }

/// Data class providing preset distributions and sport-specific labels.
class WorkoutPresetData {
  WorkoutPresetData._();

  /// Preset intensity distributions for each workout type.
  static const Map<WorkoutPreset, IntensityDistribution> presetDistributions = {
    WorkoutPreset.easy: IntensityDistribution(
      conversationalPct: 90,
      tempoPct: 8,
      allOutPct: 2,
    ),
    WorkoutPreset.long: IntensityDistribution(
      conversationalPct: 80,
      tempoPct: 15,
      allOutPct: 5,
    ),
    WorkoutPreset.tempo: IntensityDistribution(
      conversationalPct: 30,
      tempoPct: 60,
      allOutPct: 10,
    ),
    WorkoutPreset.intervals: IntensityDistribution(
      conversationalPct: 35,
      tempoPct: 25,
      allOutPct: 40,
    ),
    WorkoutPreset.racePace: IntensityDistribution(
      conversationalPct: 15,
      tempoPct: 45,
      allOutPct: 40,
    ),
    WorkoutPreset.recovery: IntensityDistribution(
      conversationalPct: 95,
      tempoPct: 5,
      allOutPct: 0,
    ),
  };

  /// Sport-specific labels for each preset.
  static const Map<ActivityType, Map<WorkoutPreset, String>> sportLabels = {
    ActivityType.running: {
      WorkoutPreset.easy: 'Easy Run',
      WorkoutPreset.long: 'Long Run',
      WorkoutPreset.tempo: 'Tempo Run',
      WorkoutPreset.intervals: 'Intervals',
      WorkoutPreset.racePace: 'Race Pace',
      WorkoutPreset.recovery: 'Recovery Run',
    },
    ActivityType.cycling: {
      WorkoutPreset.easy: 'Easy Ride',
      WorkoutPreset.long: 'Long Ride',
      WorkoutPreset.tempo: 'Tempo Ride',
      WorkoutPreset.intervals: 'Intervals',
      WorkoutPreset.racePace: 'Race Pace',
      WorkoutPreset.recovery: 'Recovery Ride',
    },
    ActivityType.swimming: {
      WorkoutPreset.easy: 'Easy Swim',
      WorkoutPreset.long: 'Long Swim',
      WorkoutPreset.tempo: 'Tempo Swim',
      WorkoutPreset.intervals: 'Intervals',
      WorkoutPreset.racePace: 'Race Pace',
      WorkoutPreset.recovery: 'Recovery Swim',
    },
  };

  /// Returns the label for a preset given the sport type.
  ///
  /// Falls back to running labels if the sport type is not found.
  static String labelFor(ActivityType sportType, WorkoutPreset preset) {
    final labels = sportLabels[sportType] ?? sportLabels[ActivityType.running]!;
    return labels[preset] ?? preset.name;
  }

  /// Finds which preset matches the given distribution, if any.
  ///
  /// Returns `null` if no preset matches exactly.
  static WorkoutPreset? matchingPreset(IntensityDistribution distribution) {
    for (final entry in presetDistributions.entries) {
      if (entry.value == distribution) return entry.key;
    }
    return null;
  }
}
