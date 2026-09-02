import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/utils/adaptive_modal.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import 'meal_card.dart';
import 'stepper.dart';

/// Servings-only sheet for swapping a meal into the plan (meal detail with
/// `?swap=`, 05 §4). Reports the chosen serving count; the caller runs the
/// remote-ack `swap_meal` + `set_servings`.
Future<int?> showServingsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required MealRef meal,
  int initial = 1,
}) {
  final content = ref.read(contentServiceProvider);
  return showAdaptiveModal<int>(
    context: context,
    builder: (sheetContext) {
      var servings = initial;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          final textColor = isDark
              ? AppColors.cream
              : AppColors.blackberry;
          final accent = isDark
              ? AppColors.electrolyte
              : AppColors.electrolyteDark;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MealCard(meal: meal, onTap: () {}),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        '$servings ${content.getValue(ContentKeys.mpServingsLabel)}',
                        key: const ValueKey(
                          'meal_planning.servings_sheet.value',
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ServingsStepper(
                        value: servings,
                        onChanged: (next) =>
                            setSheetState(() => servings = next),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      key: const ValueKey('meal_planning.servings_sheet.done'),
                      onPressed: () => Navigator.of(sheetContext).pop(servings),
                      child: Text(
                        content.getValue(ContentKeys.mpBtnSwapIn),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
