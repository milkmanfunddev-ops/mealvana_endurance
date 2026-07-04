import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/barcode_scanning/application/catalog_search_service.dart';
import '../../controllers/food_search_controller.dart';
import '../../services/food_management/nutrition_product_search_service.dart';
import '../buttons/search_openfoodfacts_button.dart';
import '../../../features/nutrition_plan/presentation/widgets/swap_food/food_search_results_widget.dart';

/// Unified food search results widget used by both Swap Food and Food Preferences screens.
///
/// Renders a prioritized list: user foods first, then template + catalog results.
/// Uses builder callbacks so each screen provides its own item rendering.
class UnifiedFoodSearchResults extends ConsumerWidget {
  const UnifiedFoodSearchResults({
    super.key,
    required this.controllerKey,
    required this.userFoodItemBuilder,
    required this.templateFoodItemBuilder,
    required this.catalogItemBuilder,
    required this.onSearchOpenFoodFacts,
    required this.onOpenFoodFactsResultTap,
    required this.emptyQueryContent,
    this.isMyFoodsExpanded = true,
    this.onMyFoodsSectionToggle,
    this.scrollController,
    this.showOpenFoodFactsButton = true,
    this.onNutritionProductResultTap,
    this.showSectionHeaders = true,
  });

  /// Controller key to read the right FoodSearchController instance.
  final String controllerKey;

  /// Builder for user food items.
  final Widget Function(Food food) userFoodItemBuilder;

  /// Builder for template/system food items.
  final Widget Function(Food food) templateFoodItemBuilder;

  /// Builder for catalog search result items.
  final Widget Function(CatalogSearchResult result) catalogItemBuilder;

  /// Callback to trigger Open Food Facts search.
  final VoidCallback onSearchOpenFoodFacts;

  /// Callback when an OFF result is tapped.
  final void Function(dynamic) onOpenFoodFactsResultTap;

  /// Content shown when search query is empty.
  final Widget emptyQueryContent;

  /// Whether the My Foods section is expanded (controlled by parent).
  final bool isMyFoodsExpanded;

  /// Toggle callback for My Foods section.
  final VoidCallback? onMyFoodsSectionToggle;

  /// Optional external scroll controller for the results list — lets callers
  /// (e.g. a [DraggableScrollableSheet]) drive the sheet's drag/resize
  /// behavior from this list when it's the active scrollable.
  final ScrollController? scrollController;

  /// Whether to render the manual "Search Open Food Facts" button. Defaults
  /// to `true` (legacy behavior, unchanged for existing callers). Surfaces
  /// that automatically supplement search with `search-nutrition-products`
  /// (USDA + cached OpenFoodFacts) — see [onNutritionProductResultTap] — set
  /// this to `false` since the manual trigger is redundant (ITEM 7).
  final bool showOpenFoodFactsButton;

  /// Callback when an auto-fetched `search-nutrition-products` result (USDA
  /// + cached OpenFoodFacts) is tapped. Optional: when null, the "More
  /// Results" section is hidden entirely, so callers that don't wire this up
  /// see no behavior change even though the controller always populates the
  /// underlying data (ITEM 18 — shared cascade stays solid for every
  /// composing surface; only opted-in surfaces render it).
  final void Function(NutritionProductSearchResult)? onNutritionProductResultTap;

  /// Whether to render section headers ("My Foods", "Catalog & Suggestions",
  /// "More Results") above their respective item groups. Defaults to `true`
  /// (unchanged behavior for Swap Food / Food Preferences / Carb Loading).
  /// The meal-log search surface sets this to `false` to declutter — the
  /// items themselves still render, grouped and spaced, just without the
  /// label + count-badge row above them.
  final bool showSectionHeaders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(foodSearchControllerProvider(controllerKey));

    // When search query is empty, show default content
    if (searchState.searchQuery.isEmpty) {
      return emptyQueryContent;
    }

    // Show searching indicator for Open Food Facts full-screen search
    if (searchState.isSearchingOpenFoodFacts &&
        searchState.openFoodFactsResults.isEmpty) {
      return _buildSearchingIndicator(context);
    }

    // Show OFF results if they exist (takes priority over local results)
    if (searchState.openFoodFactsResults.isNotEmpty) {
      return OpenFoodFactsResultsWidget(
        results: searchState.openFoodFactsResults,
        onResultTap: onOpenFoodFactsResultTap,
      );
    }

    // Only factor nutrition-product state into the empty check for surfaces
    // that actually render that section — otherwise a caller that doesn't
    // pass [onNutritionProductResultTap] would suppress its empty state
    // while data it never shows streams in behind the scenes.
    final showsNutritionProducts = onNutritionProductResultTap != null;
    final hasNoResults =
        searchState.userFoodResults.isEmpty &&
        searchState.templateFoodResults.isEmpty &&
        searchState.catalogResults.isEmpty &&
        !searchState.isSearchingCatalog &&
        (!showsNutritionProducts ||
            (searchState.nutritionProductResults.isEmpty &&
                !searchState.isSearchingNutritionProducts));

    if (hasNoResults) {
      return _buildEmptyState(context, searchState);
    }

