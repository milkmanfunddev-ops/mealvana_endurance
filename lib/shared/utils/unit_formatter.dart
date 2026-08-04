import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';

class UnitFormatter {
  // Conversion constants
  static const double kMlPerFlOz = 29.5735;
  static const double kFlOzPerMl = 0.033814;
  static const double kKgPerLb = 0.453592;
  static const double kLbPerKg = 2.20462;
  static const double kCmPerInch = 2.54;
  static const double kKmPerMile = 1.60934;
  static const double kMilePerKm = 0.621371;
  static const double kMeterPerFoot = 0.3048;
  static const double kFootPerMeter = 3.28084;

  /// Format a millilitre volume as `mL` or `oz`.
  ///
  /// `useMetric` is required, and named to match every other method here. The
  /// previous signature took *both* `useImperial` and `useMetric` with `false`
  /// defaults and resolved `useMetric || !useImperial`, so the natural-looking
  /// `formatFluids(ml, useMetric: false)` returned metric — the exact opposite
  /// of what the caller asked for.
  static String formatFluids(double ml, {required bool useMetric}) {
    if (!useMetric) {
      final oz = ml * kFlOzPerMl;
      return '${oz.round()} oz';
    }
    return '${ml.round()} mL';
  }

  static String formatDistance(double miles, {required DistanceUnit unit}) {
    if (unit == DistanceUnit.kilometers) {
      // 1 mile = 1.60934 km
      final km = miles * 1.60934;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${miles.toStringAsFixed(1)} mi';
  }

  /// Format a fractional minute count as `M:SS`.
  ///
  /// Rounds to whole seconds *first* and then splits, so a value that rounds up
  /// to a full minute carries instead of overflowing the seconds field. Taking
  /// `floor()` for the minutes and rounding `(value - minutes) * 60` separately
  /// renders 3.99995 min as "3:60" — the two halves disagree about which minute
  /// they are in. Every M:SS site should go through here.
  static String formatMinutesAsMinSec(double minutes) =>
      _splitSexagesimal(minutes);

  /// Format a fractional hour count as `H:MM`.
  ///
  /// Same carry-safe split as [formatMinutesAsMinSec], one unit up: 3.9999 h
  /// is `4:00`, never `3:60`.
  static String formatHoursAsHourMin(double hours) => _splitSexagesimal(hours);

  /// Split a fractional quantity into `whole:sixtieths`, rounding to the
  /// sixtieth *first* so a value that rounds up to a whole unit carries
  /// instead of overflowing the second field.
  ///
  /// Computing the two halves independently (`floor()` for the whole part,
  /// `round((value - whole) * 60)` for the remainder) lets them disagree about
  /// which unit they are in, which is what rendered 3.9999 as "3:60".
  static String _splitSexagesimal(double value) {
    final totalSixtieths = (value * 60).round();
    final whole = totalSixtieths ~/ 60;
    final remainder = totalSixtieths % 60;
    return '$whole:${remainder.toString().padLeft(2, '0')}';
  }

  static String formatPace(double minPerMile, {required PaceUnit unit}) {
    if (unit == PaceUnit.minPerKm) {
      // 1 min/mile = 0.621371 min/km
      return '${formatMinutesAsMinSec(minPerMile * kMilePerKm)} /km';
    }
    return '${formatMinutesAsMinSec(minPerMile)} /mi';
  }

  // Weight conversion methods
  static String formatWeight(double pounds, {required bool useMetric}) {
    if (useMetric) {
      final kg = pounds * kKgPerLb;
      return '${kg.toStringAsFixed(1)} kg';
    }
    return '${pounds.toStringAsFixed(1)} lbs';
  }

  static double poundsToKg(double pounds) => pounds * kKgPerLb;

  static double kgToPounds(double kg) => kg * kLbPerKg;

  // Height conversion methods
  static String formatHeight(int feet, int inches, {required bool useMetric}) {
    if (useMetric) {
      final totalInches = (feet * 12) + inches;
      final cm = (totalInches * kCmPerInch).round();
      return '$cm cm';
    }
    return "$feet'$inches\"";
  }

  static int totalInchesToCm(int totalInches) =>
      (totalInches * kCmPerInch).round();

  static int cmToTotalInches(int cm) => (cm / kCmPerInch).round();

  static (int feet, int inches) cmToFeetInches(int cm) {
    final totalInches = cmToTotalInches(cm);
    return (totalInches ~/ 12, totalInches % 12);
  }

  // Temperature conversion methods (base unit: Celsius, matching stored
  // weather/environment data throughout the app - see WeatherForecast.temperatureC)
  static String formatTemperature(double celsius, {required bool useMetric}) {
    if (useMetric) {
      return '${celsius.round()}°C';
    }
    return '${celsiusToFahrenheit(celsius).round()}°F';
  }

  static double celsiusToFahrenheit(double celsius) => (celsius * 9 / 5) + 32;

  static double fahrenheitToCelsius(double fahrenheit) =>
      (fahrenheit - 32) * 5 / 9;

  // Speed conversion methods (base unit: mph, matching
  // UserProfile.defaultCyclingSpeedMph and other imperial-base fields)
  static String formatSpeed(double mph, {required bool useMetric}) {
    if (useMetric) {
      return '${mphToKph(mph).toStringAsFixed(1)} km/h';
    }
    return '${mph.toStringAsFixed(1)} mph';
  }

  static double mphToKph(double mph) => mph * kKmPerMile;

  static double kphToMph(double kph) => kph * kMilePerKm;

  // Elevation conversion methods (base unit: feet, matching
  // CyclingParameters.elevationGainFt and other imperial-base fields)
  static String formatElevation(num feet, {required bool useMetric}) {
    if (useMetric) {
      return '${feetToMeters(feet.toDouble()).round()} m';
    }
    return '${feet.round()} ft';
  }

  static double feetToMeters(double feet) => feet * kMeterPerFoot;

  static double metersToFeet(double meters) => meters * kFootPerMeter;

  // Unit label helpers
  static String fluidUnitLabel({required bool useMetric}) =>
      useMetric ? 'mL' : 'oz';

  static String weightUnitLabel({required bool useMetric}) =>
      useMetric ? 'kg' : 'lbs';

  static String heightUnitLabel({required bool useMetric}) =>
      useMetric ? 'cm' : 'ft/in';

  static String temperatureUnitLabel({required bool useMetric}) =>
      useMetric ? '°C' : '°F';

  static String speedUnitLabel({required bool useMetric}) =>
      useMetric ? 'km/h' : 'mph';

  static String elevationUnitLabel({required bool useMetric}) =>
      useMetric ? 'm' : 'ft';
}
