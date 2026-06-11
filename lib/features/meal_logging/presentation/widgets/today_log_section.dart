import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../providers/meal_log_providers.dart';
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
        Text(
          isToday ? "Today's Log" : 'Meals on ${DateFormat('MMM d').format(selectedDate)}',
          style: AppTextStyles.sectionTitle.copyWith(
            color: textColor.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    'No meals logged yet.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: logs
                  .map(
                    (log) => MealLogRow(
                      log: log,
                      onDelete: () => ref
                          .read(mealLogControllerProvider.notifier)
                          .deleteLog(log.id),
                      onSaveFavorite: (name) => ref
                          .read(mealLogControllerProvider.notifier)
                          .saveLogAsFavorite(log, customName: name),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.md),
        KylePrimaryButton(
          text: 'Log a meal',
          onPressed: () => _openLogSheet(context, ref, dateStr),
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

/// Opens the meal log method selection sheet.
void _openLogSheet(BuildContext context, WidgetRef ref, String dateStr) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MealLogMethodSheet(
      logDate: dateStr,
      onMethodSelected: (method) {
        Navigator.of(context).pop();
        switch (method) {
          case 'photo':
            context.push('/meal-log/photo', extra: {'logDate': dateStr});
            break;
          case 'manual':
            context.push('/meal-log/manual', extra: {'logDate': dateStr});
            break;
          case 'describe':
            context.push('/meal-log/describe', extra: {'logDate': dateStr});
            break;
          case 'recent_saved':
            context.push(
                '/meal-log/recent-saved', extra: {'logDate': dateStr});
            break;
          case 'recipe':
            context.push('/meal-log/recipe', extra: {'logDate': dateStr});
            break;
        }
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Inline method sheet (avoids a separate import cycle)
// ---------------------------------------------------------------------------

/// Bottom sheet presenting the five meal-logging entry methods.
///
/// Declared here so [today_log_section.dart] stays self-contained.
/// The separate file `meal_log_method_sheet.dart` re-exports this class.
class MealLogMethodSheet extends StatelessWidget {
  const MealLogMethodSheet({
    super.key,
    required this.logDate,
    required this.onMethodSelected,
  });

  final String logDate;
  final void Function(String method) onMethodSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;

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
          _MethodTile(
            icon: Icons.camera_alt_outlined,
            title: 'Take a Photo',
            subtitle: 'Jade AI identifies food and estimates macros',
            onTap: () => onMethodSelected('photo'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MethodTile(
            icon: Icons.edit_outlined,
            title: 'Enter Manually',
            subtitle: 'Type name and macros by hand',
            onTap: () => onMethodSelected('manual'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MethodTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Describe to Jade',
            subtitle: 'Tell Jade what you ate in plain language',
            onTap: () => onMethodSelected('describe'),
          ),
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
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 28,
                color: isDark ? AppColors.electrolyte : AppColors.electrolyteDark),
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
