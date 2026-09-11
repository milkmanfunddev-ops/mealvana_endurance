import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import 'vana_tag.dart';

/// `meal_picker` part body: an electrolyte-outlined card holding a
/// horizontal strip of pick tiles. Mirrors the prototype's `MealPicker` +
/// `MealTile`; single-pick pickers fold immediately, multi-pick keep the
/// tick showing until the client chip confirms the batch (02 §3).
///
/// 2026-09-07 (Lee's walkthrough): no title row, no "tap to add" hint and
/// no "why" blurb — the tiles are self-explanatory, and the prose above the
/// card already says what the batch is. [title] is kept on the API so the
/// part renderer and hosts need no change; it is not drawn.
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

  /// The picker's title from the part. Not rendered (see class doc).
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

  /// Tile height: two title lines plus the tag row.
  static const tileHeight = 104.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = textColor.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.25),
        ),
      ),
      child: meals.isEmpty
          ? Text(
              content.getValue(ContentKeys.mpPickerEmpty),
              style: TextStyle(fontSize: 12, height: 1.4, color: muted),
            )
          : SizedBox(
              height: tileHeight,
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
    );
  }
}

/// One 188pt pick tile: the name up top with the tick (plus a direct swap
/// button once picked) carved out to its right, and the tag pills alone at
/// the bottom. Tap on the body opens the detail; the tick adds to the plan.
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
                // Title up top with the tick (and swap, once picked) carved
                // out to its right — the name never runs under the controls.
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onSwap != null) ...[
                        Tooltip(
                          message: content.getValue(ContentKeys.mpBtnSwap),
                          child: GestureDetector(
                            key: ValueKey(
                              'meal_planning.picker_swap_${meal.id}',
                            ),
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
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(
                        key: ValueKey('meal_planning.picker_tick_${meal.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onPick,
                        child: _Tick(
                          on: selected,
                          border: textColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (meal.kind == MealKind.assembly)
                      const VanaTag(
                        label: 'No recipe',
                        tone: VanaTagTone.orange,
                      ),
                    if (meal.batch && !selected) const VanaTag(label: 'Batch'),
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
