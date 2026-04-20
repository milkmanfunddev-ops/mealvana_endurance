import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/barcode_scanning/application/catalog_search_service.dart';
import '../../controllers/food_search_controller.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState =
        ref.watch(foodSearchControllerProvider(controllerKey));

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

    final hasNoResults = searchState.userFoodResults.isEmpty &&
        searchState.templateFoodResults.isEmpty &&
        searchState.catalogResults.isEmpty &&
        !searchState.isSearchingCatalog;

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
    final hasMoreCatalog = !searchState.isCatalogExpanded &&
        searchState.catalogResults.length > 20;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        // My Foods section
        if (searchState.userFoodResults.isNotEmpty) ...[
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
                        .read(foodSearchControllerProvider(controllerKey)
                            .notifier)
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

        // Search Open Food Facts button - ALWAYS visible when query is non-empty
        Padding(
          padding:
              const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
          child: SearchOpenFoodFactsButton(
            onPressed: onSearchOpenFoodFacts,
          ),
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
            Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: AppIconSizes.xl,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.3),
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
            // OFF button still visible in empty state
            SearchOpenFoodFactsButton(
              onPressed: onSearchOpenFoodFacts,
            ),
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
            Icon(
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
                  ? FontAwesomeIcons.chevronUp
                  : FontAwesomeIcons.chevronDown,
              size: AppIconSizes.sm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
