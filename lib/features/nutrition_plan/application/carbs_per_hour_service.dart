import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../domain/carbs_per_hour_summary.dart';
import '../domain/fuel_log_data.dart';

/// Pure logic for the post-workout carbs-per-hour summary.
///
/// The metric is **during-effort carbs only ÷ effective duration**, tracked
/// only for long efforts (>= [minimumDurationMinutes]), compared against the
/// athlete's recent *same-sport* history. Speed work and swims are excluded.
/// All methods are pure — the baseline's DB read is done by the provider, which
/// then hands the loaded history here for assembly.
class CarbsPerHourService {
  const CarbsPerHourService({
    this.minimumDurationMinutes = 90,
    this.unlockThreshold = 4,
    this.trendWindow = 6,
  });

  /// Minimum effort length (minutes) for carbs/hr to be tracked.
  final int minimumDurationMinutes;

  /// Qualifying prior efforts required before the trend unlocks.
  final int unlockThreshold;

  /// Total points shown on the sparkline, including the current session.
  final int trendWindow;

  /// Number of prior efforts to surface in the sparkline (window minus today).
  int get priorTrendPoints => trendWindow - 1;

  /// Completed duration when available, falling back to the planned value.
  int? effectiveDurationMinutes(Activity activity) =>
      activity.actualDurationMinutes ?? activity.durationMinutes;

  /// Sum of DURING-section actual carbs (grams) in a fuel log.
  int duringCarbsG(FuelLogData fuelLog) {
    return fuelLog.items
        .where((item) => item.sectionId.contains('during'))
        .fold<int>(
          0,
          (sum, item) => sum + (item.actualNutritionalInfo?.carbs ?? 0),
        );
  }

  /// This session's during carbs/hr, or null when duration is unusable.
  double? sessionCarbRate(Activity activity, FuelLogData fuelLog) {
    final duration = effectiveDurationMinutes(activity);
    if (duration == null || duration <= 0) return null;
    return duringCarbsG(fuelLog) / (duration / 60.0);
  }

  /// Why [activity] is (or isn't) tracked against the fueling baseline.
  CarbsHrExclusionReason exclusionReason(Activity activity) {
    if (activity.activityType == ActivityType.swimming) {
      return CarbsHrExclusionReason.swim;
    }
    final duration = effectiveDurationMinutes(activity);
    if (duration == null || duration < minimumDurationMinutes) {
      return CarbsHrExclusionReason.tooShort;
    }
    if (_isSpeedWork(activity)) {
      return CarbsHrExclusionReason.speedWork;
    }
    return CarbsHrExclusionReason.none;
  }

  /// True when the workout reads as a short/intense session that shouldn't be
  /// compared against the long-effort fueling baseline.
  bool _isSpeedWork(Activity activity) {
    const markers = [
      'interval',
      'speed',
      'sprint',
      'tempo',
      'fartlek',
      'track',
    ];
    final subtype = activity.workoutSubtype?.toLowerCase() ?? '';
    if (markers.any(subtype.contains)) return true;
    if ((activity.cyclingSessionGoal?.toLowerCase() ?? '') == 'intervals') {
      return true;
    }
    return false;
  }

  /// Per-session carbs/hr for a *historical* activity, read from its stored
  /// `fuelLogData`. Returns null when there is no logged fuel to divide.
  double? historicalCarbRate(Activity activity) {
    final raw = activity.fuelLogData;
    if (raw == null) return null;
    final fuelLog = FuelLogData.fromJson(raw);
    return sessionCarbRate(activity, fuelLog);
  }

  /// Assemble the full summary for the card. [targetGPerH] is the planned
  /// during carb rate used for the trend's target line, when known.
  CarbsPerHourSummary buildSummary({
    required Activity activity,
    required FuelLogData fuelLog,
    required CarbsPerHourBaseline baseline,
    double? targetGPerH,
  }) {
    final reason = exclusionReason(activity);
    final duration = effectiveDurationMinutes(activity) ?? 0;
    final totalDuring = duringCarbsG(fuelLog);
    final rate = duration > 0 ? totalDuring / (duration / 60.0) : 0.0;

    if (reason != CarbsHrExclusionReason.none) {
      return CarbsPerHourSummary(
        state: CarbsHrState.excluded,
        activityType: activity.activityType,
        carbsPerHour: rate,
        totalDuringCarbsG: totalDuring,
        durationMinutes: duration,
        targetGPerH: targetGPerH,
        trend: const <double>[],
        baselineAverage: baseline.average,
        baselineCount: baseline.count,
        exclusionReason: reason,
        unlockThreshold: unlockThreshold,
        minimumDurationMinutes: minimumDurationMinutes,
      );
    }

    final isBuilding = baseline.count < unlockThreshold;
    final trend = isBuilding ? const <double>[] : [...baseline.history, rate];

    return CarbsPerHourSummary(
      state: isBuilding
          ? CarbsHrState.buildingBaseline
          : CarbsHrState.inBaseline,
      activityType: activity.activityType,
      carbsPerHour: rate,
      totalDuringCarbsG: totalDuring,
      durationMinutes: duration,
      targetGPerH: targetGPerH,
      trend: trend,
      baselineAverage: baseline.average,
      baselineCount: baseline.count,
      exclusionReason: CarbsHrExclusionReason.none,
      unlockThreshold: unlockThreshold,
      minimumDurationMinutes: minimumDurationMinutes,
    );
  }

  /// Reduce recent same-sport activities (most-recent-first) into a baseline:
  /// qualifying per-session rates trimmed to the trend window, chronological.
  CarbsPerHourBaseline baselineFromHistory(
    List<Activity> recentMostRecentFirst,
  ) {
    final rates = <double>[];
    for (final activity in recentMostRecentFirst) {
      if (exclusionReason(activity) != CarbsHrExclusionReason.none) continue;
      final rate = historicalCarbRate(activity);
      if (rate == null || rate <= 0) continue;
      rates.add(rate);
    }
    // rates is most-recent-first; take the window's worth of priors and flip
    // to oldest → newest for the sparkline.
    final history = rates.take(priorTrendPoints).toList().reversed.toList();
    return CarbsPerHourBaseline(history: history, count: rates.length);
  }
}
