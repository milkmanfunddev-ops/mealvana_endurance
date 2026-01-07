import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Dialog showing workout import progress from Final Surge
class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({
    super.key,
    required this.providerName,
    required this.isImporting,
    required this.importedCount,
    this.totalCount,
    this.errorMessage,
    this.onDismiss,
  });

  /// Provider name (e.g., "Final Surge")
  final String providerName;

  /// Whether import is in progress
  final bool isImporting;

  /// Number of workouts imported so far
  final int importedCount;

  /// Total number of workouts to import (if known)
  final int? totalCount;

  /// Error message if import failed
  final String? errorMessage;

  /// Callback when dialog is dismissed
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.blackberryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            _buildIcon(),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              _getTitle(),
              style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Status message
            Text(
              _getStatusMessage(),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDarkSecondary),
              textAlign: TextAlign.center,
            ),

            // Progress indicator
            if (isImporting) ...[
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(
                value: totalCount != null && totalCount! > 0
                    ? importedCount / totalCount!
                    : null,
                backgroundColor: AppColors.blackberry,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.dragonfruit),
              ),
            ],

            // Error message
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.dragonfruit.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.dragonfruit),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Dismiss button (only when not importing)
            if (!isImporting && onDismiss != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  'Continue',
                  style: AppTextStyles.buttonPrimary.copyWith(color: AppColors.dragonfruit),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (errorMessage != null) {
      return const Icon(
        Icons.error_outline,
        size: 48,
        color: AppColors.dragonfruit,
      );
    }

    if (isImporting) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.dragonfruit,
        ),
      );
    }

    return Icon(
      Icons.check_circle,
      size: 48,
      color: AppColors.success,
    );
  }

  String _getTitle() {
    if (errorMessage != null) {
      return 'Import Failed';
    }

    if (isImporting) {
      return 'Importing Workouts';
    }

    return 'Import Complete';
  }

  String _getStatusMessage() {
    if (errorMessage != null) {
      return 'There was a problem importing your workouts.';
    }

    if (isImporting) {
      if (totalCount != null && totalCount! > 0) {
        return 'Importing $importedCount of $totalCount workouts from $providerName...';
      }
      return 'Fetching workouts from $providerName...';
    }

    if (importedCount == 0) {
      return 'No upcoming workouts found in $providerName.';
    }

    if (importedCount == 1) {
      return 'Successfully imported 1 workout from $providerName.';
    }

    return 'Successfully imported $importedCount workouts from $providerName.';
  }
}

/// Show the import progress dialog
Future<void> showImportProgressDialog(
  BuildContext context, {
  required String providerName,
  required bool isImporting,
  required int importedCount,
  int? totalCount,
  String? errorMessage,
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: !isImporting,
    builder: (context) => ImportProgressDialog(
      providerName: providerName,
      isImporting: isImporting,
      importedCount: importedCount,
      totalCount: totalCount,
      errorMessage: errorMessage,
      onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
    ),
  );
}
