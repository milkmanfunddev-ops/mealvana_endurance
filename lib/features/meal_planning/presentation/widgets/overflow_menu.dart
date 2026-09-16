import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// One line in an [OverflowMenu]. A destructive line reads in the warning
/// colour, as Delete does on the plan and card menus.
class OverflowMenuItem {
  const OverflowMenuItem({
    required this.label,
    required this.onSelected,
    this.key,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onSelected;
  final Key? key;
  final bool destructive;
}

/// The `⋮` trigger and Kyle-styled popup that the Plan tab's summary row
/// and the Shopping tab's header share (Lee, 2026-09-16: the two tabs should
/// match). Holds no actions of its own: the host names the lines. Renders
/// nothing when there are none, so a host with nothing to offer draws no
/// trigger.
class OverflowMenu extends ConsumerWidget {
  const OverflowMenu({
    super.key,
    required this.items,
    required this.tooltip,
    this.iconColor,
  });

  final List<OverflowMenuItem> items;
  final String tooltip;

  /// The trigger's colour; defaults to secondary text.
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return PopupMenuButton<int>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: textColor.withValues(alpha: 0.12)),
      ),
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: iconColor ?? textColor.withValues(alpha: 0.6),
      ),
      onSelected: (i) => items[i].onSelected(),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            key: items[i].key,
            value: i,
            child: Text(
              items[i].label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: items[i].destructive
                    ? AppColors.dragonfruitLight
                    : textColor,
              ),
            ),
          ),
      ],
    );
  }
}
