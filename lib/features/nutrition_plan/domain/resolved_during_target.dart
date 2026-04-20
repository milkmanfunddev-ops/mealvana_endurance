import '../../../shared/domain/activity_type.dart';

/// Source of truth for the currently displayed during target.
enum ResolvedDuringTargetSource {
  /// Values are from the generated macro snapshot.
  snapshot,

  /// Snapshot values match an applied settings override.
  snapshotOverrideApplied,
}

/// Canonical during target used for UI rendering.
///
/// This keeps badge/formula/range displays aligned from one resolved value.
class ResolvedDuringTarget {
  const ResolvedDuringTarget({
    required this.sport,
    required this.rateGPerH,
    required this.totalG,
    required this.source,
    required this.isOverrideApplied,
    required this.isStaleVsSettings,
    this.rangeLowG,
    this.rangeHighG,
    this.settingsOverrideRateGPerH,
  });

  final ActivityType sport;
  final double rateGPerH;
  final double totalG;
  final double? rangeLowG;
  final double? rangeHighG;
  final ResolvedDuringTargetSource source;
  final bool isOverrideApplied;
  final bool isStaleVsSettings;
  final double? settingsOverrideRateGPerH;
}
