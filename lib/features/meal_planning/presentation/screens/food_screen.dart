import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/widgets/kyle_design/navigation/kyle_tab_pill.dart';
import '../../application/meal_plan_controller.dart';
import '../widgets/shopping_share_button.dart';
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
            // Centred page title. The settings gear is drawn by TabsScreen
            // over every tab (right edge, 4pt inset); on the Shopping tab the
            // share button slots in beside it at the same height.
            SizedBox(
              height: 48,
              width: double.infinity,
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        content.getValue(ContentKeys.mpFoodTitle),
                        key: const ValueKey('meal_planning.food_title'),
                        style: AppTextStyles.pageTitle.copyWith(
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  if (_tab == FoodTab.shopping)
                    const Positioned(
                      top: 0,
                      right: 52,
                      child: ShoppingShareButton(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
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

    return KyleTabPill(
      labels: [
        content.getValue(ContentKeys.mpTabPlan),
        content.getValue(ContentKeys.mpTabMeals),
        content.getValue(ContentKeys.mpTabShopping),
      ],
      itemKeys: const [
        ValueKey('meal_planning.tab_plan'),
        ValueKey('meal_planning.tab_meals'),
        ValueKey('meal_planning.tab_shopping'),
      ],
      selectedIndex: FoodTab.values.indexOf(selected),
      onChanged: (i) => onChanged(FoodTab.values[i]),
    );
  }
}
