import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/plan_meal.dart';
import 'plan_tile.dart';
import 'stepper.dart';

/// The plan tile sheet (tap a Plan tile): servings stepper · Swap · Remove
/// (05 §4). Controller calls stay with the caller — this widget only
/// reports intents.
Future<void> showTileSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PlanMeal meal,
  required ValueChanged<int> onServings,
  required VoidCallback onSwap,
  required VoidCallback onRemove,
}) {
  final content = ref.read(contentServiceProvider);
  return showAdaptiveModal<void>(
    context: context,
    builder: (sheetContext) {
      var servings = meal.servings;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          final textColor = isDark
              ? AppColors.cream
              : AppColors.blackberry;
          final secondary = textColor.withValues(alpha: 0.65);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlanTile(meal: meal, onTap: () => Navigator.of(sheetContext).pop()),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        '$servings',
                        key: const ValueKey('meal_planning.tile_sheet.servings'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        content.getValue(ContentKeys.mpServingsLabel),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: secondary,
                        ),
                      ),
                      const Spacer(),
                      ServingsStepper(
                        value: servings,
                        onChanged: (next) {
                          setSheetState(() => servings = next);
                          onServings(next);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SheetAction(
                    label: content.getValue(ContentKeys.mpBtnSwap),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onSwap();
                    },
                  ),
                  _SheetAction(
                    label: content.getValue(ContentKeys.mpBtnRemove),
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onRemove();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? AppColors.dragonfruit
        : (isDark ? AppColors.cream : AppColors.blackberry);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: color),
        ),
        onTap: onTap,
      ),
    );
  }
}
