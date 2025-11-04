/// Cycling-specific parameters for nutrition plan generation
class CyclingParameters {
  final double distanceMiles;
  final double speedMph;
  final int durationMinutes;
  final String terrain; // 'flat', 'rolling', 'hilly', 'mountainous'
  final String indoorOutdoor; // 'indoor', 'outdoor'
  final int timeBeforeMinutes;
  final String? intensityTarget; // 'recovery', 'endurance', 'tempo', 'threshold', 'vo2max'
  final String? sessionGoal; // 'base_building', 'race_prep', 'recovery', 'intervals'
  final int? elevationGainFt;

  const CyclingParameters({
    required this.distanceMiles,
    required this.speedMph,
    required this.durationMinutes,
    required this.terrain,
    required this.indoorOutdoor,
    required this.timeBeforeMinutes,
    this.intensityTarget,
    this.sessionGoal,
    this.elevationGainFt,
  });

  CyclingParameters copyWith({
    double? distanceMiles,
    double? speedMph,
    int? durationMinutes,
    String? terrain,
    String? indoorOutdoor,
    int? timeBeforeMinutes,
    String? intensityTarget,
    String? sessionGoal,
    int? elevationGainFt,
  }) {
    return CyclingParameters(
      distanceMiles: distanceMiles ?? this.distanceMiles,
      speedMph: speedMph ?? this.speedMph,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      terrain: terrain ?? this.terrain,
      indoorOutdoor: indoorOutdoor ?? this.indoorOutdoor,
      timeBeforeMinutes: timeBeforeMinutes ?? this.timeBeforeMinutes,
      intensityTarget: intensityTarget ?? this.intensityTarget,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      elevationGainFt: elevationGainFt ?? this.elevationGainFt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance_miles': distanceMiles,
      'speed_mph': speedMph,
      'duration_minutes': durationMinutes,
      'terrain': terrain,
      'indoor_outdoor': indoorOutdoor,
      'time_before_minutes': timeBeforeMinutes,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (sessionGoal != null) 'session_goal': sessionGoal,
      if (elevationGainFt != null) 'elevation_gain_ft': elevationGainFt,
    };
  }

  factory CyclingParameters.fromJson(Map<String, dynamic> json) {
    return CyclingParameters(
      distanceMiles: (json['distance_miles'] as num).toDouble(),
      speedMph: (json['speed_mph'] as num).toDouble(),
      durationMinutes: json['duration_minutes'] as int,
      terrain: json['terrain'] as String,
      indoorOutdoor: json['indoor_outdoor'] as String,
      timeBeforeMinutes: json['time_before_minutes'] as int,
      intensityTarget: json['intensity_target'] as String?,
      sessionGoal: json['session_goal'] as String?,
      elevationGainFt: json['elevation_gain_ft'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CyclingParameters &&
        other.distanceMiles == distanceMiles &&
        other.speedMph == speedMph &&
        other.durationMinutes == durationMinutes &&
        other.terrain == terrain &&
        other.indoorOutdoor == indoorOutdoor &&
        other.timeBeforeMinutes == timeBeforeMinutes &&
        other.intensityTarget == intensityTarget &&
        other.sessionGoal == sessionGoal &&
        other.elevationGainFt == elevationGainFt;
  }

  @override
  int get hashCode {
    return Object.hash(
      distanceMiles,
      speedMph,
      durationMinutes,
      terrain,
      indoorOutdoor,
      timeBeforeMinutes,
      intensityTarget,
      sessionGoal,
      elevationGainFt,
    );
  }

  @override
  String toString() {
    return 'CyclingParameters(distanceMiles: $distanceMiles, speedMph: $speedMph, '
        'durationMinutes: $durationMinutes, terrain: $terrain, '
        'indoorOutdoor: $indoorOutdoor, timeBeforeMinutes: $timeBeforeMinutes, '
        'intensityTarget: $intensityTarget, sessionGoal: $sessionGoal, '
        'elevationGainFt: $elevationGainFt)';
  }
}
