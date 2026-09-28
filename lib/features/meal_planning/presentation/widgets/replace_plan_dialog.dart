import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../application/meal_plan_controller.dart';
import '../../domain/meal_plan.dart';

/// "Replace this week's plan with this one?" — asked before Use this plan
/// again (Previous plans) and Use this plan instead (a replaced draft's
/// chat) confirm the copy at once (Lee 2026-09-28, ticket 162). Asked only
/// when the week has a confirmed plan to replace; with none, the copy
/// confirms without a question. Returns whether to go on.
///
/// The tab's plan is awaited, not peeked: a screen that never watched the
/// plan controller would otherwise read nothing and skip the question. A
/// read that fails falls back to whatever the controller holds.
Future<bool> confirmReplaceWeekPlan(
  BuildContext context,
  WidgetRef ref,
) async {
  MealPlan? current;
  try {
    current = await ref.read(mealPlanControllerProvider.future);
  } on Object {
    current = ref.read(mealPlanControllerProvider).value;
  }
  if (current == null || !current.isConfirmed) return true;
  if (!context.mounted) return false;
  final content = ref.read(contentServiceProvider);
  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('meal_planning.replace_plan_confirm'),
      backgroundColor: Theme.of(dialogContext).scaffoldBackgroundColor,
      title: Text(content.getValue(ContentKeys.mpPreviousPlanReplaceTitle)),
      content: Text(content.getValue(ContentKeys.mpPreviousPlanReplaceBody)),
      actions: [
        TextButton(
          key: const ValueKey('meal_planning.replace_plan_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            content.getValue(ContentKeys.mpPreviousPlanReplaceCancel),
          ),
        ),
        TextButton(
          key: const ValueKey('meal_planning.replace_plan_go'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            content.getValue(ContentKeys.mpPreviousPlanReplaceConfirm),
            style: const TextStyle(color: AppColors.electrolyteDark),
          ),
        ),
      ],
    ),
  );
  return replace == true;
}
