import '../../../../shared/domain/activity_type.dart';

/// Which visual the carbs/hr card renders.
///
/// - [inBaseline]: long effort with enough same-sport history to plot a trend.
/// - [buildingBaseline]: long effort, but fewer than the unlock threshold of
///   prior same-sport efforts — show progress dots instead of a trend.
/// - [excluded]: this effort is not tracked against the fueling baseline
///   (too short, a swim, or speed work).
enum CarbsHrState { inBaseline, buildingBaseline, excluded }

/// Why a session is excluded from carbs/hr tracking. Drives the card copy.
enum CarbsHrExclusionReason { none, tooShort, swim, speedWork }

/// The same-sport fueling history a session is compared against.
///
/// [history] holds the per-session carbs/hr of prior qualifying efforts in
/// chronological order (oldest → newest) and is already trimmed to the trend
/// window. [count] is the total number of qualifying prior efforts (which can
/// exceed [history].length) and is what gates the [CarbsHrState.inBaseline]
/// unlock.
class CarbsPerHourBaseline {
  const CarbsPerHourBaseline({required this.history, required this.count});

  final List<double> history;
  final int count;

  double? get average =>
      history.isEmpty ? null : history.reduce((a, b) => a + b) / history.length;

  static const CarbsPerHourBaseline empty =
      CarbsPerHourBaseline(history: <double>[], count: 0);
}

/// Everything the carbs/hr card needs to render, assembled by
/// [CarbsPerHourService.buildSummary]. UI-only formatting (labels, colours)
/// stays in the widget.
class CarbsPerHourSummary {
  const CarbsPerHourSummary({
    required this.state,
    required this.activityType,
    required this.carbsPerHour,
    required this.totalDuringCarbsG,
    required this.durationMinutes,
    required this.targetGPerH,
    required this.trend,
    required this.baselineAverage,
    required this.baselineCount,
    required this.exclusionReason,
    required this.unlockThreshold,
    required this.minimumDurationMinutes,
  });

  /// Which card variant to render.
  final CarbsHrState state;

  /// Sport of the effort (drives icon + "Runs"/"Rides" label).
  final ActivityType activityType;

  /// This session's carbs/hr (during-effort carbs ÷ duration). Unrounded.
  final double carbsPerHour;

  /// Total during-effort carbs consumed this session (the numerator).
  final int totalDuringCarbsG;

  /// Effective workout duration in minutes (actual, falling back to planned).
  final int durationMinutes;

  /// Planned during carb rate used as the trend's target line, if known.
  final double? targetGPerH;

  /// Sparkline points oldest → newest, ending with this session. Only
  /// populated for [CarbsHrState.inBaseline].
  final List<double> trend;

  /// Mean carbs/hr of the prior qualifying same-sport efforts, if any.
  final double? baselineAverage;

  /// Total number of prior qualifying same-sport efforts.
  final int baselineCount;

  /// Why the session is excluded (only meaningful when [state] is excluded).
  final CarbsHrExclusionReason exclusionReason;

  /// Number of qualifying efforts needed before the trend unlocks.
  final int unlockThreshold;

  /// Minimum effort length (minutes) for carbs/hr to be tracked.
  final int minimumDurationMinutes;

  /// Signed difference of this session vs the baseline average, if available.
  double? get deltaVsAverage =>
      baselineAverage == null ? null : carbsPerHour - baselineAverage!;

  /// True when this session's rate meets or exceeds every prior effort.
  ///
  /// Assumes [trend] ends with this session's [carbsPerHour] (the contract
  /// documented on [trend] and enforced by `CarbsPerHourService.buildSummary`).
  bool get isHighestYet {
    assert(
      trend.isEmpty || trend.last == carbsPerHour,
      'trend must end with the current session carbsPerHour',
    );
    if (trend.length < 2) return false;
    final prior = trend.sublist(0, trend.length - 1);
    return carbsPerHour >= prior.reduce((a, b) => a > b ? a : b);
  }
}
