import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Warning banner displayed when nutrition plan is stale due to schedule changes
///
/// Shows when activity schedule has changed since nutrition plan was generated.
/// Gives user option to regenerate the plan or dismiss the warning.
class StalePlanWarning extends StatelessWidget {
  const StalePlanWarning({
    super.key,
    required this.onRegeneratePlan,
    this.onDismiss,
    this.isRegenerating = false,
    this.title = 'Schedule Changed',
    this.message =
        'Schedule has changed since this plan was generated. Regenerate to match your updated workout.',
    this.icon = Icons.schedule_outlined,
    this.buttonText = 'Regenerate Plan',
  });

  /// Callback when "Regenerate Plan" button is tapped
  final VoidCallback onRegeneratePlan;

  /// Optional callback when user dismisses the warning without regenerating
  final VoidCallback? onDismiss;

  /// Whether plan regeneration is in progress
  final bool isRegenerating;
  final String title;
  final String message;
  final IconData icon;
  final String buttonText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and warning text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning icon
              Icon(icon, color: AppColors.warning, size: 22),
              const SizedBox(width: AppSpacing.sm),

              // Warning message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Optional dismiss button
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Regenerate button
          GestureDetector(
            onTap: isRegenerating ? null : onRegeneratePlan,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isRegenerating
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.warning,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRegenerating)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textDark,
                      ),
                    )
                  else
                    Icon(Icons.refresh, size: 18, color: AppColors.textDark),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    isRegenerating ? 'Regenerating...' : buttonText,
                    style: AppTextStyles.buttonPrimary.copyWith(
                      color: AppColors.textDark,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
