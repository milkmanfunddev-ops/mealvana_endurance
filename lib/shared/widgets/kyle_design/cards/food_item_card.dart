import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

import '../icons/food_icon.dart';
import '../buttons/secondary_button.dart';
import '../buttons/tertiary_button.dart';
import 'base_card.dart';

/// Food Item Card - Kyle's Design System
/// Expandable card showing food details with nutrition facts
class FoodItemCard extends ConsumerStatefulWidget {
  const FoodItemCard({
    super.key,
    required this.food,
    this.onSwap,
    this.onRemove,
    this.onQuantityChanged,
  });

  final DisplayFoodItem food;
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final Function(double)? onQuantityChanged;

  @override
  ConsumerState<FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends ConsumerState<FoodItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Column(
        children: [
          // Main content (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Food icon
                  KyleFoodIcon(
                    foodType: mapFoodType(productTypeId: widget.food.productTypeId, name: widget.food.name),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  
                  // Food info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.food.name,
                          style: AppTextStyles.foodTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.food.servingSize,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Expand/collapse icon
                  Icon(
                    _isExpanded 
                        ? FontAwesomeIcons.chevronUp.data
                        : FontAwesomeIcons.chevronDown.data,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: AppIconSizes.chevron,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Nutrition facts grid
                  _buildNutritionFactsGrid(context),

                  const SizedBox(height: AppSpacing.md),

                  // Quantity controls
                  _buildQuantityControls(context),

                  const SizedBox(height: AppSpacing.md),

                  // Action buttons
                  _buildActionButtons(context),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionFactsGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: AppRadius.smRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Facts',
            style: AppTextStyles.smallLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildNutritionFact(
                  context: context,
                  label: 'Calories',
                  value: '${widget.food.calories.toInt()}',
                  color: AppColors.orange,
                ),
              ),
              Expanded(
                child: _buildNutritionFact(
                  context: context,
                  label: 'Carbs',
                  value: '${widget.food.carbsG.toStringAsFixed(1)}g',
                  color: AppColors.electrolyte,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildNutritionFact(
                  context: context,
                  label: 'Protein',
                  value: '${widget.food.proteinG.toStringAsFixed(1)}g',
                  color: AppColors.dragonfruit,
                ),
              ),
              Expanded(
                child: _buildNutritionFact(
                  context: context,
                  label: 'Fat',
                  value: '${widget.food.fatG.toStringAsFixed(1)}g',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionFact({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [ 
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: color,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityControls(BuildContext context) {
    return Row(
      children: [
        Text(
          'Quantity:',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.orange,
              width: 2,
            ),
            borderRadius: AppRadius.buttonRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrease button
              InkWell(
                onTap: () => _updateQuantity(-0.5),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.minus,
                    size: AppIconSizes.controlIcon,
                    color: AppColors.orange,
                  ),
                ),
              ),
              
              // Quantity display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  '1.0',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Increase button
              InkWell(
                onTap: () => _updateQuantity(0.5),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(14),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.plus,
                    size: AppIconSizes.controlIcon,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Swap button
        Expanded(
          child: KyleSecondaryButton(
            text: 'Swap Food Item',
            onPressed: widget.onSwap,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Remove button
        Expanded(
          child: KyleTertiaryButton(
            text: 'Remove Food Item',
            onPressed: widget.onRemove,
          ),
        ),
      ],
    );
  }

  void _updateQuantity(double delta) {
    if (widget.onQuantityChanged != null) {
      // Calculate new quantity (ensure it doesn't go below 0.5)
      final newQuantity = (1.0 + delta).clamp(0.5, 10.0);
      widget.onQuantityChanged!(newQuantity);
    }
  }

}



/// Mock DisplayFoodItem class for demonstration
class DisplayFoodItem {
  final String id;
  final String name;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double calories;
  final String servingSize;
  final String? productTypeId;

  DisplayFoodItem({
    required this.id,
    required this.name,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.calories,
    required this.servingSize,
    this.productTypeId,
  });
}