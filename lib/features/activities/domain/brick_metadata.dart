// Brick workout metadata domain models
//
// This file contains domain models for brick workouts - multi-sport training
// sessions where 2-3 sports are performed consecutively (e.g., swim then run).

/// Brick workout metadata
///
/// Stores structured information about a brick workout including segment order,
/// detailed segment information, and whether the brick was created from existing
/// activities.
class BrickMetadata {
  const BrickMetadata({
    required this.segmentOrder,
    required this.segments,
    this.originalActivityIds,
    required this.createdFromExisting,
    required this.totalDurationMinutes,
  });

  /// Ordered list of sports in this brick (e.g., ['swimming', 'running'])
  final List<String> segmentOrder;

  /// Detailed information about each segment
  final List<BrickSegment> segments;

  /// Original activity IDs if created from existing activities (for ungrouping)
  final List<String>? originalActivityIds;

  /// Whether this brick was created from existing activities or from scratch
  final bool createdFromExisting;

  /// Total calculated duration (sum of all segments)
  final int totalDurationMinutes;

  /// Serialize to JSON for storage in brick_metadata column
  Map<String, dynamic> toJson() {
    return {
      'segment_order': segmentOrder,
      'segments': segments.map((s) => s.toJson()).toList(),
      'original_activity_ids': originalActivityIds,
      'created_from_existing': createdFromExisting,
      'total_duration_minutes': totalDurationMinutes,
    };
  }

  /// Deserialize from JSON
  factory BrickMetadata.fromJson(Map<String, dynamic> json) {
    return BrickMetadata(
      segmentOrder: (json['segment_order'] as List<dynamic>).cast<String>(),
      segments: (json['segments'] as List<dynamic>)
          .map((s) => BrickSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      originalActivityIds: json['original_activity_ids'] != null
          ? (json['original_activity_ids'] as List<dynamic>).cast<String>()
          : null,
      createdFromExisting: json['created_from_existing'] as bool,
      totalDurationMinutes: json['total_duration_minutes'] as int,
    );
  }

  BrickMetadata copyWith({
    List<String>? segmentOrder,
    List<BrickSegment>? segments,
    List<String>? originalActivityIds,
    bool? createdFromExisting,
    int? totalDurationMinutes,
  }) {
    return BrickMetadata(
      segmentOrder: segmentOrder ?? this.segmentOrder,
      segments: segments ?? this.segments,
      originalActivityIds: originalActivityIds ?? this.originalActivityIds,
      createdFromExisting: createdFromExisting ?? this.createdFromExisting,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrickMetadata &&
        _listEquals(other.segmentOrder, segmentOrder) &&
        _listEquals(other.segments, segments) &&
        _listEquals(other.originalActivityIds, originalActivityIds) &&
        other.createdFromExisting == createdFromExisting &&
        other.totalDurationMinutes == totalDurationMinutes;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(segmentOrder),
      Object.hashAll(segments),
      Object.hashAll(originalActivityIds ?? []),
      createdFromExisting,
      totalDurationMinutes,
    );
  }

  @override
  String toString() {
    return 'BrickMetadata(segmentOrder: $segmentOrder, segments: ${segments.length}, createdFromExisting: $createdFromExisting)';
  }
}

/// Individual segment within a brick workout
///
/// Each segment represents one sport within the brick (e.g., the swim portion
/// of a swim/run brick). Only sport-specific fields relevant to that segment
/// should be populated.
class BrickSegment {
  const BrickSegment({
    required this.sport,
    required this.order,
    required this.durationMinutes,
    required this.intensity,
    // Swimming fields
    this.distanceMeters,
    this.pacePer100mSeconds,
    this.poolOrOpenWater,
    this.waterTempC,
    // Cycling fields
    this.distanceMiles,
    this.speedMph,
    this.terrain,
    this.indoorOutdoor,
    this.elevationGainFt,
    // Running fields (shares distanceMiles with cycling)
    this.paceMinutesPerMile,
  });

  /// Sport type for this segment ('swimming', 'cycling', 'running')
  final String sport;

  /// Position in the brick (1-based)
  final int order;

  /// Duration of this segment in minutes
  final int durationMinutes;

  /// Intensity level ('easy', 'moderate', 'hard', 'race')
  final String intensity;

  // Swimming-specific fields
  /// Distance in meters (swimming only)
  final double? distanceMeters;

  /// Pace per 100m in seconds (swimming only)
  final int? pacePer100mSeconds;

  /// Pool or open water ('pool', 'open_water')
  final String? poolOrOpenWater;

  /// Water temperature in Celsius (swimming only)
  final double? waterTempC;

  // Cycling-specific fields
  /// Distance in miles (cycling and running)
  final double? distanceMiles;

