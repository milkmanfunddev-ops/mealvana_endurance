import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// The `⋮` beside the plan's summary row (Lee's 09-16 demo: there was no way
/// to get rid of a plan by hand). Plan-scoped, so it holds only what the
/// per-tile menu cannot: start a fresh plan, look at earlier plans, or delete
/// this one. Same Kyle
/// popup styling as `CardOverflowMenu`; the two stay siblings rather than one
/// widget with two action sets, because a plan menu and a tile menu share
/// nothing but the trigger.
class PlanOverflowMenu extends ConsumerWidget {
  const PlanOverflowMenu({
    super.key,
    this.onStartNew,
    this.onPrevious,
    this.onDelete,
  });

  final VoidCallback? onStartNew;

  /// Opens the earlier-plans sheet.
  final VoidCallback? onPrevious;
  final VoidCallback? onDelete;

  bool get isEmpty =>
      onStartNew == null && onPrevious == null && onDelete == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEmpty) return const SizedBox.shrink();
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return PopupMenuButton<_PlanAction>(
      key: const ValueKey('meal_planning.plan_overflow'),
      tooltip: content.getValue(ContentKeys.mpPlanMore),
      padding: EdgeInsets.zero,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: textColor.withValues(alpha: 0.12)),
      ),
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: textColor.withValues(alpha: 0.6),
      ),
      onSelected: (action) => switch (action) {
        _PlanAction.startNew => onStartNew?.call(),
        _PlanAction.previous => onPrevious?.call(),
        _PlanAction.delete => onDelete?.call(),
      },
      itemBuilder: (context) => [
        if (onStartNew != null)
          PopupMenuItem(
            key: const ValueKey('meal_planning.plan_new'),
            value: _PlanAction.startNew,
            child: Text(
              content.getValue(ContentKeys.mpPlanStartNew),
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
          ),
        if (onPrevious != null)
          PopupMenuItem(
            key: const ValueKey('meal_planning.plan_previous'),
            value: _PlanAction.previous,
            child: Text(
              content.getValue(ContentKeys.mpPlanPrevious),
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            key: const ValueKey('meal_planning.plan_delete'),
            value: _PlanAction.delete,
            child: Text(
              content.getValue(ContentKeys.mpPlanDelete),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.dragonfruitLight,
              ),
            ),
          ),
      ],
    );
  }
}

enum _PlanAction { startNew, previous, delete }
