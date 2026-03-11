import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/kyle_design/kyle_design.dart';

/// Option for product type dropdown
class ProductTypeOption {
  final String value;
  final String label;
  final String description;

  const ProductTypeOption({
    required this.value,
    required this.label,
    required this.description,
  });
}

/// Predefined product type options
const List<ProductTypeOption> productTypeOptions = [
  ProductTypeOption(
    value: 'gel',
    label: 'Energy Gel',
    description: 'Quick-absorbing gel pouches',
  ),
  ProductTypeOption(
    value: 'chew',
    label: 'Energy Chew',
    description: 'Gummy or chewable energy',
  ),
  ProductTypeOption(
    value: 'bar',
    label: 'Energy/Protein Bar',
    description: 'Solid bars for sustained energy',
  ),
  ProductTypeOption(
    value: 'drink_mix',
    label: 'Drink Mix',
    description: 'Powder to mix with water',
  ),
  ProductTypeOption(
    value: 'sports_drink',
    label: 'Sports Drink',
    description: 'Ready-to-drink beverages',
  ),
  ProductTypeOption(
    value: 'real_food',
    label: 'Real Food',
    description: 'Whole foods like fruit, sandwiches',
  ),
  ProductTypeOption(
    value: 'waffle',
    label: 'Energy Waffle',
    description: 'Stroopwafels and similar',
  ),
  ProductTypeOption(
    value: 'electrolyte_only',
    label: 'Electrolytes Only',
    description: 'No calories, just electrolytes',
  ),
  ProductTypeOption(
    value: 'recovery_shake',
    label: 'Recovery Shake',
    description: 'Post-workout protein shakes',
  ),
  ProductTypeOption(
    value: 'import',
    label: 'Other / Custom',
    description: 'Doesn\'t fit other categories',
  ),
];

/// Beverage-related product types (for fluid field visibility)
const Set<String> beverageProductTypes = {
  'sports_drink',
  'drink_mix',
  'electrolyte_only',
  'recovery_shake',
};

/// Widget that displays product type selection dropdown.
/// Helps categorize foods for better recommendations.
class ProductTypeSelector extends StatelessWidget {
  final String selectedProductType;
  final ValueChanged<String> onProductTypeChanged;

  const ProductTypeSelector({
    super.key,
    required this.selectedProductType,
    required this.onProductTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What type of food is this?',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Helps us recommend similar alternatives',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.inputRadius,
            border: Border.all(
              color: isDark
                  ? AppColors.cream.withValues(alpha: 0.3)
                  : AppColors.blackberry.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedProductType,
              isExpanded: true,
              icon: Icon(
                FontAwesomeIcons.chevronDown,
                size: AppIconSizes.chevron,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              dropdownColor: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.cardRadius,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: productTypeOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option.value,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        option.description,
                        style: AppTextStyles.smallLabel.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onProductTypeChanged(value);
                }
              },
              selectedItemBuilder: (context) {
                return productTypeOptions.map((option) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      option.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ],
    );
  }
}
