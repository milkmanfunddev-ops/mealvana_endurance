/// Sensible defaults for TrainingPeaks workouts with missing data
///
/// These defaults are applied when TrainingPeaks API returns workouts
/// without distance, duration, or pace information.
///
/// CRITICAL DIFFERENCES FROM FINAL SURGE:
/// - TrainingPeaks distance is ALWAYS in METERS (no conversion needed)
/// - TrainingPeaks time is in DECIMAL HOURS (not seconds)
/// - TrainingPeaks does NOT provide pace (calculate from distance/time)
///
/// Defaults were chosen based on:
/// - Average beginner/recreational athlete capabilities
/// - Safe values that won't generate excessive nutrition recommendations
/// - Reasonable starting points for nutrition plan generation
library;

/// Default values for TrainingPeaks workout imports
class TrainingPeaksDefaults {
  TrainingPeaksDefaults._(); // Private constructor - static only

  // ===========================================================================
  // RUNNING DEFAULTS
  // ===========================================================================

  /// Default running distance when not specified (miles)
  static const double runningDistanceMiles = 3.0;

  /// Default running distance when not specified (meters)
  /// 3 miles ≈ 4828 meters
  static const double runningDistanceMeters = 4828.0;

  /// Default running duration when not specified (minutes)
  static const int runningDurationMinutes = 30;

  /// Default running duration when not specified (decimal hours)
  /// 30 minutes = 0.5 hours
  static const double runningDurationHours = 0.5;

  /// Default running pace when not specified (minutes per mile)
  /// 10:00/mile = 6 mph = comfortable jog
  static const double runningPaceMinPerMile = 10.0;

  // ===========================================================================
  // CYCLING DEFAULTS
  // ===========================================================================

  /// Default cycling distance when not specified (miles)
  static const double cyclingDistanceMiles = 10.0;

  /// Default cycling distance when not specified (meters)
  /// 10 miles ≈ 16093 meters
  static const double cyclingDistanceMeters = 16093.0;

  /// Default cycling duration when not specified (minutes)
  static const int cyclingDurationMinutes = 45;

  /// Default cycling duration when not specified (decimal hours)
  /// 45 minutes = 0.75 hours
  static const double cyclingDurationHours = 0.75;

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

  /// Default swimming duration when not specified (decimal hours)
  /// 30 minutes = 0.5 hours
  static const double swimmingDurationHours = 0.5;

  /// Default swimming pace when not specified (seconds per 100m)
  /// 180 sec/100m = 3:00/100m = relaxed/beginner pace
  static const int swimmingPacePer100mSeconds = 180;

  // ===========================================================================
  // CONVERSION HELPERS
  // ===========================================================================

  /// Meters to miles conversion factor
  static const double metersToMiles = 0.000621371;

  /// Miles to meters conversion factor
  static const double milesToMeters = 1609.34;

  /// Yards to meters conversion factor
  static const double yardsToMeters = 0.9144;

  /// Miles to kilometers conversion factor
  static const double milesToKm = 1.60934;

  /// Kilometers to miles conversion factor
  static const double kmToMiles = 0.621371;

  /// Decimal hours to minutes conversion
  static const double hoursToMinutes = 60.0;

  /// Minutes to decimal hours conversion
  static const double minutesToHours = 1 / 60.0;
}
