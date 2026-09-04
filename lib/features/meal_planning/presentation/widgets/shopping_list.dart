import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/shopping_list_controller.dart';
import '../../domain/shopping_item.dart';
import 'vana_avatar.dart';
import 'vana_bubble.dart';

/// The aisle-grouped shopping list: the item-count header, Vana's "I left
/// these off" note, and one card per aisle whose rows are checkbox · name ·
/// quantity. Toggles are local-first through [ShoppingListController]
/// (05 §4). Mirrors the prototype's `ShoppingList`.
class ShoppingList extends ConsumerWidget {
  const ShoppingList({
    super.key,
    required this.state,
    required this.onToggleChecked,
    required this.onAddBack,
  });

  final ShoppingListState state;
  final void Function(ShoppingItem item, bool value) onToggleChecked;
  final ValueChanged<String> onAddBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

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
          style: AppTextStyles.sectionTitle.copyWith(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          ContentKeys.format(content.getValue(ContentKeys.mpShoppingTotals), {
            'servings': state.totalServings,
            'meals': state.mealCount,
          }),
          style: AppTextStyles.bodySmall.copyWith(color: secondary),
        ),
        if (state.skipped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _LeftOffNote(
            skipped: state.skipped,
            onAddBack: () => onAddBack(state.skipped.first),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // Items the athlete already has are left off the list entirely and
        // named in Vana's note above, where "Add back" undoes it — as in the
        // prototype. Nothing here marks an item as "have"; Vana does that.
        for (final entry in state.byAisle.entries.map(
          (e) => MapEntry(e.key, e.value.where((i) => !i.have).toList()),
        ))
          if (entry.value.isNotEmpty) ...[
            Text(
              entry.key.toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < entry.value.length; i++)
                    _ShoppingRow(
                      item: entry.value[i],
                      isLast: i == entry.value.length - 1,
                      textColor: textColor,
                      secondary: secondary,
                      accent: accent,
                      onToggleChecked: (v) =>
                          onToggleChecked(entry.value[i], v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

/// "I left broccoli, carrots off — you have them. Add back" — said by Vana,
/// in her own bubble, as in the prototype.
class _LeftOffNote extends ConsumerWidget {
  const _LeftOffNote({required this.skipped, required this.onAddBack});

  final List<String> skipped;
  final VoidCallback onAddBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    final text = ContentKeys.format(
      content.getValue(
        skipped.length == 1
            ? ContentKeys.mpShoppingLeftOffOne
            : ContentKeys.mpShoppingLeftOffMany,
      ),
      {'items': skipped.map((s) => s.toLowerCase()).join(', ')},
    );

    return Row(
      key: const ValueKey('meal_planning.shopping_add_back'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VanaAvatar(size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: VanaBubble(
            compact: true,
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
                children: [
                  TextSpan(text: '$text '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: onAddBack,
                      child: Text(
                        content.getValue(ContentKeys.mpShoppingAddBackAction),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One 48pt list row inside an aisle card, hairline-separated from the next.
class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.item,
    required this.isLast,
    required this.textColor,
    required this.secondary,
    required this.accent,
    required this.onToggleChecked,
  });

  final ShoppingItem item;
  final bool isLast;
  final Color textColor;
  final Color secondary;
  final Color accent;
  final ValueChanged<bool> onToggleChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: textColor.withValues(alpha: 0.1)),
              ),
      ),
      child: Row(
        children: [
          _Check(
            key: ValueKey('meal_planning.shopping_check_${item.name}'),
            on: item.checked,
            accent: accent,
            border: textColor.withValues(alpha: 0.4),
            onTap: () => onToggleChecked(!item.checked),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: item.checked
                    ? textColor.withValues(alpha: 0.5)
                    : textColor,
                decoration: item.checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (item.qty.isNotEmpty)
            Text(
              item.qty,
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
        ],
      ),
    );
  }
}

/// The 22pt rounded-square checkbox from the prototype (`.v-check`) — a
/// filled electrolyte tile with a cut-out tick when on.
class _Check extends StatelessWidget {
  const _Check({
    super.key,
    required this.on,
    required this.accent,
    required this.border,
    required this.onTap,
  });

  final bool on;
  final Color accent;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: on ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: on ? accent : border, width: 1.5),
        ),
        child: on
            ? const Icon(Icons.check, size: 14, color: AppColors.blackberry)
            : null,
      ),
    );
  }
}
