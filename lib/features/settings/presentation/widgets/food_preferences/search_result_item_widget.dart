import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../barcode_scanning/application/open_food_facts_search_service.dart';

/// A search result card for displaying OpenFoodFacts products
///
/// Shows:
/// - Product image (if available)
/// - Product name and brand
/// - Add button icon
class SearchResultItemWidget extends StatelessWidget {
  final FoodSearchResult result;
  final VoidCallback onTap;

  const SearchResultItemWidget({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.blackberry.withOpacity(0.3)
              : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.electrolyte.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Product image (if available)
            if (result.imageUrl?.isNotEmpty == true)
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardRadius,
                  image: DecorationImage(
                    image: NetworkImage(result.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayName,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (result.brand?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      result.brand!,
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Add button
            FaIcon(
              FontAwesomeIcons.circlePlus,
              size: AppIconSizes.lg,
              color: AppColors.electrolyte,
            ),
          ],
        ),
      ),
    );
  }
}
