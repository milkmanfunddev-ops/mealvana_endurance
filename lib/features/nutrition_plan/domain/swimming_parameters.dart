/// Swimming-specific parameters for nutrition plan generation
class SwimmingParameters {
  final int distanceMeters;
  final int paceSecondsper100m;
  final int durationMinutes;
  final String poolOrOpenWater; // 'pool', 'open_water'
  final int timeBeforeMinutes;
  final String?
  intensityTarget; // 'recovery', 'endurance', 'tempo', 'threshold', 'vo2max'
  final String?
  sessionGoal; // 'base_building', 'race_prep', 'recovery', 'intervals'
  final double? waterTempC;

  const SwimmingParameters({
    required this.distanceMeters,
    required this.paceSecondsper100m,
    required this.durationMinutes,
    required this.poolOrOpenWater,
    required this.timeBeforeMinutes,
    this.intensityTarget,
    this.sessionGoal,
    this.waterTempC,
  });

  SwimmingParameters copyWith({
    int? distanceMeters,
    int? paceSecondsper100m,
    int? durationMinutes,
    String? poolOrOpenWater,
    int? timeBeforeMinutes,
    String? intensityTarget,
    String? sessionGoal,
    double? waterTempC,
  }) {
    return SwimmingParameters(
      distanceMeters: distanceMeters ?? this.distanceMeters,
      paceSecondsper100m: paceSecondsper100m ?? this.paceSecondsper100m,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      poolOrOpenWater: poolOrOpenWater ?? this.poolOrOpenWater,
      timeBeforeMinutes: timeBeforeMinutes ?? this.timeBeforeMinutes,
      intensityTarget: intensityTarget ?? this.intensityTarget,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      waterTempC: waterTempC ?? this.waterTempC,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance_meters': distanceMeters,
      'pace_per_100m_seconds': paceSecondsper100m,
      'duration_minutes': durationMinutes,
      'pool_or_open_water': poolOrOpenWater,
      'time_before_minutes': timeBeforeMinutes,
      if (intensityTarget != null) 'intensity_target': intensityTarget,
      if (sessionGoal != null) 'session_goal': sessionGoal,
      if (waterTempC != null) 'water_temp_c': waterTempC,
    };
  }

  factory SwimmingParameters.fromJson(Map<String, dynamic> json) {
    return SwimmingParameters(
      distanceMeters: json['distance_meters'] as int,
      paceSecondsper100m: json['pace_per_100m_seconds'] as int,
      durationMinutes: json['duration_minutes'] as int,
      poolOrOpenWater: json['pool_or_open_water'] as String,
      timeBeforeMinutes: json['time_before_minutes'] as int,
      intensityTarget: json['intensity_target'] as String?,
      sessionGoal: json['session_goal'] as String?,
      waterTempC: (json['water_temp_c'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SwimmingParameters &&
        other.distanceMeters == distanceMeters &&
        other.paceSecondsper100m == paceSecondsper100m &&
        other.durationMinutes == durationMinutes &&
        other.poolOrOpenWater == poolOrOpenWater &&
        other.timeBeforeMinutes == timeBeforeMinutes &&
        other.intensityTarget == intensityTarget &&
        other.sessionGoal == sessionGoal &&
        other.waterTempC == waterTempC;
  }

  @override
  int get hashCode {
    return Object.hash(
      distanceMeters,
      paceSecondsper100m,
      durationMinutes,
      poolOrOpenWater,
      timeBeforeMinutes,
      intensityTarget,
      sessionGoal,
      waterTempC,
    );
  }

  @override
  String toString() {
    return 'SwimmingParameters(distanceMeters: $distanceMeters, '
        'paceSecondsper100m: $paceSecondsper100m, durationMinutes: $durationMinutes, '
        'poolOrOpenWater: $poolOrOpenWater, timeBeforeMinutes: $timeBeforeMinutes, '
        'intensityTarget: $intensityTarget, sessionGoal: $sessionGoal, '
        'waterTempC: $waterTempC)';
  }
}
