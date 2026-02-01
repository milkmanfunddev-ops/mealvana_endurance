import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Displays sync status timestamp and refresh button for synced activities
///
/// Shows "Last updated: Jan 16, 2026 at 3:42 PM" with a refresh icon button.
/// Only visible for activities synced from external providers (Final Surge, Training Peaks).
class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({
    super.key,
    required this.lastSyncAt,
    required this.onRefresh,
    required this.isLoading,
    required this.isSyncedActivity,
  });

  /// Last sync timestamp from the activity
  final DateTime? lastSyncAt;

  /// Callback when refresh button is tapped
  final VoidCallback? onRefresh;

  /// Whether refresh is in progress
  final bool isLoading;

  /// Whether this is a synced activity (from Final Surge, Training Peaks, etc.)
  /// If false, this widget displays nothing
  final bool isSyncedActivity;

  @override
  Widget build(BuildContext context) {
    // Don't show anything if this isn't a synced activity
    if (!isSyncedActivity || lastSyncAt == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.blackberryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sync icon (static)
          Icon(
            Icons.sync,
            size: 16,
            color: AppColors.electrolyte.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.xs),

          // "Last updated" timestamp
          Text(
            _formatSyncTimestamp(lastSyncAt!),
            style: AppTextStyles.smallLabel.copyWith(
              color: AppColors.textDarkSecondary,
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Refresh button or loading spinner
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.electrolyte,
              ),
            )
          else
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.electrolyte.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xxs),
                ),
                child: Icon(
                  Icons.refresh,
                  size: 16,
                  color: AppColors.electrolyte,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Format timestamp as "Last updated: Jan 16, 2026 at 3:42 PM"
  String _formatSyncTimestamp(DateTime timestamp) {
    // Format: "MMM d, yyyy 'at' h:mm a"
    // Example: "Jan 16, 2026 at 3:42 PM"
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    final dateStr = dateFormat.format(timestamp);
    final timeStr = timeFormat.format(timestamp);

    return 'Last updated: $dateStr at $timeStr';
  }
}
