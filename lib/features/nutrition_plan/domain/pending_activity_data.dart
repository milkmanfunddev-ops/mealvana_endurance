import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';

/// Pending activity data (not yet created in database).
///
/// This represents activity data collected during nutrition plan generation
/// that will be used to create an actual Activity entity later.
class PendingActivityData {
  const PendingActivityData({
    required this.title,
    required this.scheduledDateTime,
    required this.activityType,
    required this.distanceMiles,
    required this.paceMinutesPerMile,
    this.intensityLevel = IntensityLevel.moderate,
    this.notes,
    // Cycling-specific parameters
    this.cyclingSpeedMph,
    this.cyclingTerrain,
    this.cyclingIndoorOutdoor,
    this.cyclingElevationGainFt,
    this.cyclingSessionGoal,
    // Swimming-specific parameters
    this.swimmingPacePer100mSeconds,
    this.swimmingPoolOrOpenWater,
    this.swimmingWaterTempC,
    // Shared parameters
    this.intensityTarget,
    this.timeBeforeMinutes,
  });

  final String title;
  final DateTime scheduledDateTime;
  final ActivityType activityType;
  final double distanceMiles;
  final double paceMinutesPerMile;
  final IntensityLevel intensityLevel;
  final String? notes;

  // Cycling-specific parameters
  final double? cyclingSpeedMph;
  final String? cyclingTerrain;
  final String? cyclingIndoorOutdoor;
  final int? cyclingElevationGainFt;
  final String? cyclingSessionGoal;

  // Swimming-specific parameters
  final int? swimmingPacePer100mSeconds;
  final String? swimmingPoolOrOpenWater;
  final double? swimmingWaterTempC;

  // Shared parameters
  final String? intensityTarget;
  final int? timeBeforeMinutes;

  /// Factory constructor for running activities
  factory PendingActivityData.running({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required DateTime scheduledDateTime,
    required int timeBeforeMinutes,
    IntensityLevel intensityLevel = IntensityLevel.moderate,
    String? notes,
  }) {
    return PendingActivityData(
      title: '${distanceMiles.toStringAsFixed(1)} mi Run',
      scheduledDateTime: scheduledDateTime,
      activityType: ActivityType.running,
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      intensityLevel: intensityLevel,
      notes: notes ?? 'Created from nutrition plan generation',
      timeBeforeMinutes: timeBeforeMinutes,
    );
  }

  /// Factory constructor for cycling activities
  factory PendingActivityData.cycling({
    required double distanceMiles,
    required double speedMph,
    required DateTime scheduledDateTime,
    required int timeBeforeMinutes,
    required String terrain,
    required String indoorOutdoor,
    int? elevationGainFt,
    String? sessionGoal,
    String? intensityTarget,
    IntensityLevel intensityLevel = IntensityLevel.moderate,
    String? notes,
  }) {
    return PendingActivityData(
      title: '${distanceMiles.toStringAsFixed(1)} mi Ride',
      scheduledDateTime: scheduledDateTime,
      activityType: ActivityType.cycling,
      distanceMiles: distanceMiles,
      paceMinutesPerMile: 0.0, // Not applicable for cycling
      intensityLevel: intensityLevel,
      notes: notes ?? 'Created from cycling nutrition plan generation',
      cyclingSpeedMph: speedMph,
      cyclingTerrain: terrain,
      cyclingIndoorOutdoor: indoorOutdoor,
      cyclingElevationGainFt: elevationGainFt,
      cyclingSessionGoal: sessionGoal,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
    );
  }

  /// Factory constructor for swimming activities
  factory PendingActivityData.swimming({
    required int distanceMeters,
    required int paceSecondsper100m,
    required DateTime scheduledDateTime,
    required int timeBeforeMinutes,
    required String poolOrOpenWater,
    double? waterTempC,
    String? intensityTarget,
    String? sessionGoal,
    IntensityLevel intensityLevel = IntensityLevel.moderate,
    String? notes,
  }) {
    return PendingActivityData(
      title: '${distanceMeters}m Swim',
      scheduledDateTime: scheduledDateTime,
      activityType: ActivityType.swimming,
      distanceMiles: distanceMeters * 0.000621371, // Convert meters to miles
      paceMinutesPerMile: 0.0, // Not applicable for swimming
      intensityLevel: intensityLevel,
      notes: notes ?? 'Created from swimming nutrition plan generation',
      swimmingPacePer100mSeconds: paceSecondsper100m,
      swimmingPoolOrOpenWater: poolOrOpenWater,
      swimmingWaterTempC: waterTempC,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
    );
  }
}
