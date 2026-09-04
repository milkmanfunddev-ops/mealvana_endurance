import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import 'vana_tag.dart';

/// `meal_picker` part body: an electrolyte-outlined card holding the picker
/// title, a "N in your plan" / "tap to add" hint, and a horizontal strip of
/// tall pick tiles. Mirrors the prototype's `MealPicker` + `MealTile`;
/// single-pick pickers fold immediately, multi-pick keep the tick showing
/// until the client chip confirms the batch (02 §3).
class MealPickerCarousel extends ConsumerWidget {
  const MealPickerCarousel({
    super.key,
    required this.title,
    required this.meals,
    required this.multi,
    required this.pickedIds,
    required this.onPick,
    this.onOpen,
    this.onSwap,
  });

  final String title;
  final List<MealRef> meals;
  final bool multi;

  /// Ids already picked in this picker (multi mode shows a tick).
  final Set<String> pickedIds;
  final ValueChanged<MealRef> onPick;

  /// Swap (opens the swap picker) — offered **only** on tiles whose id is
  /// in [pickedIds], i.e. meals already in the draft plan.
  /// Tap on the card body opens the meal's detail (recipe, ingredients,
  /// cooking mode); the tick is what adds it to the plan. Null → the whole
  /// card picks (legacy hosts).
  final ValueChanged<MealRef>? onOpen;
  final ValueChanged<MealRef>? onSwap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);

    final inPlan = meals.where((m) => pickedIds.contains(m.id)).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  title,
                  key: const ValueKey('meal_planning.picker_title'),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                inPlan > 0
                    ? ContentKeys.format(
                        content.getValue(ContentKeys.mpPickerInPlan),
                        {'n': inPlan},
                      )
                    : content.getValue(ContentKeys.mpPickerTapToAdd),
                style: AppTextStyles.bodySmall.copyWith(color: muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (meals.isEmpty)
            Text(
              content.getValue(ContentKeys.mpPickerEmpty),
              style: AppTextStyles.bodySmall.copyWith(color: muted),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final meal = meals[i];
                  final picked = pickedIds.contains(meal.id);
                  return _PickerTile(
                    key: ValueKey('meal_planning.picker_card_${meal.id}'),
                    meal: meal,
                    selected: picked,
                    onTap: () => (onOpen ?? onPick)(meal),
                    onPick: () => onPick(meal),
                    onSwap: picked && onSwap != null
                        ? () => onSwap!(meal)
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// One 188pt pick tile (2026-09-04 redesign): no meal icon — the tick is
/// the whole top-left, the name carries the tile, and a picked meal shows
/// a direct swap button top-right (no overflow menu). Tap on the body
/// opens the detail; the tick adds to the plan.
class _PickerTile extends ConsumerWidget {
  const _PickerTile({
    super.key,
    required this.meal,
    required this.selected,
    required this.onTap,
    required this.onPick,
    this.onSwap,
  });

  final MealRef meal;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPick;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return SizedBox(
      width: 188,
      child: Material(
        color: isDark ? AppColors.blackberry : AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? AppColors.electrolyte
                : textColor.withValues(alpha: 0.15),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      key: ValueKey('meal_planning.picker_tick_${meal.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onPick,
                      child: Padding(
                        // Right only: the tile is height-fixed and the tick
                        // should sit flush with the text block below.
                        padding: const EdgeInsets.only(right: 4),
                        child: _Tick(
                          on: selected,
                          border: textColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (onSwap != null)
                      Tooltip(
                        message: content.getValue(ContentKeys.mpBtnSwap),
                        child: GestureDetector(
                          key: ValueKey('meal_planning.picker_swap_${meal.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onSwap,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.swap_horiz,
                              size: 14,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Name + why as one clamped rich text — the whole block
                // ellipsizes together, so the tile can't overflow however
                // the text metrics run.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: meal.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: textColor,
                          ),
                        ),
                        TextSpan(text: '\n', style: TextStyle(height: 0.6)),
                        TextSpan(
                          text: meal.why,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                // Tags wrap when they don't fit beside the kcal figure —
                // the tile is only 188pt wide.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (meal.kind == MealKind.assembly)
                            const VanaTag(
                              label: 'No recipe',
                              tone: VanaTagTone.orange,
                            ),
                          if (meal.batch && !selected)
                            const VanaTag(label: 'Batch'),
                        ],
                      ),
                    ),
                    if (meal.kcal != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${meal.kcal} kcal',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The prototype's 22pt rounded-square tick, reused as the pick affordance.
class _Tick extends StatelessWidget {
  const _Tick({required this.on, required this.border});

  final bool on;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? AppColors.electrolyte : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: on ? AppColors.electrolyte : border,
          width: 1.5,
        ),
      ),
      child: on
          ? const Icon(Icons.check, size: 14, color: AppColors.blackberry)
          : null,
    );
  }
}
