import 'package:flutter/material.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/brick_exceptions.dart';

/// Dialog shown when brick validation fails
///
/// Displays a user-friendly error message explaining why the brick cannot be created,
/// with appropriate actions based on the error type.
class BrickValidationErrorDialog extends StatelessWidget {
  const BrickValidationErrorDialog({
    super.key,
    required this.exception,
    this.onRetry,
  });

  final BrickValidationException exception;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine icon and title based on error code
    IconData icon;
    String title;
    String? actionText;

    switch (exception.code) {
      case 'MINIMUM_SPORTS':
        icon = Icons.sports;
        title = 'Need More Sports';
        actionText = 'Select Activities';
        break;
      case 'MAXIMUM_ACTIVITIES':
        icon = Icons.warning_rounded;
        title = 'Too Many Activities';
        actionText = 'Deselect Activities';
        break;
      case 'DUPLICATE_SPORTS':
        icon = Icons.content_copy_rounded;
        title = 'Duplicate Sports';
        actionText = 'Change Selection';
        break;
      case 'SAME_DAY_REQUIRED':
        icon = Icons.calendar_today_rounded;
        title = 'Different Days';
        actionText = 'Select Same Day';
        break;
      case 'INVALID_SEGMENT_ORDER':
        icon = Icons.format_list_numbered_rounded;
        title = 'Invalid Order';
        actionText = 'Try Again';
        break;
      default:
        icon = Icons.error_outline_rounded;
        title = 'Validation Error';
        actionText = 'Try Again';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.xl,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Error message
            Text(
              exception.message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action button
            KylePrimaryButton(
              text: actionText,
              onPressed: onRetry != null
                  ? () {
                      Navigator.of(context).pop(true);
                      onRetry!(); // Use null assertion since we checked above
                    }
                  : () => Navigator.of(context).pop(true),
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

/// Dialog shown when brick creation fails (non-validation errors)
///
/// Displays error message for database, network, or unknown errors
/// with retry option where applicable.
class BrickCreationErrorDialog extends StatelessWidget {
  const BrickCreationErrorDialog({
    super.key,
    required this.exception,
    this.onRetry,
  });

  final BrickCreationException exception;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine if error is retryable
    final isRetryable = exception.code == 'NETWORK_ERROR';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: AppIconSizes.xl,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Creation Failed',
              style: AppTextStyles.sectionTitle.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Error message
            Text(
              exception.message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action button
            if (isRetryable && onRetry != null)
              KylePrimaryButton(
                text: 'Retry',
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onRetry!();
                },
              )
            else
              KylePrimaryButton(
                text: 'OK',
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

/// Dialog shown when brick ungrouping fails
///
/// Displays error message for ungroup failures with retry option.
class BrickUngroupErrorDialog extends StatelessWidget {
  const BrickUngroupErrorDialog({
    super.key,
    required this.exception,
    this.onRetry,
  });

  final BrickUngroupException exception;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine if error is retryable
    final isRetryable = exception.code == 'NETWORK_ERROR';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: AppIconSizes.xl,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Ungroup Failed',
              style: AppTextStyles.sectionTitle.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Error message
            Text(
              exception.message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action button
            if (isRetryable && onRetry != null)
              KylePrimaryButton(
                text: 'Retry',
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onRetry!();
                },
              )
            else
              KylePrimaryButton(
                text: 'OK',
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

/// Dialog shown when brick macro generation fails
///
/// Displays error message for macro generation failures with retry option.
class BrickMacroGenerationErrorDialog extends StatelessWidget {
  const BrickMacroGenerationErrorDialog({
    super.key,
    required this.exception,
    this.onRetry,
  });

  final BrickMacroGenerationException exception;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // All macro generation errors are retryable except invalid segments
    final isRetryable = exception.code != 'INVALID_SEGMENTS';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: AppIconSizes.xl,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Macro Generation Failed',
              style: AppTextStyles.sectionTitle.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Error message
            Text(
              exception.message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action button
            if (isRetryable && onRetry != null)
              KylePrimaryButton(
                text: 'Retry',
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onRetry!();
                },
              )
            else
              KylePrimaryButton(
                text: 'OK',
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
