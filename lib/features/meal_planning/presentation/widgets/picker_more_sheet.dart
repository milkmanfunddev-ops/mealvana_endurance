import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/list_pictures.dart';
import '../../domain/meal_ref.dart';
import 'meal_add_button.dart';
import 'meal_card.dart';

/// "Show more" under a picker (mp-230 clause 2): the rest of the SAME search
/// the tiles came from, as a sheet. No new query runs — the meals rode in on
/// the part, so the sheet is the same ranking, past the handful.
///
/// The picker's rules hold inside it (clause 3): the tick is the only thing
/// that adds a meal, and a tap on the row opens that meal's detail.
Future<void> showPickerMoreSheet({
  required BuildContext context,
  required List<MealRef> meals,
  required Set<String> pickedIds,
  required ValueChanged<MealRef> onPick,
  required ValueChanged<MealRef> onOpen,
}) => showAdaptiveModal<void>(
  context: context,
  builder: (sheetContext) => PickerMoreSheet(
    meals: meals,
    pickedIds: pickedIds,
    onPick: onPick,
    onOpen: onOpen,
  ),
);

class PickerMoreSheet extends ConsumerStatefulWidget {
  const PickerMoreSheet({
    super.key,
    required this.meals,
    required this.pickedIds,
    required this.onPick,
    required this.onOpen,
  });

  /// The tail of the picker's search — already excluding the tiles.
  final List<MealRef> meals;

  /// Ids in the draft when the sheet opened.
  final Set<String> pickedIds;

  /// The tick: adds to the draft, exactly as the picker's tick does.
  final ValueChanged<MealRef> onPick;

  /// A tap on the row: the meal's detail screen.
  final ValueChanged<MealRef> onOpen;

  @override
  ConsumerState<PickerMoreSheet> createState() => _PickerMoreSheetState();
}

class _PickerMoreSheetState extends ConsumerState<PickerMoreSheet> {
  /// Ticked while the sheet is open. The host's `pickedIds` is a snapshot
  /// from the frame that raised it, so the sheet keeps its own tally rather
  /// than waiting on a rebuild that never reaches it.
  late final Set<String> _picked = {...widget.pickedIds};

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final photos = photosForList(widget.meals);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.getValue(ContentKeys.mpPickerMoreTitle),
              key: const ValueKey('meal_planning.picker_more_title'),
              style: AppTextStyles.sectionTitle.copyWith(color: textColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.meals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final meal = widget.meals[i];
                    final picked = _picked.contains(meal.id);
                    return MealCard(
                      key: ValueKey('meal_planning.picker_more_${meal.id}'),
                      meal: meal,
                      slot: photos[i],
                      // Clause 3: the row opens detail, it never adds.
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onOpen(meal);
                      },
                      trailing: MealAddButton(
                        key: ValueKey(
                          'meal_planning.picker_more_tick_${meal.id}',
                        ),
                        added: picked,
                        tooltip: content.getValue(
                          picked
                              ? ContentKeys.mpBrowseAdded
                              : ContentKeys.mpBrowseAdd,
                        ),
                        onTap: picked
                            ? null
                            : () {
                                setState(() => _picked.add(meal.id));
                                widget.onPick(meal);
                              },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
