import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../barcode_scanning/application/catalog_search_service.dart';

/// Widget for displaying product catalog search results
/// Shows catalog results with nutrition badges and loading states
class CatalogSectionWidget extends StatelessWidget {
  final List<CatalogSearchResult> catalogResults;
  final bool isSearchingCatalog;
  final void Function(CatalogSearchResult) onCatalogResultTap;

  const CatalogSectionWidget({
    super.key,
    required this.catalogResults,
    required this.isSearchingCatalog,
    required this.onCatalogResultTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while searching
    if (isSearchingCatalog && catalogResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.store,
                    size: AppIconSizes.sm,
                    color: AppColors.electrolyte,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Product Catalog',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ),
      );
    }

    // Nothing to show
    if (catalogResults.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.store,
                  size: AppIconSizes.sm,
                  color: AppColors.electrolyte,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Product Catalog',
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
                    color: AppColors.electrolyte.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${catalogResults.length}',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: AppColors.electrolyte,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSearchingCatalog)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          // Catalog result cards
          ...catalogResults.map((result) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CatalogCard(
              result: result,
              onTap: () => onCatalogResultTap(result),
            ),
          )),
        ],
      ),
    );
  }
}

/// Individual catalog result card
class _CatalogCard extends StatelessWidget {
  final CatalogSearchResult result;
  final VoidCallback onTap;

  const _CatalogCard({
    required this.result,
    required this.onTap,
  });

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
              // Product image or placeholder
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
                            FontAwesomeIcons.cartShopping,
                            color: AppColors.electrolyte,
                            size: AppIconSizes.controlIcon,
                          ),
                        ),
                      )
                    : Icon(
                        FontAwesomeIcons.cartShopping,
                        color: AppColors.electrolyte,
                        size: AppIconSizes.controlIcon,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName,
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.brand != null && result.brand!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.brand!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    // Nutrition badge row
                    Row(
                      children: [
                        if (result.hasNutrition) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.electrolyte.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${result.carbsG?.toInt() ?? 0}g carbs',
                              style: AppTextStyles.smallLabel.copyWith(
                                color: AppColors.electrolyte,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (result.caloriesPerServing != null)
                            Text(
                              '${result.caloriesPerServing} cal',
                              style: AppTextStyles.smallLabel.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                        ] else
                          Text(
                            'No nutrition data',
                            style: AppTextStyles.smallLabel.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                result.hasNutrition
                    ? FontAwesomeIcons.circlePlus
                    : FontAwesomeIcons.chevronRight,
                color: result.hasNutrition
                    ? AppColors.orange
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: AppIconSizes.md,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
