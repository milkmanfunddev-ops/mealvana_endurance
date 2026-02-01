import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';

class UnitFormatter {
  // Conversion constants
  static const double kMlPerFlOz = 29.5735;
  static const double kFlOzPerMl = 0.033814;
  static const double kKgPerLb = 0.453592;
  static const double kLbPerKg = 2.20462;
  static const double kCmPerInch = 2.54;

  static String formatFluids(double ml, {bool useImperial = false, bool useMetric = false}) {
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

  static int totalInchesToCm(int totalInches) => (totalInches * kCmPerInch).round();

  static int cmToTotalInches(int cm) => (cm / kCmPerInch).round();

  static (int feet, int inches) cmToFeetInches(int cm) {
    final totalInches = cmToTotalInches(cm);
    return (totalInches ~/ 12, totalInches % 12);
  }

  // Unit label helpers
  static String fluidUnitLabel({required bool useMetric}) => useMetric ? 'mL' : 'oz';

  static String weightUnitLabel({required bool useMetric}) => useMetric ? 'kg' : 'lbs';

  static String heightUnitLabel({required bool useMetric}) => useMetric ? 'cm' : 'ft/in';
}
