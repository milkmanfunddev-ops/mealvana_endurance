import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/activity.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Brick Confirmation Dialog
///
/// Shows before creating a brick workout from selected activities.
/// Displays the selected activities in order with a preview of what will be created.
///
/// Returns true if user confirms, false if cancelled.
class BrickConfirmationDialog extends StatelessWidget {
  const BrickConfirmationDialog({
    super.key,
    required this.selectedActivities,
  });

  final List<Activity> selectedActivities;

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
            // Chain link icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.link,
                size: AppIconSizes.xl,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Create Brick Workout?',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Description
            Text(
              'This will combine the following activities:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Selected activities preview
            ...selectedActivities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    // Order number
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.electrolyte,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.smallLabel.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Activity type icon
                    Icon(
                      _getActivityIcon(activity.activityType),
                      size: AppIconSizes.md,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Activity name
                    Expanded(
                      child: Text(
                        activity.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.lg),

            // Info message
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.1),
                borderRadius: AppRadius.inputRadius,
              ),
              child: Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.circleInfo,
                    size: AppIconSizes.sm,
                    color: AppColors.electrolyte,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Original activities will be archived',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Create button
            KylePrimaryButton(
              text: 'Create Brick',
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

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return FontAwesomeIcons.personRunning;
      case ActivityType.cycling:
        return FontAwesomeIcons.personBiking;
      case ActivityType.swimming:
        return FontAwesomeIcons.personSwimming;
      case ActivityType.brick:
        return FontAwesomeIcons.link;
    }
  }
}
