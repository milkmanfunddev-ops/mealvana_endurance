import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/kyle_design/kyle_design.dart';

/// Widget that displays food category selection checkboxes.
/// Allows users to select when they would eat this food (before/during/after run).
class CategorySelector extends StatelessWidget {
  final Map<int, bool> selectedCategories;
  final ValueChanged<Map<int, bool>> onCategoriesChanged;

  const CategorySelector({
    super.key,
    required this.selectedCategories,
    required this.onCategoriesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const ValueKey('custom_food.timing_section'),
          'When would you eat this?',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          key: const ValueKey('custom_food.timing_body'),
          'Select all that apply (optional)',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Category checkboxes
        _buildCategoryCheckbox(
          checkboxKey: const ValueKey('custom_food.timing_before_run'),
          context: context,
          categoryId: 1,
          title: 'Before Run',
          subtitle: 'Fuel up before your workout',
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildCategoryCheckbox(
          checkboxKey: const ValueKey('custom_food.timing_during_run'),
          context: context,
          categoryId: 2,
          title: 'During Run',
          subtitle: 'Energy during long workouts',
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildCategoryCheckbox(
          checkboxKey: const ValueKey('custom_food.timing_after_run'),
          context: context,
          categoryId: 3,
          title: 'After Run',
          subtitle: 'Recovery after your workout',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildCategoryCheckbox({
    required BuildContext context,
    required int categoryId,
    required String title,
    required String subtitle,
    required bool isDark,
    Key? checkboxKey,
  }) {
    final isSelected = selectedCategories[categoryId] ?? false;

    return GestureDetector(
      key: checkboxKey,
      onTap: () {
        final updatedCategories = Map<int, bool>.from(selectedCategories);
        updatedCategories[categoryId] = !isSelected;
        onCategoriesChanged(updatedCategories);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electrolyte.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.electrolyte
                : isDark
                ? AppColors.cream.withValues(alpha: 0.3)
                : AppColors.blackberry.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.electrolyte : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? AppColors.electrolyte
                      : isDark
                      ? AppColors.cream.withValues(alpha: 0.5)
                      : AppColors.blackberry.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const FaIcon(
                      FontAwesomeIcons.check,
                      color: AppColors.blackberry,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
