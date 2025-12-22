import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// A card widget with a toggle switch for boolean options
///
/// Used for yes/no questions in sport detail screens:
/// - "Do you run with a water bottle?"
/// - "Do you have an aero bottle?"
/// - "Do you have a bento box?"
/// - "Do you typically wear a wetsuit?"
///
/// Features:
/// - Toggle switch on the right side
/// - Label and optional description
/// - Optional icon or emoji
class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.icon,
    this.emoji,
    this.enabled = true,
  });

  /// The main label text (question)
  final String label;

  /// Current toggle value
  final bool value;

  /// Called when the toggle value changes
  final ValueChanged<bool> onChanged;

  /// Optional description text below the label
  final String? description;

  /// Optional icon to display
  final IconData? icon;

  /// Optional emoji to display (takes precedence over icon)
  final String? emoji;

  /// Whether the toggle is enabled for interaction
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: AppColors.borderLightSecondary,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon or emoji
          if (emoji != null || icon != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: emoji != null
                  ? Text(
                      emoji!,
                      style: const TextStyle(fontSize: 24),
                    )
                  : Icon(
                      icon,
                      size: 24,
                      color: value
                          ? AppColors.orange
                          : AppColors.textLightSecondary,
                    ),
            ),

          // Label and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: enabled ? AppColors.textLight : AppColors.inactive,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLightSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Toggle switch
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.orange,
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.orange.withValues(alpha: 0.5);
              }
              return AppColors.inactive.withValues(alpha: 0.3);
            }),
          ),
        ],
      ),
    );
  }
}

/// A simpler toggle row without card styling
///
/// Used for inline toggle options within a larger form
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: enabled ? AppColors.textLight : AppColors.inactive,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLightSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.orange,
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.orange.withValues(alpha: 0.5);
              }
              return AppColors.inactive.withValues(alpha: 0.3);
            }),
          ),
        ],
      ),
    );
  }
}
