import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_icon_classifier.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import 'card_overflow_menu.dart';
import 'meal_icon_glyphs.dart';
import 'vana_tag.dart';

/// A [MealRef] presented as a tappable row: icon tile, name, the why-line,
/// then the tag strip (Yours · No recipe · Batch · prep · kcal). Mirrors the
/// prototype's `CatalogRow` on `.v-tile`. Used by the picker carousel,
/// search results and detail-adjacent lists.
///
/// With [showMacros] the kcal fact leaves the tag strip and a [MacroPillRow]
/// (kcal · carbs · protein · fat) renders beneath it — the library component
/// per `docs/ssot/spec/design/components/macro-pill-row.md` (MP-L3).
///
/// [greysWhen] renders the card disabled — the Meals tab greys cards the
/// athlete's allergens exclude even though the server already filters
/// suggestions (05 §4).
///
/// [onSwap] / [onRemove] add the `⋮` overflow (plan Phase 6.2) after
/// [trailing]; a card for a meal not in the plan passes neither and gets
/// no menu.
class MealCard extends ConsumerWidget {
  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    this.trailing,
    this.onSwap,
    this.onRemove,
    this.showMacros = false,
    this.excluded = false,
    this.compact = false,
  });

  final MealRef meal;
  final VoidCallback onTap;

  /// Optional right-aligned action (e.g. the picker's "Add").
  final Widget? trailing;

  /// Card-scoped Swap / Remove — renders the `⋮` menu when either is set.
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final bool showMacros;
  final bool excluded;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    // kcal sits in the tag strip only when the pill row is not showing it
    // (never twice — macro-pill-row MP-L3).
    final facts = <String>[
      if (meal.prepMinutes != null && meal.prepMinutes! > 0)
        '${meal.prepMinutes} min',
      if (!showMacros && meal.kcal != null) '${meal.kcal} kcal',
    ];
    final macros = showMacros
        ? MacroPillRow(
            kcal: meal.kcal,
            carbsG: meal.carbsG,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            compact: compact,
          )
        : null;

    return Opacity(
      opacity: excluded ? 0.45 : 1,
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: textColor.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MealIconTile(
                  icon: meal.effectiveIcon,
                  size: compact ? 32 : 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.foodTitle.copyWith(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (!compact && meal.why.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meal.why,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: textColor.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (meal.source == MealSource.saved)
                            const VanaTag(label: 'Yours'),
                          if (meal.kind == MealKind.assembly)
                            const VanaTag(
                              label: 'No recipe',
                              tone: VanaTagTone.orange,
                            ),
                          if (meal.batch) const VanaTag(label: 'Batch'),
                          for (final fact in facts)
                            Text(
                              fact,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: textColor.withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                      if (macros != null && !macros.isEmpty) ...[
                        const SizedBox(height: 5),
                        macros,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Align(
                    alignment: Alignment.center,
                    child: trailing!,
                  ),
                ],
                if (onSwap != null || onRemove != null) ...[
                  const SizedBox(width: 4),
                  CardOverflowMenu(
                    menuKey: ValueKey('meal_planning.card_overflow_${meal.id}'),
                    onSwap: onSwap,
                    onRemove: onRemove,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on MealRef {
  MealIcon get effectiveIcon =>
      icon ??
      MealIconClassifier.classify(
        name: name,
        ingredients: ingredients,
        pattern: pattern,
      );
}
