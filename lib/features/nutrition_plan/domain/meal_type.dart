import '../../../shared/domain/activity_type.dart';
import 'intensity_distribution.dart';

/// Internal categorization of timing windows for pre-workout nutrition scaling.
///
/// Not a user-facing selector - derived from the user's selected hours via
/// [MealType.fromHours]. Used to determine protein/fat/sodium/hydration scaling.
///
/// Rachel-corrected v3 algorithm: pre-workout carbs use 1 g/kg per hour directly,
/// but protein, fat, sodium, and hydration scale based on the timing window category.
enum MealType {
  /// >= 2.5 hours before: full meal macros
  /// Protein 0.25 g/kg, fat 0.4 g/kg, full sodium/hydration
  fullMeal,

  /// 1-2.5 hours before: snack macros
  /// Protein 0.15 g/kg, fat 5g fixed, 50% sodium, moderate hydration
  snack,

  /// < 1 hour before: top-up macros
  /// Protein 0g, fat 0g, minimal sodium, 200-300ml fixed hydration
  topUp;

  /// Derives meal type from user's selected hours before workout.
  static MealType fromHours(double hours) {
    if (hours >= 2.5) return MealType.fullMeal;
    if (hours >= 1.0) return MealType.snack;
    return MealType.topUp;
  }
}

/// Recommended hours before exercise based on sport type and intensity classification.
///
/// Intensity classification from IntensityDistribution:
/// - Easy: conversationalPct >= 70
/// - Hard: allOutPct >= 25 OR tempoPct >= 50
/// - Moderate: everything else
///
/// These are pre-filled defaults; user can override based on their schedule.
double recommendedHoursBefore(
  ActivityType sport,
  IntensityDistribution intensity,
) {
  final level = _classifyIntensity(intensity);

  switch (sport) {
    case ActivityType.running:
      switch (level) {
        case _IntensityLevel.easy:
          return 1.5;
        case _IntensityLevel.moderate:
          return 2.5;
        case _IntensityLevel.hard:
          return 3.5;
      }
    case ActivityType.cycling:
      switch (level) {
        case _IntensityLevel.easy:
          return 1.0;
        case _IntensityLevel.moderate:
          return 2.0;
        case _IntensityLevel.hard:
          return 3.0;
      }
    case ActivityType.swimming:
      switch (level) {
        case _IntensityLevel.easy:
          return 1.5;
        case _IntensityLevel.moderate:
          return 2.0;
        case _IntensityLevel.hard:
          return 2.5;
      }
    case ActivityType.brick:
    case ActivityType.triathlon:
    case ActivityType.duathlon:
    case ActivityType.multisport:
      // Multi-sport defaults to running (most conservative)
      switch (level) {
        case _IntensityLevel.easy:
          return 1.5;
        case _IntensityLevel.moderate:
          return 2.5;
        case _IntensityLevel.hard:
          return 3.5;
      }
  }
}

/// Format minutes as a compact recommendation string (e.g., "2h 30m", "1h", "45 min").
String formatRecommendedTime(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  if (rem == 0) return '${hours}h';
  return '${hours}h ${rem}m';
}

enum _IntensityLevel { easy, moderate, hard }

_IntensityLevel _classifyIntensity(IntensityDistribution intensity) {
  if (intensity.conversationalPct >= 70) return _IntensityLevel.easy;
  if (intensity.allOutPct >= 25 || intensity.tempoPct >= 50) {
    return _IntensityLevel.hard;
  }
  return _IntensityLevel.moderate;
}
