import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food.dart';
import 'food_card_widget.dart';
import 'catalog_section_widget.dart';
import '../../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../../../shared/widgets/buttons/search_openfoodfacts_button.dart';

/// @deprecated Use [UnifiedFoodSearchResults] instead.
/// Kept only because [OpenFoodFactsResultsWidget] below is still in use.
@Deprecated('Use UnifiedFoodSearchResults instead')
class FoodSearchResultsWidget extends StatelessWidget {
  final List<Food> searchResults;
  final List<Food> userFoods;
  final List<CatalogSearchResult> catalogResults;
  final List<dynamic> openFoodFactsResults;
  final bool isSearchingCatalog;
  final bool isMyFoodsExpanded;
  final String searchQuery;
  final void Function(Food) onFoodTap;
  final void Function(Food)? onFoodLongPress;
  final void Function(Food)? onFoodEdit;
  final void Function(CatalogSearchResult) onCatalogResultTap;
  final void Function(dynamic) onOpenFoodFactsResultTap;
  final VoidCallback onMyFoodsSectionToggle;
  final bool Function(Food) isUserFood;
  final VoidCallback? onSearchOpenFoodFacts;
  final bool showOpenFoodFactsButton;

  const FoodSearchResultsWidget({
    super.key,
    required this.searchResults,
    required this.userFoods,
    required this.catalogResults,
    required this.openFoodFactsResults,
    required this.isSearchingCatalog,
    required this.isMyFoodsExpanded,
    required this.searchQuery,
    required this.onFoodTap,
    this.onFoodLongPress,
    this.onFoodEdit,
    required this.onCatalogResultTap,
    required this.onOpenFoodFactsResultTap,
    required this.onMyFoodsSectionToggle,
    required this.isUserFood,
    this.onSearchOpenFoodFacts,
    this.showOpenFoodFactsButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasNoResults = searchResults.isEmpty &&
        userFoods.isEmpty &&
        catalogResults.isEmpty &&
        !isSearchingCatalog;

    if (hasNoResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.magnifyingGlass,
                size: AppIconSizes.xl,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No foods found for "$searchQuery"',
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        // My Foods section (if matching user foods exist)
        if (userFoods.isNotEmpty) ...[
          _MyFoodsSectionHeader(
            userFoodCount: userFoods.length,
            isExpanded: isMyFoodsExpanded,
            onToggle: onMyFoodsSectionToggle,
          ),
          if (isMyFoodsExpanded)
            ...userFoods.map((food) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FoodCardWidget(
                food: food,
                isUserFood: isUserFood(food),
                onTap: () => onFoodTap(food),
                onLongPress: onFoodLongPress != null ? () => onFoodLongPress!(food) : null,
                onEdit: onFoodEdit != null ? () => onFoodEdit!(food) : null,
              ),
            )),
          const SizedBox(height: AppSpacing.md),
        ],
        // Search Results header
        if (searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Search Results',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        // Search result food cards
        ...searchResults.map((food) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: FoodCardWidget(
            food: food,
            isUserFood: isUserFood(food),
            onTap: () => onFoodTap(food),
            onLongPress: onFoodLongPress != null ? () => onFoodLongPress!(food) : null,
            onEdit: onFoodEdit != null ? () => onFoodEdit!(food) : null,
          ),
        )),

        // Product Catalog section
        CatalogSectionWidget(
          catalogResults: catalogResults,
          isSearchingCatalog: isSearchingCatalog,
          onCatalogResultTap: onCatalogResultTap,
        ),

        // Search OpenFoodFacts button at bottom of results
        if (showOpenFoodFactsButton && onSearchOpenFoodFacts != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
            child: SearchOpenFoodFactsButton(
              onPressed: onSearchOpenFoodFacts!,
            ),
          ),
      ],
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

/// Widget for displaying OpenFoodFacts search results
class OpenFoodFactsResultsWidget extends StatelessWidget {
  final List<dynamic> results;
  final void Function(dynamic) onResultTap;

  const OpenFoodFactsResultsWidget({
    super.key,
    required this.results,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final result = results[index];
        return _OpenFoodFactsCard(
          result: result,
          onTap: () => onResultTap(result),
        );
      },
    );
  }
}

/// Individual OpenFoodFacts result card
class _OpenFoodFactsCard extends StatelessWidget {
  final dynamic result;
  final VoidCallback onTap;

  const _OpenFoodFactsCard({
    required this.result,
    required this.onTap,
  });

  String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

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
              // Product image
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
                          errorBuilder: (context, error, stackTrace) => Icon(
                            FontAwesomeIcons.utensils,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: AppIconSizes.controlIcon,
                          ),
                        ),
                      )
                    : Icon(
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
                      _capitalize(result.displayName ?? 'Unknown Product'),
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.categories?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.categories!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
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
