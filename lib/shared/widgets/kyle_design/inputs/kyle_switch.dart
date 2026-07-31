import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

/// Branded switch used across the app for consistent cross-platform styling.
///
/// Design decisions:
/// - Always uses a white thumb for readability in both themes
/// - Uses electrolyte accent for selected track
/// - Hides the default track outline for a cleaner Kyle look
class KyleSwitch extends StatelessWidget {
  const KyleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.materialTapTargetSize,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final MaterialTapTargetSize? materialTapTargetSize;

  /// Optional spoken label for screen readers (e.g., "Fasted workout").
  /// When omitted, the adjacent label text typically supplies context, but
  /// providing a label here makes the switch self-describing in isolation.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTrack =
        activeTrackColor ??
        (isDark ? AppColors.electrolyte : AppColors.electrolyteDark);
    final unselectedTrack =
        inactiveTrackColor ??
        Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: isDark ? 0.32 : 0.26);

    final widget = Switch(
      value: value,
      onChanged: enabled ? onChanged : null,
      materialTapTargetSize: materialTapTargetSize,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withValues(alpha: 0.65);
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return unselectedTrack.withValues(alpha: 0.45);
        }
        if (states.contains(WidgetState.selected)) {
          return selectedTrack;
        }
        return unselectedTrack;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );

    if (semanticLabel == null) return widget;
    return Semantics(label: semanticLabel, toggled: value, child: widget);
  }
}
