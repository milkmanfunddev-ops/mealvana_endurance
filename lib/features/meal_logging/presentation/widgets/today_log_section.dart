import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_log.dart';
import '../providers/meal_log_providers.dart';
import '../screens/log_meal_screen.dart';
import 'meal_log_row.dart';

/// Displays the list of meal log entries for [selectedDate] and a button
/// to open the log-method picker sheet.
class TodayLogSection extends ConsumerWidget {
  const TodayLogSection({super.key, required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final logsAsync = ref.watch(mealLogsForDateProvider(dateStr));
    final isToday = _isToday(selectedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isToday
                  ? "Today's Log"
                  : 'Meals on ${DateFormat('MMM d').format(selectedDate)}',
              style: AppTextStyles.sectionTitle.copyWith(
                color: textColor.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            _AddButton(onPressed: () => _openLogSheet(context, ref, dateStr)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return GestureDetector(
                onTap: () => _openLogSheet(context, ref, dateStr),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (isDark ? AppColors.cream : AppColors.blackberry)
                          .withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 20,
                        color: textColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Log your first meal',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: logs
                  .map(
                    (log) => MealLogRow(
                      log: log,
                      onDelete: () => _deleteWithUndo(context, ref, log),
                      onEdit: () =>
                          context.push('/meal-log/edit', extra: {'log': log}),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

// ---------------------------------------------------------------------------
// Add button shown in the section header
// ---------------------------------------------------------------------------

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.orange, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: AppColors.orange),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft-deletes [log] and shows an undo snackbar that restores the entry.
///
/// The delete is applied immediately (offline-first); the snackbar gives the
/// user a brief window to undo before the tombstone propagates to Supabase.
void _deleteWithUndo(BuildContext context, WidgetRef ref, MealLog log) {
  // Clear any snackbar already in flight so a rapid double-swipe can't queue
  // two "Meal deleted" toasts back to back (parity with the Fuel Timeline).
  final messenger = ScaffoldMessenger.of(context);
  ref.read(mealLogControllerProvider.notifier).deleteLog(log.id);
  messenger.clearSnackBars();

  MealvanaSnackbar.showInfo(
    context,
    'Meal deleted',
    actionLabel: 'Undo',
    onAction: () =>
        ref.read(mealLogControllerProvider.notifier).restoreLog(log.id),
  );
}

/// Opens the full-screen "Log a Meal" experience.
void _openLogSheet(BuildContext context, WidgetRef ref, String dateStr) {
  openLogMealScreen(context, logDate: dateStr, source: 'today_log_section');
}

// ---------------------------------------------------------------------------
// Legacy MealLogMethodSheet — kept for the re-export in meal_log_method_sheet.dart
// and for callers that navigate to it directly.  The default entry point from
// TodayLogSection now opens [LogMealScreen] via [openLogMealScreen].
// ---------------------------------------------------------------------------

/// Bottom sheet presenting the five meal-logging entry methods (legacy).
///
/// Declared here so [today_log_section.dart] stays self-contained.
/// The separate file `meal_log_method_sheet.dart` re-exports this class.
class MealLogMethodSheet extends ConsumerWidget {
  const MealLogMethodSheet({
    super.key,
    required this.logDate,
    required this.onMethodSelected,
  });

  final String logDate;
  final void Function(String method) onMethodSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final describeMealEnabled = ref.watch(
      appConfigProvider.select((config) => config.describeMealEnabled),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Log a Meal',
            style: AppTextStyles.pageTitle.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (describeMealEnabled) ...[
            _MethodTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take a Photo',
              subtitle: 'Mealvana AI identifies food and estimates macros',
              onTap: () => onMethodSelected('photo'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _MethodTile(
            icon: Icons.edit_outlined,
            title: 'Enter Manually',
            subtitle: 'Type name and macros by hand',
            onTap: () => onMethodSelected('manual'),
          ),
          if (describeMealEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            _MethodTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Describe to Mealvana',
              subtitle: 'Tell Mealvana what you ate in plain language',
              onTap: () => onMethodSelected('describe'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _MethodTile(
            icon: Icons.history_outlined,
            title: 'Recent & Saved',
            subtitle: 'Re-log a recent or saved meal',
            onTap: () => onMethodSelected('recent_saved'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MethodTile(
            icon: Icons.menu_book_outlined,
            title: 'From a Recipe',
            subtitle: 'Log a meal scaled from the recipe catalog',
            onTap: () => onMethodSelected('recipe'),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: isDark ? AppColors.electrolyte : AppColors.electrolyteDark,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.cream.withValues(alpha: 0.55)
                          : AppColors.blackberry.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
