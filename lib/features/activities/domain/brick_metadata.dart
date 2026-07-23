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
    final segmentOrderRaw = json['segment_order'] ?? json['segmentOrder'];
    final segmentsRaw = json['segments'];
    final originalActivityIdsRaw =
        json['original_activity_ids'] ?? json['originalActivityIds'];
    final createdFromExistingRaw =
        json['created_from_existing'] ?? json['createdFromExisting'];
    final totalDurationMinutesRaw =
        json['total_duration_minutes'] ?? json['totalDurationMinutes'];

    final parsedSegments = _asMapList(
      segmentsRaw,
    ).map(BrickSegment.fromJson).toList();

    return BrickMetadata(
      segmentOrder: _asStringList(segmentOrderRaw),
      segments: parsedSegments,
      originalActivityIds: originalActivityIdsRaw != null
          ? _asStringList(originalActivityIdsRaw)
          : null,
      createdFromExisting: _asBool(createdFromExistingRaw) ?? false,
      totalDurationMinutes:
          _asInt(totalDurationMinutesRaw) ??
          parsedSegments.fold<int>(
            0,
            (sum, segment) => sum + segment.durationMinutes,
          ),
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
      if (pacePer100mSeconds != null)
        'pace_per_100m_seconds': pacePer100mSeconds,
      if (poolOrOpenWater != null) 'pool_or_open_water': poolOrOpenWater,
      if (waterTempC != null) 'water_temp_c': waterTempC,
      if (distanceMiles != null) 'distance_miles': distanceMiles,
      if (speedMph != null) 'speed_mph': speedMph,
      if (terrain != null) 'terrain': terrain,
      if (indoorOutdoor != null) 'indoor_outdoor': indoorOutdoor,
      if (elevationGainFt != null) 'elevation_gain_ft': elevationGainFt,
      if (paceMinutesPerMile != null)
        'pace_minutes_per_mile': paceMinutesPerMile,
    };
  }

  /// Deserialize from JSON
  factory BrickSegment.fromJson(Map<String, dynamic> json) {
    return BrickSegment(
      sport: _requireString(json['sport'], 'sport'),
      order: _requireInt(json['order'], 'order'),
      durationMinutes: _requireInt(
        json['duration_minutes'] ?? json['durationMinutes'],
        'duration_minutes',
      ),
      intensity: _requireString(json['intensity'], 'intensity'),
      distanceMeters: _asDouble(
        json['distance_meters'] ?? json['distanceMeters'],
      ),
      pacePer100mSeconds: _asInt(
        json['pace_per_100m_seconds'] ?? json['pacePer100mSeconds'],
      ),
      poolOrOpenWater: _asString(
        json['pool_or_open_water'] ?? json['poolOrOpenWater'],
      ),
      waterTempC: _asDouble(json['water_temp_c'] ?? json['waterTempC']),
      distanceMiles: _asDouble(json['distance_miles'] ?? json['distanceMiles']),
      speedMph: _asDouble(json['speed_mph'] ?? json['speedMph']),
      terrain: _asString(json['terrain']),
      indoorOutdoor: _asString(json['indoor_outdoor'] ?? json['indoorOutdoor']),
      elevationGainFt: _asInt(
        json['elevation_gain_ft'] ?? json['elevationGainFt'],
      ),
      paceMinutesPerMile: _asDouble(
        json['pace_minutes_per_mile'] ?? json['paceMinutesPerMile'],
      ),
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
        ) ^
        Object.hash(
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

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Object?>()
      .map(_asStringKeyedMap)
      .toList(growable: false);
}

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  throw const FormatException('Expected JSON object');
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .where((item) => item != null)
      .map((item) => item.toString())
      .toList(growable: false);
}

String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

String _requireString(dynamic value, String fieldName) {
  final parsed = _asString(value);
  if (parsed == null || parsed.isEmpty) {
    throw FormatException('Missing required field: $fieldName');
  }
  return parsed;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int _requireInt(dynamic value, String fieldName) {
  final parsed = _asInt(value);
  if (parsed == null) {
    throw FormatException('Invalid required field: $fieldName');
  }
  return parsed;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}
