import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Brick Ungroup Dialog
///
/// Shows before ungrouping a brick workout.
/// Warns user that ungrouping will restore original activities to standalone status.
///
/// Returns true if user confirms ungrouping, false if cancelled.
class BrickUngroupDialog extends StatelessWidget {
  const BrickUngroupDialog({
    super.key,
    required this.segmentCount,
  });

  final int segmentCount;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.triangleExclamation,
                size: AppIconSizes.xl,
                color: AppColors.orange,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Ungroup Brick Workout?',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Description
            Text(
              'Ungrouping will restore $segmentCount ${segmentCount == 1 ? 'activity' : 'activities'} to standalone workouts.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Info message
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: AppRadius.inputRadius,
              ),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.circleInfo,
                    size: AppIconSizes.sm,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'The brick workout will be deleted and nutrition plan removed',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Ungroup button
            KylePrimaryButton(
              text: 'Ungroup',
              onPressed: () => Navigator.of(context).pop(true),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Cancel button
            KyleTertiaryButton(
              text: 'Cancel',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
