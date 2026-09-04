import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// The `⋮` on a meal card or plan tile (plan Phase 6.2): Swap / Remove,
/// card-scoped, so neither lives two taps deeper in a sheet. Renders
/// nothing when the host passes no actions, so a card outside the plan
/// carries no menu. Kyle-styled popup, both themes; no new library
/// component (plan §4.2 — "extend `MealCard.trailing` / `PlanTile`").
class CardOverflowMenu extends ConsumerWidget {
  const CardOverflowMenu({
    super.key,
    this.onSwap,
    this.onRemove,
    this.menuKey,
  });

  final VoidCallback? onSwap;
  final VoidCallback? onRemove;

  /// Key for the trigger, so hosts can address one card's menu in tests.
  final Key? menuKey;

  bool get isEmpty => onSwap == null && onRemove == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEmpty) return const SizedBox.shrink();
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return PopupMenuButton<_OverflowAction>(
      key: menuKey,
      tooltip: content.getValue(ContentKeys.mpCardMore),
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
        _OverflowAction.swap => onSwap?.call(),
        _OverflowAction.remove => onRemove?.call(),
      },
      itemBuilder: (context) => [
        if (onSwap != null)
          PopupMenuItem(
            key: const ValueKey('meal_planning.card_overflow_swap'),
            value: _OverflowAction.swap,
            child: Text(
              content.getValue(ContentKeys.mpBtnSwap),
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
          ),
        if (onRemove != null)
          PopupMenuItem(
            key: const ValueKey('meal_planning.card_overflow_remove'),
            value: _OverflowAction.remove,
            child: Text(
              content.getValue(ContentKeys.mpBtnRemove),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.dragonfruitLight,
              ),
            ),
          ),
      ],
    );
  }
}

enum _OverflowAction { swap, remove }