  /// Speed in mph (cycling only)
  final double? speedMph;

  /// Terrain type ('flat', 'rolling', 'hilly')
  final String? terrain;

  /// Indoor or outdoor ('indoor', 'outdoor')
  final String? indoorOutdoor;

  /// Elevation gain in feet (cycling only)
  final int? elevationGainFt;

  // Running-specific fields
  /// Pace in minutes per mile (running only)
  final double? paceMinutesPerMile;

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'sport': sport,
      'order': order,
      'duration_minutes': durationMinutes,
      'intensity': intensity,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (pacePer100mSeconds != null) 'pace_per_100m_seconds': pacePer100mSeconds,
      if (poolOrOpenWater != null) 'pool_or_open_water': poolOrOpenWater,
      if (waterTempC != null) 'water_temp_c': waterTempC,
      if (distanceMiles != null) 'distance_miles': distanceMiles,
      if (speedMph != null) 'speed_mph': speedMph,
      if (terrain != null) 'terrain': terrain,
      if (indoorOutdoor != null) 'indoor_outdoor': indoorOutdoor,
      if (elevationGainFt != null) 'elevation_gain_ft': elevationGainFt,
      if (paceMinutesPerMile != null) 'pace_minutes_per_mile': paceMinutesPerMile,
    };
  }

  /// Deserialize from JSON
  factory BrickSegment.fromJson(Map<String, dynamic> json) {
    return BrickSegment(
      sport: json['sport'] as String,
      order: json['order'] as int,
      durationMinutes: json['duration_minutes'] as int,
      intensity: json['intensity'] as String,
      distanceMeters: json['distance_meters'] as double?,
      pacePer100mSeconds: json['pace_per_100m_seconds'] as int?,
      poolOrOpenWater: json['pool_or_open_water'] as String?,
      waterTempC: json['water_temp_c'] as double?,
      distanceMiles: json['distance_miles'] as double?,
      speedMph: json['speed_mph'] as double?,
      terrain: json['terrain'] as String?,
      indoorOutdoor: json['indoor_outdoor'] as String?,
      elevationGainFt: json['elevation_gain_ft'] as int?,
      paceMinutesPerMile: json['pace_minutes_per_mile'] as double?,
    );
  }

  BrickSegment copyWith({
    String? sport,
    int? order,
    int? durationMinutes,
    String? intensity,
    double? distanceMeters,
    int? pacePer100mSeconds,
    String? poolOrOpenWater,
    double? waterTempC,
    double? distanceMiles,
    double? speedMph,
    String? terrain,
    String? indoorOutdoor,
    int? elevationGainFt,
    double? paceMinutesPerMile,
  }) {
    return BrickSegment(
      sport: sport ?? this.sport,
      order: order ?? this.order,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      pacePer100mSeconds: pacePer100mSeconds ?? this.pacePer100mSeconds,
      poolOrOpenWater: poolOrOpenWater ?? this.poolOrOpenWater,
      waterTempC: waterTempC ?? this.waterTempC,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      speedMph: speedMph ?? this.speedMph,
      terrain: terrain ?? this.terrain,
      indoorOutdoor: indoorOutdoor ?? this.indoorOutdoor,
      elevationGainFt: elevationGainFt ?? this.elevationGainFt,
      paceMinutesPerMile: paceMinutesPerMile ?? this.paceMinutesPerMile,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrickSegment &&
        other.sport == sport &&
        other.order == order &&
        other.durationMinutes == durationMinutes &&
        other.intensity == intensity &&
        other.distanceMeters == distanceMeters &&
        other.pacePer100mSeconds == pacePer100mSeconds &&
        other.poolOrOpenWater == poolOrOpenWater &&
        other.waterTempC == waterTempC &&
        other.distanceMiles == distanceMiles &&
        other.speedMph == speedMph &&
        other.terrain == terrain &&
        other.indoorOutdoor == indoorOutdoor &&
        other.elevationGainFt == elevationGainFt &&
        other.paceMinutesPerMile == paceMinutesPerMile;
  }

  @override
  int get hashCode {
    return Object.hash(
      sport,
      order,
      durationMinutes,
      intensity,
      distanceMeters,
      pacePer100mSeconds,
      poolOrOpenWater,
      waterTempC,
      distanceMiles,
      speedMph,
    ) ^ Object.hash(
      terrain,
      indoorOutdoor,
      elevationGainFt,
      paceMinutesPerMile,
    );
  }

  @override
  String toString() {
    return 'BrickSegment(sport: $sport, order: $order, duration: ${durationMinutes}min, intensity: $intensity)';
  }
}

// Helper function for list equality comparison
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
