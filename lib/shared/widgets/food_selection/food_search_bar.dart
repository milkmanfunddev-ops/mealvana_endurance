import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// Unified search bar for food selection across different screens
/// Uses Kyle's design system for consistent styling
/// Configurable to show/hide filter button based on context
class FoodSearchBar extends StatelessWidget {
  const FoodSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onBarcodeScan,
    this.onChanged,
    this.showFilters = false,
    this.onFilterToggle,
    this.filtersEnabled = false,
    this.hintText = 'Search foods...',
    this.showClearButton = false,
    this.onClear,
  });

  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String)? onChanged;
  final VoidCallback onBarcodeScan;
  final bool showFilters;
  final VoidCallback? onFilterToggle;
  final bool filtersEnabled;
  final String hintText;
  final bool showClearButton;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Search input field
            Expanded(
              child: SizedBox(
                height: AppSizes.inputHeight,
                child: TextField(
                  controller: controller,
                  onChanged: (value) {
                    // For real-time search filtering (not API search)
                    if (onChanged != null) {
                      onChanged!(value);
                    } else {
                      // Fallback: clear search when empty
                      if (value.isEmpty) {
                        onSearch('');
                      }
                    }
                  },
                  onSubmitted: (_) => onSearch(controller.text),
                  style: AppTextStyles.inputText.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: AppSpacing.inputPadding,
                    hintText: hintText,
                    hintStyle: AppTextStyles.inputText.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      size: AppIconSizes.controlIcon,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barcode button
                        IconButton(
                          icon: Icon(
                            FontAwesomeIcons.barcode,
                            color: AppColors.orange,
                            size: AppIconSizes.controlIcon,
                          ),
                          onPressed: onBarcodeScan,
                        ),

                        // Filter button (only show for preferences screen)
                        if (showFilters)
                          IconButton(
                            icon: Icon(
                              FontAwesomeIcons.filter,
                              color: filtersEnabled
                                ? AppColors.orange
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                              size: AppIconSizes.controlIcon,
                            ),
                            onPressed: onFilterToggle,
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                      borderSide: const BorderSide(
                        color: AppColors.orange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Search button
            SizedBox(
              height: AppSizes.inputHeight,
              child: KylePrimaryButton(
                text: 'SEARCH',
                onPressed: () => onSearch(controller.text),
                isFullWidth: false,
              ),
            ),
          ],
        ),

        // Clear search button (when showing results)
        if (showClearButton) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton.icon(
              onPressed: onClear,
              icon: Icon(
                FontAwesomeIcons.xmark,
                size: AppIconSizes.sm,
                color: AppColors.orange,
              ),
              label: Text(
                'Clear Search',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
