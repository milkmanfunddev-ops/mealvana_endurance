import 'dart:convert';

/// Domain models for athlete training zones from Training Peaks.
///
/// Training Peaks provides zone configurations for:
/// - Heart Rate (7 zones based on max HR and threshold)
/// - Speed (per-sport pace zones in m/s)
/// - Power (6 zones based on FTP)
///
/// These zones enable:
/// 1. Precise intensity classification of structured workouts
/// 2. Auto-suggest pace on New Activity screen
/// 3. Pre-fill intensity distribution based on zone targets

/// Top-level container for all athlete zone configurations
class AthleteZones {
  const AthleteZones({this.heartRateZones, this.speedZones, this.powerZones});

  final HeartRateZoneConfig? heartRateZones;
  final Map<String, SpeedZoneConfig>?
  speedZones; // keyed by sport: Default, Run, Swim
  final PowerZoneConfig? powerZones;

  /// Parse from Training Peaks /v1/athlete/profile/zones response
  factory AthleteZones.fromTrainingPeaksResponse(Map<String, dynamic> json) {
    // Parse Heart Rate Zones
    HeartRateZoneConfig? hrZones;
    final hrData = json['HeartRateZones'] as Map<String, dynamic>?;
    if (hrData != null) {
      final defaultHr = hrData['Default'] as Map<String, dynamic>?;
      if (defaultHr != null) {
        hrZones = HeartRateZoneConfig.fromJson(defaultHr);
      }
    }

    // Parse Speed Zones (per-sport)
    Map<String, SpeedZoneConfig>? speedZones;
    final speedData = json['SpeedZones'] as Map<String, dynamic>?;
    if (speedData != null) {
      speedZones = {};
      for (final entry in speedData.entries) {
        if (entry.value is Map<String, dynamic>) {
          speedZones[entry.key] = SpeedZoneConfig.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    // Parse Power Zones
    PowerZoneConfig? powerZones;
    final powerData = json['PowerZones'] as Map<String, dynamic>?;
    if (powerData != null) {
      final defaultPower = powerData['Default'] as Map<String, dynamic>?;
      if (defaultPower != null) {
        powerZones = PowerZoneConfig.fromJson(defaultPower);
      }
    }

    return AthleteZones(
      heartRateZones: hrZones,
      speedZones: speedZones,
      powerZones: powerZones,
    );
  }

  /// Deserialize from stored JSON
  factory AthleteZones.fromJson(Map<String, dynamic> json) {
    HeartRateZoneConfig? hrZones;
    if (json['heartRateZones'] != null) {
      hrZones = HeartRateZoneConfig.fromJson(
        json['heartRateZones'] as Map<String, dynamic>,
      );
    }

    Map<String, SpeedZoneConfig>? speedZones;
    if (json['speedZones'] != null) {
      final speedMap = json['speedZones'] as Map<String, dynamic>;
      speedZones = speedMap.map(
        (key, value) => MapEntry(
          key,
          SpeedZoneConfig.fromJson(value as Map<String, dynamic>),
        ),
      );
    }

    PowerZoneConfig? powerZones;
    if (json['powerZones'] != null) {
      powerZones = PowerZoneConfig.fromJson(
        json['powerZones'] as Map<String, dynamic>,
      );
    }

    return AthleteZones(
      heartRateZones: hrZones,
      speedZones: speedZones,
      powerZones: powerZones,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (heartRateZones != null) 'heartRateZones': heartRateZones!.toJson(),
      if (speedZones != null)
        'speedZones': speedZones!.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (powerZones != null) 'powerZones': powerZones!.toJson(),
    };
  }

  /// Serialize to JSON string for database storage
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from JSON string
  static AthleteZones? fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AthleteZones.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Get run speed zone config (falls back to Default)
  SpeedZoneConfig? get runSpeedZones =>
      speedZones?['Run'] ?? speedZones?['Default'];

  /// Get swim speed zone config
  SpeedZoneConfig? get swimSpeedZones => speedZones?['Swim'];

  /// Get Zone 2 swim pace in seconds per 100m from speed zones
  ///
  /// Speed zones are in m/s. Conversion:
  /// pace (sec/100m) = 100 / speed_m_s
  double? get zone2SwimPaceSecondsPer100m {
    final config = swimSpeedZones;
    if (config == null || config.zones.length < 2) return null;

    final zone2 = config.zones[1];
    final midSpeedMs = (zone2.minimum + zone2.maximum) / 2;
    if (midSpeedMs <= 0) return null;

    return 100 / midSpeedMs;
  }

  /// Estimate pace in min/mile for a given zone name from speed zones
  ///
  /// Speed zones are in m/s. Conversion:
  /// pace (min/mile) = 1609.34 / (speed_m_s * 60)
  double? estimatedPaceMinPerMile(String zoneName) {
    final config = runSpeedZones;
    if (config == null) return null;

    final zone = config.zones.where((z) => z.label == zoneName).firstOrNull;
    if (zone == null) return null;

    // Use midpoint of zone range
    final midSpeedMs = (zone.minimum + zone.maximum) / 2;
    if (midSpeedMs <= 0) return null;

    return 1609.34 / (midSpeedMs * 60);
  }

  /// Get Zone 2 (endurance) pace in min/mile from speed zones
  ///
  /// Zone 2 is typically the second zone, used for easy/aerobic running.
  double? get zone2PaceMinPerMile {
    final config = runSpeedZones;
    if (config == null || config.zones.length < 2) return null;

    // Zone 2 is index 1 (0-indexed)
    final zone2 = config.zones[1];
    final midSpeedMs = (zone2.minimum + zone2.maximum) / 2;
    if (midSpeedMs <= 0) return null;

    return 1609.34 / (midSpeedMs * 60);
  }

  /// Get threshold pace in min/mile from speed zones
  double? get thresholdPaceMinPerMile {
    final config = runSpeedZones;
    if (config == null || config.threshold == null || config.threshold! <= 0) {
      return null;
    }

    return 1609.34 / (config.threshold! * 60);
  }

  /// Map a %maxHR value to our intensity level
  ///
  /// Uses actual athlete zones when available, otherwise falls back
  /// to standard thresholds.
  String intensityLevelForHrPercent(double percent) {
    if (heartRateZones != null && heartRateZones!.zones.length >= 5) {
      // Use actual zone boundaries
      // Zones are ordered 1-7, check from top down
      final zones = heartRateZones!.zones;
      final maxHr = heartRateZones!.maxHeartRate;
      if (maxHr != null && maxHr > 0) {
        final actualHr = percent * maxHr;
        // Zone 5+ → race/hard
        if (zones.length >= 5 && actualHr >= zones[4].minimum) {
          return 'race';
        }
        // Zone 3-4 → moderate/hard
        if (zones.length >= 3 && actualHr >= zones[2].minimum) {
          return 'hard';
        }
        // Zone 1-2 → easy
        return 'easy';
      }
    }

    // Standard thresholds
    if (percent >= 0.95) return 'race';
    if (percent >= 0.80) return 'hard';
    if (percent >= 0.70) return 'moderate';
    return 'easy';
  }

  @override
  String toString() {
    final parts = <String>[];
    if (heartRateZones != null)
      parts.add('HR: ${heartRateZones!.zones.length} zones');
    if (speedZones != null) parts.add('Speed: ${speedZones!.length} configs');
    if (powerZones != null)
      parts.add('Power: ${powerZones!.zones.length} zones');
    return 'AthleteZones(${parts.join(', ')})';
  }
}

/// Heart rate zone configuration
class HeartRateZoneConfig {
  const HeartRateZoneConfig({
    this.threshold,
    this.maxHeartRate,
    this.restingHeartRate,
    required this.zones,
  });

  final int? threshold;
  final int? maxHeartRate;
  final int? restingHeartRate;
  final List<Zone> zones;

  factory HeartRateZoneConfig.fromJson(Map<String, dynamic> json) {
    final zonesJson = json['Zones'] as List? ?? json['zones'] as List? ?? [];
    return HeartRateZoneConfig(
      threshold: (json['Threshold'] ?? json['threshold']) as int?,
      maxHeartRate: (json['MaxHeartRate'] ?? json['maxHeartRate']) as int?,
      restingHeartRate:
          (json['RestingHeartRate'] ?? json['restingHeartRate']) as int?,
      zones: zonesJson
          .map((z) => Zone.fromJson(z as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (threshold != null) 'threshold': threshold,
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
    'zones': zones.map((z) => z.toJson()).toList(),
  };
}

/// Speed zone configuration (per-sport: Default, Run, Swim)
class SpeedZoneConfig {
  const SpeedZoneConfig({this.threshold, required this.zones});

  /// Threshold speed in m/s
  final double? threshold;
  final List<Zone> zones;

  factory SpeedZoneConfig.fromJson(Map<String, dynamic> json) {
    final zonesJson = json['Zones'] as List? ?? json['zones'] as List? ?? [];
    return SpeedZoneConfig(
      threshold:
          (json['Threshold'] as num?)?.toDouble() ??
          (json['threshold'] as num?)?.toDouble(),
      zones: zonesJson
          .map((z) => Zone.fromJson(z as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (threshold != null) 'threshold': threshold,
    'zones': zones.map((z) => z.toJson()).toList(),
  };
}

/// Power zone configuration
class PowerZoneConfig {
  const PowerZoneConfig({this.threshold, required this.zones});

  /// FTP (Functional Threshold Power) in watts
  final int? threshold;
  final List<Zone> zones;

  factory PowerZoneConfig.fromJson(Map<String, dynamic> json) {
    final zonesJson = json['Zones'] as List? ?? json['zones'] as List? ?? [];
    return PowerZoneConfig(
      threshold: (json['Threshold'] ?? json['threshold']) as int?,
      zones: zonesJson
          .map((z) => Zone.fromJson(z as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (threshold != null) 'threshold': threshold,
    'zones': zones.map((z) => z.toJson()).toList(),
  };
}

/// A single training zone with label and min/max bounds
class Zone {
  const Zone({
    required this.label,
    required this.minimum,
    required this.maximum,
  });

  final String label;
  final double minimum;
  final double maximum;

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      label: (json['Label'] ?? json['label'] ?? '') as String,
      minimum:
          (json['Minimum'] as num?)?.toDouble() ??
          (json['minimum'] as num?)?.toDouble() ??
          0,
      maximum:
          (json['Maximum'] as num?)?.toDouble() ??
          (json['maximum'] as num?)?.toDouble() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'minimum': minimum,
    'maximum': maximum,
  };
}
