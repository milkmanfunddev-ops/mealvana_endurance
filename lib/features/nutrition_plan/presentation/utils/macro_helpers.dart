import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../providers/macro_targets_controller.dart';
import '../../domain/macro_targets.dart' as domain;

/// Utility class for Macro Targets Screen
/// Contains formatting and text mapping logic
class MacroHelpers {
  // Private constructor to prevent instantiation
  MacroHelpers._();

  /// Get activity type text from macroTargets ("During this Run", "During this Ride", etc.)
  static String getActivityTypeText(domain.MacroTargets? macroTargets) {
    if (macroTargets == null) return 'During this Activity';

    switch (macroTargets.activityType) {
      case ActivityType.running:
        return 'During this Run';
      case ActivityType.cycling:
        return 'During this Ride';
      case ActivityType.swimming:
        return 'During this Swim';
      case ActivityType.brick:
        return 'During this Brick';
      default:
        return 'During this Activity';
    }
  }

  /// Format activity info as "1.8 h • 12MI" from macro targets
  static String formatActivityInfo(MacroTargetsState state) {
    final macros = state.macroTargets;
    if (macros == null) return '';

    // Use duration and distance from metrics
    final durationStr = '${macros.metrics.durationH.toStringAsFixed(1)} h';
    final distanceStr = '${macros.metrics.distanceMi.toStringAsFixed(0)}MI';

    return '$durationStr  •  $distanceStr';
  }

  /// Format pace value from macro targets
  /// Returns "8:30/mi" for running, "15.5 mph" for cycling, "1:45/100m" for swimming
  static String formatPaceValue(MacroTargetsState state) {
    final macros = state.macroTargets;
    if (macros == null) return '--';

    switch (macros.activityType) {
      case ActivityType.running:
        final pace = macros.metrics.paceMinPerMile ?? 8.5;
        return '${UnitFormatter.formatMinutesAsMinSec(pace)}/mi';

      case ActivityType.cycling:
        final speed = macros.metrics.speedMph;
        return '${speed.toStringAsFixed(1)} mph';

      case ActivityType.swimming:
        // Swimming uses pace per 100m, calculated from distance and duration
        final distanceMeters = macros.metrics.distanceKm * 1000;
        final durationMinutes = macros.metrics.durationH * 60;
        final pacePer100m =
            (durationMinutes / (distanceMeters / 100)) * 60; // seconds per 100m
        final minutes = pacePer100m.floor() ~/ 60;
        final seconds = pacePer100m.floor() % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}/100m';

      default:
        return '--';
    }
  }

  /// Format markdown text by removing ** symbols
  /// (Simple implementation - could be enhanced with RichText)
  static String formatMarkdownText(String text) {
    return text.replaceAll('**', '');
  }
}