    return _buildSearchResults(context, ref, searchState);
  }

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    FoodSearchState searchState,
  ) {
    // Determine catalog items to show (limit to 20 unless expanded)
    final catalogToShow = searchState.isCatalogExpanded
        ? searchState.catalogResults
        : searchState.catalogResults.take(20).toList();
    final hasMoreCatalog =
        !searchState.isCatalogExpanded &&
        searchState.catalogResults.length > 20;

    return ListView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        // My Foods section
        if (searchState.userFoodResults.isNotEmpty) ...[
          if (showSectionHeaders)
            _MyFoodsSectionHeader(
              userFoodCount: searchState.userFoodResults.length,
              isExpanded: isMyFoodsExpanded,
              onToggle: onMyFoodsSectionToggle ?? () {},
            ),
          if (isMyFoodsExpanded)
            ...searchState.userFoodResults.map(
              (food) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: userFoodItemBuilder(food),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Catalog & Suggestions section
        if (searchState.templateFoodResults.isNotEmpty ||
            catalogToShow.isNotEmpty ||
            searchState.isSearchingCatalog) ...[
          if (showSectionHeaders)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    'Catalog & Suggestions',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${searchState.templateFoodResults.length + searchState.catalogResults.length}',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Template food items
          ...searchState.templateFoodResults.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: templateFoodItemBuilder(food),
            ),
          ),

          // Catalog items (limited to 20 unless expanded)
          ...catalogToShow.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: catalogItemBuilder(result),
            ),
          ),

          // Loading spinner for catalog search
          if (searchState.isSearchingCatalog &&
              searchState.catalogResults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),

          // "Show more" button
          if (hasMoreCatalog)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    ref
                        .read(
                          foodSearchControllerProvider(controllerKey).notifier,
                        )
                        .expandCatalogResults();
                  },
                  child: Text(
                    'Show ${searchState.catalogResults.length - 20} more results',
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
            ),
        ],

        // "More Results" — auto-fetched USDA + cached-OpenFoodFacts results
        // from search-nutrition-products (ITEM 7). Only rendered when the
        // caller wires up onNutritionProductResultTap; otherwise this data
        // streams into state unused, matching legacy behavior exactly.
        if (onNutritionProductResultTap != null &&
            (searchState.nutritionProductResults.isNotEmpty ||
                searchState.isSearchingNutritionProducts)) ...[
          if (showSectionHeaders)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                'More Results',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ...searchState.nutritionProductResults.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _NutritionProductCard(
                result: result,
                onTap: () => onNutritionProductResultTap!(result),
              ),
            ),
          ),
          if (searchState.isSearchingNutritionProducts &&
              searchState.nutritionProductResults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],

        // Search Open Food Facts button - visible when query is non-empty,
        // unless the surface auto-supplements via search-nutrition-products.
        if (showOpenFoodFactsButton)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.md,
            ),
            child: SearchOpenFoodFactsButton(onPressed: onSearchOpenFoodFacts),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, FoodSearchState searchState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: AppIconSizes.xl,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No foods found for "${searchState.searchQuery}"',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // OFF button still visible in empty state (unless auto-supplemented)
            if (showOpenFoodFactsButton)
              SearchOpenFoodFactsButton(onPressed: onSearchOpenFoodFacts),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingIndicator(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Searching food database...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// My Foods section header with expand/collapse toggle
class _MyFoodsSectionHeader extends StatelessWidget {
  final int userFoodCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _MyFoodsSectionHeader({
    required this.userFoodCount,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: AppRadius.smRadius,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.solidHeart,
              size: AppIconSizes.sm,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'My Foods',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.dragonfruit.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$userFoodCount',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.dragonfruit,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded
                  ? FontAwesomeIcons.chevronUp.data
                  : FontAwesomeIcons.chevronDown.data,
              size: AppIconSizes.sm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for a "More Results" item — an auto-fetched `search-nutrition-products`
/// hit (USDA FoodData Central or a cached Open Food Facts product). Mirrors
/// the visual style of the manual OpenFoodFacts result card so the two feel
/// like one continuous experience even though this one appears automatically.
class _NutritionProductCard extends StatelessWidget {
  const _NutritionProductCard({required this.result, required this.onTap});

  final NutritionProductSearchResult result;
  final VoidCallback onTap;

  String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  String? get _macroLabel {
    final carbs = result.carbsPerServing ?? result.carbsPer100g;
    if (carbs == null) return null;
    final unit = result.carbsPerServing != null ? 'g carbs' : 'g carbs/100g';
    return '${carbs.toInt()}$unit';
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: AppIconSizes.foodIcon,
                height: AppIconSizes.foodIcon,
                decoration: BoxDecoration(
                  color: AppColors.electrolyte.withValues(alpha: 0.2),
                  borderRadius: AppRadius.smRadius,
                ),
                child: result.imageUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: AppRadius.smRadius,
                        child: Image.network(
                          result.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => FaIcon(
                            FontAwesomeIcons.utensils,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: AppIconSizes.controlIcon,
                          ),
                        ),
                      )
                    : FaIcon(
                        FontAwesomeIcons.utensils,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: AppIconSizes.controlIcon,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalize(result.displayName),
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_macroLabel != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _macroLabel!,
                        style: AppTextStyles.smallLabel.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: AppIconSizes.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
