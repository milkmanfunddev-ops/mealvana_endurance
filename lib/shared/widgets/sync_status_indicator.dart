import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import '../services/sync/sync_coordinator.dart';

/// Persistent sync status indicator shown in app bar during background sync
/// Displays a small progress indicator when data is being uploaded to Supabase
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncCoordinatorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Only show indicator when actively syncing
    if (syncState != SyncState.syncing) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blackberry.withOpacity(0.15)
            : AppColors.blackberry.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.blackberry.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark
                    ? AppColors.blackberry.withOpacity(0.8)
                    : AppColors.blackberry,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Syncing your data...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.blackberry.withOpacity(0.9)
                  : AppColors.blackberry,
            ),
          ),
        ],
      ),
    );
  }
}
