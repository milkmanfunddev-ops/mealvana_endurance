/// Semantic status for an actual nutrition value compared with its target.
///
/// This is intentionally independent of Flutter colors so plan generation
/// diagnostics and Activity Details always use the same thresholds.
enum MacroTargetStatus { green, nonGreen, severe }

MacroTargetStatus classifyMacroTarget({
  required int actual,
  required int target,
  int? low,
  int? high,
}) {
  if (low != null && high != null && (low > 0 || high > 0)) {
    if (actual >= low && actual <= high) {
      return MacroTargetStatus.green;
    }

    final margin = (high - low) * 0.2;
    if (actual >= low - margin && actual <= high + margin) {
      return MacroTargetStatus.nonGreen;
    }
    return MacroTargetStatus.severe;
  }

  if (target <= 0) {
    return MacroTargetStatus.green;
  }

  final ratio = actual / target;
  if (ratio >= 0.8 && ratio <= 1.2) {
    return MacroTargetStatus.green;
  }
  if (ratio >= 0.6 && ratio <= 1.5) {
    return MacroTargetStatus.nonGreen;
  }
  return MacroTargetStatus.severe;
}
