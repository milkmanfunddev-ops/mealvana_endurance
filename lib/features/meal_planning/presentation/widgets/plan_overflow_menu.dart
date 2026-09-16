import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import 'overflow_menu.dart';

/// The `⋮` beside the plan's summary row (Lee's 09-16 demo: there was no way
/// to get rid of a plan by hand). Plan-scoped, so it holds only what the
/// per-tile menu cannot: start a fresh plan, look at earlier plans, or delete
/// this one. The trigger and popup are [OverflowMenu], which the Shopping
/// tab's header shares.
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
    return OverflowMenu(
      key: const ValueKey('meal_planning.plan_overflow'),
      tooltip: content.getValue(ContentKeys.mpPlanMore),
      items: [
        if (onStartNew != null)
          OverflowMenuItem(
            key: const ValueKey('meal_planning.plan_new'),
            label: content.getValue(ContentKeys.mpPlanStartNew),
            onSelected: onStartNew!,
          ),
        if (onPrevious != null)
          OverflowMenuItem(
            key: const ValueKey('meal_planning.plan_previous'),
            label: content.getValue(ContentKeys.mpPlanPrevious),
            onSelected: onPrevious!,
          ),
        if (onDelete != null)
          OverflowMenuItem(
            key: const ValueKey('meal_planning.plan_delete'),
            label: content.getValue(ContentKeys.mpPlanDelete),
            destructive: true,
            onSelected: onDelete!,
          ),
      ],
    );
  }
}
