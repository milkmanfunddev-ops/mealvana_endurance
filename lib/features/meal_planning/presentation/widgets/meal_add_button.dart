import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// The small round Add affordance on a browse card (Xuan's v5 "Add
/// ribbon"): an outlined `+` that fills electrolyte with a tick once the
/// meal has landed in the draft. [onTap] null renders it inert — the ticked
/// state is not a toggle; removal happens in the plan bar. Inert still
/// absorbs the tap: with no handler the touch fell through to the card
/// body, which opened the detail, whose Add to plan added the meal again
/// (testing-wave 18-001).
///
/// A screen reader reads [tooltip] as the button's name in both states, so
/// a ticked Add stays an element named "Added" (testing-wave 18-005).
///
/// [unavailable] is the third state: the meal can't go in a plan (its
/// nutrition numbers are missing, mp-678). The plus is drawn faint and the
/// button reads as disabled; [onTap] still runs so the screen can say why.
class MealAddButton extends StatelessWidget {
  const MealAddButton({
    super.key,
    required this.added,
    required this.tooltip,
    this.onTap,
    this.unavailable = false,
    this.size = 28,
  });

  final bool added;
  final String tooltip;
  final VoidCallback? onTap;
  final bool unavailable;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final faint = unavailable && !added;

    return Semantics(
      button: true,
      enabled: faint ? false : null,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          color: added ? AppColors.electrolyte : Colors.transparent,
          shape: CircleBorder(
            side: added
                ? BorderSide.none
                : BorderSide(
                    color: textColor.withValues(alpha: faint ? 0.15 : 0.35),
                  ),
          ),
          child: InkWell(
            onTap: onTap ?? () {},
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                added ? Icons.check : Icons.add,
                size: size * 0.6,
                color: added
                    ? AppColors.blackberry
                    : textColor.withValues(alpha: faint ? 0.3 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
