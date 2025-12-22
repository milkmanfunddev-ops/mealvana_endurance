/// Sensible defaults for Final Surge workouts with missing data
///
/// These defaults are applied when Final Surge API returns workouts
/// without distance, duration, or pace information.
///
/// Defaults were chosen based on:
/// - Average beginner/recreational athlete capabilities
/// - Safe values that won't generate excessive nutrition recommendations
/// - Reasonable starting points for nutrition plan generation
library;

/// Default values for Final Surge workout imports
class FinalSurgeDefaults {
  FinalSurgeDefaults._(); // Private constructor - static only

  // ===========================================================================
  // RUNNING DEFAULTS
  // ===========================================================================

  /// Default running distance when not specified (miles)
  static const double runningDistanceMiles = 3.0;

  /// Default running duration when not specified (minutes)
  static const int runningDurationMinutes = 30;

  /// Default running pace when not specified (minutes per mile)
  /// 10:00/mile = 6 mph = comfortable jog
  static const double runningPaceMinPerMile = 10.0;

  // ===========================================================================
  // CYCLING DEFAULTS
  // ===========================================================================

  /// Default cycling distance when not specified (miles)
  static const double cyclingDistanceMiles = 10.0;

  /// Default cycling duration when not specified (minutes)
  static const int cyclingDurationMinutes = 45;

  /// Default cycling speed when not specified (mph)
  /// 13.3 mph = moderate recreational pace
  static const double cyclingSpeedMph = 13.3;

  // ===========================================================================
  // SWIMMING DEFAULTS
  // ===========================================================================

  /// Default swimming distance when not specified (METERS - industry standard)
  static const double swimmingDistanceMeters = 1000.0;

  /// Default swimming duration when not specified (minutes)
  static const int swimmingDurationMinutes = 30;

  /// Default swimming pace when not specified (seconds per 100m)
  /// 180 sec/100m = 3:00/100m = relaxed/beginner pace
  static const int swimmingPacePer100mSeconds = 180;

  // ===========================================================================
  // CONVERSION HELPERS
  // ===========================================================================

  /// Yards to meters conversion factor
  static const double yardsToMeters = 0.9144;

  /// Miles to kilometers conversion factor
  static const double milesToKm = 1.60934;

  /// Kilometers to miles conversion factor
  static const double kmToMiles = 0.621371;
}
