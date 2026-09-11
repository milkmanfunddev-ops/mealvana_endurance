import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../application/shopping_list_controller.dart';
import '../../application/shopping_qty_formatter.dart';
import '../../domain/meal_icon.dart';
import '../../domain/plan_meal.dart';
import '../../domain/shopping_item.dart';
import 'meal_icon_glyphs.dart';
import 'slot_chip.dart';
import 'vana_avatar.dart';
import 'vana_bubble.dart';

/// The aisle-grouped shopping list: the item-count header, Vana's "I left
/// these off" note, and one card per aisle whose rows are checkbox · name ·
/// quantity. Toggles are local-first through [ShoppingListController]
/// (05 §4). Mirrors the prototype's `ShoppingList`.
///
/// Quantities render in [units] (Lee, 2026-09-07: US shoppers read pounds
/// and ounces; metric only when the athlete chose it in Settings). A line
/// built from more than one meal carries a small count badge, and tapping
/// any line's body opens a sheet naming the meals it came from, each of
/// which opens the recipe through [onOpenMeal].
class ShoppingList extends ConsumerWidget {
  const ShoppingList({
    super.key,
    required this.state,
    required this.onToggleChecked,
    required this.onAddBack,
    this.units = UnitSystem.imperial,
    this.onOpenMeal,
  });

  final ShoppingListState state;
  final void Function(ShoppingItem item, bool value) onToggleChecked;
  final ValueChanged<String> onAddBack;
  final UnitSystem units;

  /// Opens a source meal's recipe. Null disables the tap-through.
  final ValueChanged<PlanMeal>? onOpenMeal;

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
                      qty: formatShoppingQty(entry.value[i].qty, units),
                      sourceCount: state.sourcesOf(entry.value[i]).length,
                      isLast: i == entry.value.length - 1,
                      textColor: textColor,
                      secondary: secondary,
                      accent: accent,
                      onToggleChecked: (v) =>
                          onToggleChecked(entry.value[i], v),
                      onOpenSources: onOpenMeal == null
                          ? null
                          : () =>
                                _showSources(context, content, entry.value[i]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  void _showSources(
    BuildContext context,
    ContentService content,
    ShoppingItem item,
  ) {
    final sources = state.sourcesOf(item);
    if (sources.isEmpty) return;
    showAdaptiveModal<void>(
      context: context,
      builder: (sheetContext) => _SourcesSheet(
        item: item,
        qty: formatShoppingQty(item.qty, units),
        sources: sources,
        content: content,
        onOpenMeal: (meal) {
          Navigator.of(sheetContext).pop();
          onOpenMeal?.call(meal);
        },
      ),
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
/// The checkbox toggles; the rest of the row opens the source-meal sheet.
class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.item,
    required this.qty,
    required this.sourceCount,
    required this.isLast,
    required this.textColor,
    required this.secondary,
    required this.accent,
    required this.onToggleChecked,
    required this.onOpenSources,
  });

  final ShoppingItem item;

  /// [ShoppingItem.qty] already rendered in the athlete's units.
  final String qty;

  /// How many plan meals the line was built from (badge when > 1).
  final int sourceCount;
  final bool isLast;
  final Color textColor;
  final Color secondary;
  final Color accent;
  final ValueChanged<bool> onToggleChecked;
  final VoidCallback? onOpenSources;

  @override
  Widget build(BuildContext context) {
    final canOpen = onOpenSources != null && sourceCount > 0;
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
            child: GestureDetector(
              key: ValueKey('meal_planning.shopping_row_${item.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: canOpen ? onOpenSources : null,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: item.checked
                              ? textColor.withValues(alpha: 0.5)
                              : textColor,
                          decoration: item.checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (sourceCount > 1) ...[
                      const SizedBox(width: 8),
                      _CountBadge(
                        key: ValueKey(
                          'meal_planning.shopping_sources_${item.name}',
                        ),
                        count: sourceCount,
                        color: secondary,
                      ),
                    ],
                    const Spacer(),
                    if (qty.isNotEmpty)
                      Text(
                        qty,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet 18pt pill with the number of meals a line feeds — the only hint
/// that the row opens something, so it stays tonal (secondary text on a
/// 10% tint), never the accent.
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
          color: color,
        ),
      ),
    );
  }
}

/// The sheet behind a row: the ingredient and its amount up top, then one
/// tappable row per source meal (icon tile · name · slot · servings) that
/// opens the recipe. Kept to the list's own surfaces and type — no header
/// bar, no dividers heavier than the list's hairline.
class _SourcesSheet extends StatelessWidget {
  const _SourcesSheet({
    required this.item,
    required this.qty,
    required this.sources,
    required this.content,
    required this.onOpenMeal,
  });

  final ShoppingItem item;
  final String qty;
  final List<PlanMeal> sources;
  final ContentService content;
  final ValueChanged<PlanMeal> onOpenMeal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final hairline = textColor.withValues(alpha: 0.1);

    final label = content.getValue;
    final from = sources.length == 1
        ? label(ContentKeys.mpShoppingFromOne)
        : ContentKeys.format(label(ContentKeys.mpShoppingFromMany), {
            'n': sources.length,
          });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          key: const ValueKey('meal_planning.shopping_sources_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (qty.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    qty,
                    style: AppTextStyles.bodyMedium.copyWith(color: secondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$from · ${label(ContentKeys.mpShoppingSourcesHint)}',
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < sources.length; i++)
              _SourceRow(
                meal: sources[i],
                isLast: i == sources.length - 1,
                textColor: textColor,
                secondary: secondary,
                hairline: hairline,
                content: content,
                onTap: () => onOpenMeal(sources[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.meal,
    required this.isLast,
    required this.textColor,
    required this.secondary,
    required this.hairline,
    required this.content,
    required this.onTap,
  });

  final PlanMeal meal;
  final bool isLast;
  final Color textColor;
  final Color secondary;
  final Color hairline;
  final ContentService content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slot = SlotChip.shortLabelFor(content, meal.mealType);
    return InkWell(
      key: ValueKey('meal_planning.shopping_source_${meal.id}'),
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: hairline)),
        ),
        child: Row(
          children: [
            MealIconTile(
              icon: meal.icon ?? MealIcon.bowl,
              size: 32,
              mealType: meal.mealType,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$slot · ${meal.servings}×',
                    style: AppTextStyles.bodySmall.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: secondary),
          ],
        ),
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
