/// Domain model for run parameters used in nutrition calculations
class RunParameters {
  final double distance;
  final DistanceUnit distanceUnit;
  final String pace; // Format: "M:SS" or number (minutes)
  final PaceUnit paceUnit;
  final int timeBeforeRunMin; // Minutes available before start
  
  const RunParameters({
    required this.distance,
    this.distanceUnit = DistanceUnit.miles,
    required this.pace,
    this.paceUnit = PaceUnit.minPerMile,
    required this.timeBeforeRunMin,
  });

  RunParameters copyWith({
    double? distance,
    DistanceUnit? distanceUnit,
    String? pace,
    PaceUnit? paceUnit,
    int? timeBeforeRunMin,
  }) {
    return RunParameters(
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      pace: pace ?? this.pace,
      paceUnit: paceUnit ?? this.paceUnit,
      timeBeforeRunMin: timeBeforeRunMin ?? this.timeBeforeRunMin,
    );
  }

  @override
  String toString() {
    return 'RunParameters(distance: $distance $distanceUnit, pace: $pace $paceUnit, timeBeforeRun: ${timeBeforeRunMin}min)';
  }
}

enum DistanceUnit {
  miles('mi', 'Miles'),
  kilometers('km', 'Kilometers');

  const DistanceUnit(this.abbreviation, this.displayName);
  final String abbreviation;
  final String displayName;
}

enum PaceUnit {
  minPerMile('min/mi', 'Min per Mile'),
  minPerKm('min/km', 'Min per Km');

  const PaceUnit(this.abbreviation, this.displayName);
  final String abbreviation;
  final String displayName;
}

enum UnitSystem {
  imperial('Imperial', 'US'),
  metric('Metric', 'International');

  final String displayName;
  final String description;
  const UnitSystem(this.displayName, this.description);
}