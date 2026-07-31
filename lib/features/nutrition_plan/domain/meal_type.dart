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

/// Recommended hours before exercise based on sport type, intensity, and duration.
///
/// Uses a continuous formula that considers both intensity and workout duration:
/// - Weighted intensity: 0.0 (all easy) → 1.0 (all hard)
/// - Duration factor: dead zone below 30 min, scales linearly to 1.0 at 180 min
/// - Combined: duration 60% + intensity 40% (duration matters more)
/// - Sport-specific min/max windows with linear interpolation
/// - Result rounded to nearest 15 minutes (0.25h)
///
/// These are pre-filled defaults; user can override based on their schedule.
double recommendedHoursBefore(
  ActivityType sport,
  IntensityDistribution intensity, {
  int durationMinutes = 90,
}) {
  // Weighted intensity: 0.0 (all easy) → 1.0 (all hard)
  final weightedIntensity =
      (intensity.tempoPct * 0.5 + intensity.allOutPct * 1.0) / 100.0;

  // Duration factor: short workouts need less pre-fueling
  // Dead zone below 30 min, scales linearly to 1.0 at 180 min
  final durationFactor = ((durationMinutes - 30) / 150.0).clamp(0.0, 1.0);

  // Combined factor: duration weighted 60%, intensity 40%
  // Duration matters more: a 45-min easy jog needs far less pre-fueling
  // than a 3-hour easy long run, regardless of intensity
  final combinedFactor = durationFactor * 0.6 + weightedIntensity * 0.4;

  // Sport-specific min/max windows
  final (minHours, maxHours) = switch (sport) {
    ActivityType.running => (0.25, 3.5),
    ActivityType.cycling => (0.25, 3.0),
    ActivityType.swimming => (0.5, 2.5),
    _ => (0.25, 3.5), // brick/triathlon/etc
  };

  // Linear interpolation between min and max
  final hours = minHours + combinedFactor * (maxHours - minHours);

  // Round to nearest 15 minutes (0.25h)
  return (hours * 4).round() / 4.0;
}

/// Format minutes as a compact recommendation string (e.g., "2h 30m", "1h", "45 min").
String formatRecommendedTime(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  if (rem == 0) return '${hours}h';
  return '${hours}h ${rem}m';
}
