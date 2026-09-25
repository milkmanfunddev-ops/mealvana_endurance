import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/data/macro_pill_row.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import '../../domain/meal_photo.dart';
import 'card_overflow_menu.dart';
import 'meal_photo_view.dart';
import 'vana_tag.dart';

/// A [MealRef] presented as a tappable row: picture, name, what it is made of,
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
///
/// [slot] is what the card draws where a picture goes; a list passes the one
/// `photosForList` gave it so no photograph repeats. Omitted, the card draws
/// the Meal's own photo — or nothing at all, which takes no space (ADR 0003).
///
/// [subtitle] is the line under the name, and callers pass the ingredients.
/// With none, or one that only repeats the name (a meal saved from a log
/// carries the dish as its one item), the card shows no line. It never falls
/// back to `why`: a library Meal's `why` is its research note, not a
/// description (testing-wave 18-004, 89-003).
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
    this.slot,
    this.subtitle,
  });

  final MealRef meal;
  final MealPhotoSlot? slot;
  final String? subtitle;
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
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final secondary = textColor.withValues(alpha: 0.55);
    final thumb = compact ? 32.0 : 36.0;
    final photo = slot == null ? meal.photo : slot!.photo;
    final line = subtitle?.trim() ?? '';
    final showLine =
        line.isNotEmpty && line.toLowerCase() != meal.name.trim().toLowerCase();

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
                // The Meal's Dish photo, or no picture slot at all: a Meal
                // without one starts at its name, and the names and macros of
                // a list mixing the two still line up (ADR 0003).
                MealPhotoThumb(
                  photo: photo,
                  size: thumb,
                  borderRadius: BorderRadius.circular(9),
                ),
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
                      if (!compact && showLine) ...[
                        const SizedBox(height: 3),
                        Text(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: secondary,
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
                                color: secondary,
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
                  Align(alignment: Alignment.center, child: trailing!),
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
