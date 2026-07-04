import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/widgets/food_search/unified_food_search_results.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../recipes/domain/recipe.dart';
import '../../domain/common_ingredients.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/saved_meal.dart';
import '../providers/meal_log_providers.dart';

/// Sectioned cross-source search results shown below the unified search bar
/// (item 25) whenever the query is non-empty.
///
/// Two layers:
/// - A horizontal "quick match" strip covering favorites, recents, recipes,
///   and the curated common-ingredients library (all filtered client-side by
///   [query]) — tapping a card adds straight to the build-a-meal draft.
/// - The shared [UnifiedFoodSearchResults] (composed, not modified) for
///   foods/catalog/Open Food Facts — the same widget Swap Food and Food
///   Preferences use, keyed to this sheet's own [FoodSearchController]
///   instance via [controllerKey].
class UnifiedMealSearchResults extends ConsumerWidget {
  const UnifiedMealSearchResults({
    super.key,
    required this.query,
    required this.recipes,
    required this.controllerKey,
    required this.scrollController,
    required this.onAddRecipe,
    required this.onAddFavorite,
    required this.onAddRecent,
    required this.onAddIngredient,
    required this.onFoodTap,
    required this.onCatalogTap,
    required this.onOpenFoodFactsResultTap,
    required this.onSearchOpenFoodFacts,
  });

  final String query;
  final List<Recipe> recipes;
  final String controllerKey;
  final ScrollController scrollController;

  final ValueChanged<Recipe> onAddRecipe;
  final ValueChanged<SavedMeal> onAddFavorite;
  final ValueChanged<MealLog> onAddRecent;
  final ValueChanged<MealComponent> onAddIngredient;
  final ValueChanged<Food> onFoodTap;
  final ValueChanged<CatalogSearchResult> onCatalogTap;
  final void Function(dynamic) onOpenFoodFactsResultTap;
  final VoidCallback onSearchOpenFoodFacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim().toLowerCase();
    final favoritesAsync = ref.watch(savedMealsProvider);
    final recentAsync = ref.watch(recentMealsProvider);

    final matchingFavorites = (favoritesAsync.asData?.value ?? const <SavedMeal>[])
        .where((m) => m.name.toLowerCase().contains(q))
        .take(8)
        .toList();
    final matchingRecents = (recentAsync.asData?.value ?? const <MealLog>[])
        .where((l) => l.name.toLowerCase().contains(q))
        .take(8)
        .toList();
    final matchingRecipes =
        recipes.where((r) => r.name.toLowerCase().contains(q)).take(8).toList();
    final matchingIngredients = kCommonIngredients
        .where((i) => i.name.toLowerCase().contains(q))
        .take(8)
        .toList();

    final hasQuickMatches = matchingFavorites.isNotEmpty ||
        matchingRecents.isNotEmpty ||
        matchingRecipes.isNotEmpty ||
        matchingIngredients.isNotEmpty;

    return Column(
      children: [
        if (hasQuickMatches)
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              children: [
                ...matchingFavorites.map(
                  (m) => _QuickMatchCard(
                    icon: Icons.star,
                    label: m.name,
                    sublabel: 'Favorite',
                    onTap: () => onAddFavorite(m),
                  ),
                ),
                ...matchingRecents.map(
                  (l) => _QuickMatchCard(
                    icon: Icons.history,
                    label: l.name,
                    sublabel: 'Recent',
                    onTap: () => onAddRecent(l),
                  ),
                ),
                ...matchingRecipes.map(
                  (r) => _QuickMatchCard(
                    icon: Icons.menu_book_outlined,
                    label: r.name,
                    sublabel: 'Recipe',
                    onTap: () => onAddRecipe(r),
                  ),
                ),
                ...matchingIngredients.map(
                  (i) => _QuickMatchCard(
                    icon: Icons.eco_outlined,
                    label: i.name,
                    sublabel: 'Ingredient',
                    onTap: () => onAddIngredient(i),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: UnifiedFoodSearchResults(
            controllerKey: controllerKey,
            scrollController: scrollController,
            // Declutter the meal-log search surface — the quick-match strip
            // above and this list's grouping already make the source of each
            // result obvious without a "Catalog & Suggestions" label + count
            // badge (item 4). Swap Food / Food Preferences / Carb Loading are
            // unaffected (they don't pass this).
            showSectionHeaders: false,
            userFoodItemBuilder: (food) => _FoodResultTile(
              food: food,
              onTap: () => onFoodTap(food),
            ),
            templateFoodItemBuilder: (food) => _FoodResultTile(
              food: food,
              onTap: () => onFoodTap(food),
            ),
            catalogItemBuilder: (result) => _CatalogResultTile(
              result: result,
              onTap: () => onCatalogTap(result),
            ),
            onSearchOpenFoodFacts: onSearchOpenFoodFacts,
            onOpenFoodFactsResultTap: onOpenFoodFactsResultTap,
            emptyQueryContent: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// Compact horizontal-strip card for a cross-source "quick match".
class _QuickMatchCard extends StatelessWidget {
  const _QuickMatchCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 120,
      height: 104,
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact food/catalog result row used within the unified search results
/// (kept local so this file doesn't reach into nutrition_plan's swap-food
/// card widgets, which are styled for a different surface).
class _FoodResultTile extends StatelessWidget {
  const _FoodResultTile({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = food.displayName ?? food.name;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${food.caloriesPerServing?.round() ?? '—'} kcal per serving',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.add_circle_outline, size: 20),
        onTap: onTap,
      ),
    );
  }
}

class _CatalogResultTile extends StatelessWidget {
  const _CatalogResultTile({required this.result, required this.onTap});

  final CatalogSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        title: Text(
          result.variantTitle ?? result.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${result.caloriesPerServing?.round() ?? '—'} kcal per serving',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.add_circle_outline, size: 20),
        onTap: onTap,
      ),
    );
  }
}
