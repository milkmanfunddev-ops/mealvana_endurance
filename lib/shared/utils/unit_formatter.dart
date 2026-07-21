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

  static String formatFluids(
    double ml, {
    bool useImperial = false,
    bool useMetric = false,
  }) {
    // Support both parameter names for backward compatibility
    final shouldUseMetric = useMetric || !useImperial;

    if (!shouldUseMetric) {
      // Imperial: convert to oz
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

  static String formatPace(double minPerMile, {required PaceUnit unit}) {
    if (unit == PaceUnit.minPerKm) {
      // 1 min/mile = 0.621371 min/km
      final minPerKm = minPerMile * 0.621371;
      final minutes = minPerKm.floor();
      final seconds = ((minPerKm - minutes) * 60).round();
      return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
    }
    final minutes = minPerMile.floor();
    final seconds = ((minPerMile - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /mi';
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
