import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_plan_controller.dart';
import '../../application/meal_icon_classifier.dart';
import '../widgets/meal_icon_glyphs.dart';
import 'meals_tab.dart';
import 'plan_tab.dart';
import 'shopping_tab.dart';

/// The three segments of the Food screen (05 §4).
enum FoodTab { plan, meals, shopping }

/// `/food` — header "Food" + segmented Plan · Meals · Shopping. Detail
/// routes (`/food/meals/:id`, …) are separate routes and hide this header.
/// The tab state is local; deep links pass `?tab=`.
class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key, this.initialTab = FoodTab.plan});

  final FoodTab initialTab;

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  late FoodTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // Repository-level on-demand sync the first time the tab shows
    // (05 §5 / CLAUDE.md: never startup-wide sync-all).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(mealPlanControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;

    return Scaffold(
      key: const ValueKey('meal_planning.food_screen'),
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  MealIconTile(
                    icon: MealIcon.bowl,
                    size: 34,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    content.getValue(ContentKeys.mpFoodTitle),
                    key: const ValueKey('meal_planning.food_title'),
                    style: AppTextStyles.pageTitle.copyWith(color: textColor),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _TabSelector(
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: FoodTab.values.indexOf(_tab),
                children: const [
                  PlanTab(),
                  MealsTab(),
                  ShoppingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSelector extends ConsumerWidget {
  const _TabSelector({required this.selected, required this.onChanged});

  final FoodTab selected;
  final ValueChanged<FoodTab> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? AppColors.cream : AppColors.blackberry;
    final inactive = active.withValues(alpha: 0.45);

    Widget segment(FoodTab tab, String label) => Expanded(
      child: GestureDetector(
        key: ValueKey('meal_planning.tab_${tab.name}'),
        onTap: () => onChanged(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected == tab ? AppColors.orange : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.tabSelector.copyWith(
              color: selected == tab ? active : inactive,
              fontWeight: selected == tab ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        segment(FoodTab.plan, content.getValue(ContentKeys.mpTabPlan)),
        segment(FoodTab.meals, content.getValue(ContentKeys.mpTabMeals)),
        segment(
          FoodTab.shopping,
          content.getValue(ContentKeys.mpTabShopping),
        ),
      ],
    );
  }
}
