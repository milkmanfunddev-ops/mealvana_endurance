import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/widgets/kyle_design/navigation/kyle_tab_pill.dart';
import '../../../../shared/widgets/lazy_indexed_stack.dart';
import '../../application/meal_plan_controller.dart';
import '../../domain/vana_situation.dart';
import '../widgets/vana_situation_scope.dart';
import '../widgets/shopping_share_button.dart';
import 'meals_tab.dart';
import 'plan_tab.dart';
import 'shopping_tab.dart';

/// The three segments of the Food screen (05 §4).
enum FoodTab { plan, meals, shopping }

/// Where the Food tab opens on [tab]: inside the tab shell, never a bare Food
/// page with no tab bar and no way home.
String foodTabLocation(FoodTab tab) => '/main?tab=food&food=${tab.name}';

/// A fresh `extra` for a go to [foodTabLocation]: going to the same location
/// again (the athlete has since tapped another segment) still switches.
Object foodTabRequest() => DateTime.now().microsecondsSinceEpoch;

/// Goes to the Food tab on [tab] (see [foodTabLocation]).
void goToFoodTab(BuildContext context, FoodTab tab) =>
    context.go(foodTabLocation(tab), extra: foodTabRequest());

/// The Food tab of the tab shell — header "Food" + segmented Plan · Meals ·
/// Shopping. Detail routes (`/food/meals/:id`, …) are separate routes and hide
/// this header. The segment is local; links pass `/main?tab=food&food=`.
class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key, this.initialTab = FoodTab.plan, this.request});

  final FoodTab initialTab;

  /// Changes on every navigation that asks for [initialTab] ([foodTabRequest]).
  final Object? request;

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

  // `/main?tab=food&food=shopping` reuses a Food tab that is already built;
  // a newly requested segment must still win over the one it first opened
  // on (mp-596: "Open shopping list" landed on Plan; 16-002: so did Confirm).
  @override
  void didUpdateWidget(FoodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab ||
        widget.request != oldWidget.request) {
      _tab = widget.initialTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    // What Vana is told this screen has in view: the Plan tab, today, and the
    // week's plan. Ids only — the server resolves them.
    final plan = ref.watch(mealPlanControllerProvider).value;

    return VanaSituationScope(
      situation: VanaSituation.screen(
        VanaScreen.planTab,
        entityId: plan?.id,
        date: DateTime.now(),
      ),
      child: Scaffold(
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
                // A segment is built the first time it is selected and kept
                // alive after, so opening Food does not fire all three
                // segments' server calls at once (mp-432 / mp-468).
                child: LazyIndexedStack(
                  index: FoodTab.values.indexOf(_tab),
                  itemCount: FoodTab.values.length,
                  itemBuilder: (_, i) => switch (FoodTab.values[i]) {
                    // "Add meal" switches segment here; it never pushes a
                    // second Food page over this one.
                    FoodTab.plan => PlanTab(
                      onAddMeal: () => setState(() => _tab = FoodTab.meals),
                    ),
                    FoodTab.meals => const MealsTab(),
                    FoodTab.shopping => const ShoppingTab(),
                  },
                ),
              ),
            ],
          ),
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
