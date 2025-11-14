import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Activity card action buttons (check and X)
///
/// Displays two action buttons on the right side of activity cards:
/// - Check mark: Mark activity as completed
/// - X mark: Delete activity
///
/// Specifications from Kyle's design:
/// - Size: 36px × 36px circles
/// - Border: 1px solid (Cream in dark, Blackberry in light)
/// - Icon size: 18px
/// - Spacing: 8px between buttons
///
/// Example:
/// ```dart
/// ActivityActionButtons(
///   onComplete: () async {
///     await completeActivity(activity);
///   },
///   onDelete: () async {
///     await deleteActivity(activity);
///   },
/// )
/// ```
class ActivityActionButtons extends StatelessWidget {
  const ActivityActionButtons({
    super.key,
    required this.onComplete,
    required this.onDelete,
    this.isCompleted = false,
  });

  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Complete button
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.electrolyte : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? AppColors.electrolyte : AppColors.orange,
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(
              isCompleted ? FontAwesomeIcons.check : FontAwesomeIcons.check,
            ),
            iconSize: 16,
            color: isCompleted ? AppColors.blackberry : iconColor,
            onPressed: onComplete,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 8),
        // Delete button
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.orange,
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(FontAwesomeIcons.xmark),
            iconSize: 16,
            color: iconColor,
            onPressed: onDelete,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
