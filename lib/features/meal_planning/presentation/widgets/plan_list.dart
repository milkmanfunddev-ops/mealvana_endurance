import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/widgets/swipe_action_background.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../domain/plan_meal.dart';
import 'plan_tile.dart';

/// The plan's meal rows. Swipe **right** → Remove (the caller shows the
/// Undo snackbar that re-picks the meal); swipe **left** → Swap (routes to
/// `/food/swap/:id`); tap → the meal's detail page.
///
/// Rows always snap back: the plan data is owned by the Drift watch, so the
/// action fires in [Dismissible.confirmDismiss] and the dismiss itself is
/// vetoed.
class PlanList extends StatelessWidget {
  const PlanList({
    super.key,
    required this.meals,
    required this.onTapMeal,
    required this.onSwap,
    required this.onRemove,
    this.showMacros = false,
  });

  final List<PlanMeal> meals;
  final ValueChanged<PlanMeal> onTapMeal;

  /// Opens `/food/swap/:planMealId`.
  final ValueChanged<PlanMeal> onSwap;

  /// Removes the meal locally-first; the caller shows the Undo snackbar.
  final ValueChanged<PlanMeal> onRemove;
  final bool showMacros;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.sm);

    return Column(
      children: [
        for (final (i, meal) in meals.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          Dismissible(
            key: ValueKey('meal_planning.plan_tile_${meal.id}'),
            direction: DismissDirection.horizontal,
            dismissThresholds: const {
              DismissDirection.startToEnd: 0.35,
              DismissDirection.endToStart: 0.35,
            },
            background: SwipeActionBackground(
              color: AppColors.dragonfruit,
              alignment: Alignment.centerLeft,
              borderRadius: radius,
              icon: const FaIcon(
                FontAwesomeIcons.trashCan,
                color: Colors.white,
                size: 22,
              ),
            ),
            secondaryBackground: SwipeActionBackground(
              color: AppColors.electrolyteDark,
              alignment: Alignment.centerRight,
              borderRadius: radius,
              icon: const FaIcon(
                FontAwesomeIcons.rightLeft,
                color: Colors.white,
                size: 22,
              ),
            ),
            confirmDismiss: (direction) {
              switch (direction) {
                case DismissDirection.startToEnd:
                  onRemove(meal);
                case DismissDirection.endToStart:
                  onSwap(meal);
                default:
                  break;
              }
              // Never actually dismiss — the watch stream re-renders the list.
              return Future.value(false);
            },
            onDismissed: (_) {},
            child: PlanTile(
              meal: meal,
              onTap: () => onTapMeal(meal),
              onSwap: () => onSwap(meal),
              onRemove: () => onRemove(meal),
              showMacros: showMacros,
            ),
          ),
        ],
      ],
    );
  }
}
