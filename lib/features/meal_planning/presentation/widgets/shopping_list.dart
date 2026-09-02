import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/shopping_list_controller.dart';
import '../../domain/shopping_item.dart';

/// The aisle-grouped shopping list: header counts, the "left off — add
/// back" row, and per-aisle sections of checkbox + qty + "have it" chip.
/// Toggles are local-first through [ShoppingListController] (05 §4).
class ShoppingList extends ConsumerWidget {
  const ShoppingList({
    super.key,
    required this.state,
    required this.onToggleChecked,
    required this.onToggleHave,
    required this.onAddBack,
  });

  final ShoppingListState state;
  final void Function(ShoppingItem item, bool value) onToggleChecked;
  final void Function(ShoppingItem item, bool value) onToggleHave;
  final ValueChanged<String> onAddBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    if (state.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(
              content.getValue(ContentKeys.mpShoppingEmptyTitle),
              style: AppTextStyles.sectionTitle.copyWith(color: textColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              content.getValue(ContentKeys.mpShoppingEmptyBody),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ContentKeys.format(
            content.getValue(ContentKeys.mpShoppingItemCount),
            {'n': state.itemCount},
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          ContentKeys.format(content.getValue(ContentKeys.mpShoppingTotals), {
            'servings': state.totalServings,
            'meals': state.mealCount,
          }),
          style: AppTextStyles.bodySmall.copyWith(color: secondary),
        ),
        if (state.skipped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            key: const ValueKey('meal_planning.shopping_add_back'),
            onTap: () => onAddBack(state.skipped.first),
            child: Text(
              ContentKeys.format(
                content.getValue(ContentKeys.mpShoppingAddBack),
                {'items': state.skipped.join(', ')},
              ),
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.electrolyte : AppColors.electrolyteDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final entry in state.byAisle.entries)
          if (entry.value.isNotEmpty) ...[
            Text(
              entry.key,
              style: AppTextStyles.smallLabel.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...entry.value.map(
              (item) => _ShoppingRow(
                item: item,
                surface: surface,
                textColor: textColor,
                secondary: secondary,
                haveLabel: content.getValue(ContentKeys.mpShoppingHave),
                onToggleChecked: (v) => onToggleChecked(item, v),
                onToggleHave: (v) => onToggleHave(item, v),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.item,
    required this.surface,
    required this.textColor,
    required this.secondary,
    required this.haveLabel,
    required this.onToggleChecked,
    required this.onToggleHave,
  });

  final ShoppingItem item;
  final Color surface;
  final Color textColor;
  final Color secondary;
  final String haveLabel;
  final ValueChanged<bool> onToggleChecked;
  final ValueChanged<bool> onToggleHave;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.electrolyte
        : AppColors.electrolyteDark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              key: ValueKey('meal_planning.shopping_check_${item.name}'),
              value: item.checked,
              activeColor: accent,
              onChanged: (v) => onToggleChecked(v ?? false),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor,
                decoration: item.checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (item.qty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                item.qty,
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
            ),
          GestureDetector(
            key: ValueKey('meal_planning.shopping_have_${item.name}'),
            onTap: () => onToggleHave(!item.have),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: item.have
                    ? accent.withValues(alpha: 0.2)
                    : Colors.transparent,
                border: Border.all(color: accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                haveLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
