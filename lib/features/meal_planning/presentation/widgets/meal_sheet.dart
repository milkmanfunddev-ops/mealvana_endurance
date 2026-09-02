import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../../domain/plan_meal.dart';
import 'plan_tile.dart';
import 'stepper.dart';
import 'swap_picker.dart';

/// Opens the chat-screen tile sheet: servings stepper · Swap (expands an
/// inline [SwapPicker]) · Remove (05 §4). Controller calls stay with the
/// caller — the sheet reports intents.
Future<void> showMealSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PlanMeal meal,
  required ValueChanged<int> onServings,
  required void Function(PlanMeal meal, MealRef replacement) onSwap,
  required VoidCallback onRemove,
}) {
  return showAdaptiveModal<void>(
    context: context,
    builder: (sheetContext) => MealSheet(
      meal: meal,
      onServings: onServings,
      onSwap: onSwap,
      onRemove: onRemove,
    ),
  );
}

class MealSheet extends ConsumerStatefulWidget {
  const MealSheet({
    super.key,
    required this.meal,
    required this.onServings,
    required this.onSwap,
    required this.onRemove,
  });

  final PlanMeal meal;
  final ValueChanged<int> onServings;

  /// Runs the remote-ack `swap_meal` with the picked replacement.
  final void Function(PlanMeal meal, MealRef replacement) onSwap;
  final VoidCallback onRemove;

  @override
  ConsumerState<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<MealSheet> {
  bool _swapping = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlanTile(meal: widget.meal, onTap: () {}),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  '${widget.meal.servings} ${content.getValue(ContentKeys.mpServingsLabel)}',
                  key: const ValueKey('meal_planning.meal_sheet.servings'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ServingsStepper(
                  value: widget.meal.servings,
                  onChanged: widget.onServings,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  key: const ValueKey('meal_planning.meal_sheet.swap'),
                  onPressed: () => setState(() => _swapping = !_swapping),
                  child: Text(
                    content.getValue(ContentKeys.mpBtnSwap),
                    style: AppTextStyles.bodyMedium.copyWith(color: secondary),
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('meal_planning.meal_sheet.remove'),
                  onPressed: widget.onRemove,
                  child: Text(
                    content.getValue(ContentKeys.mpBtnRemove),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.dragonfruit,
                    ),
                  ),
                ),
              ],
            ),
            if (_swapping)
              SwapPicker(
                mealType: widget.meal.mealType,
                onPick: (replacement) {
                  Navigator.of(context).pop();
                  widget.onSwap(widget.meal, replacement);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
