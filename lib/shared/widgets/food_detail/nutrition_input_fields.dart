import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/kyle_design/kyle_design.dart';

/// Widget that displays all nutrition input fields for a food item.
/// Includes: calories, carbs, protein, fat, sodium, and optional fluid amount.
class NutritionInputFields extends StatelessWidget {
  final TextEditingController caloriesController;
  final TextEditingController carbsController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController sodiumController;
  final TextEditingController fluidController;
  final bool showFluidField;
  final VoidCallback onFieldChanged;

  const NutritionInputFields({
    super.key,
    required this.caloriesController,
    required this.carbsController,
    required this.proteinController,
    required this.fatController,
    required this.sodiumController,
    required this.fluidController,
    required this.showFluidField,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          key: const ValueKey('custom_food.nutrition_section'),
          'Nutrition Information',
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Calories
        _buildNutritionField(
          fieldKey: const ValueKey('custom_food.calories_field'),
          context: context,
          controller: caloriesController,
          label: 'Calories',
          suffix: 'cal',
          isDark: isDark,
          allowDecimals: false,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Carbs and Protein row
        Row(
          children: [
            Expanded(
              child: _buildNutritionField(
                fieldKey: const ValueKey('custom_food.carbs_field'),
                context: context,
                controller: carbsController,
                label: 'Carbs',
                suffix: 'g',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildNutritionField(
                fieldKey: const ValueKey('custom_food.protein_field'),
                context: context,
                controller: proteinController,
                label: 'Protein',
                suffix: 'g',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Fat and Sodium row
        Row(
          children: [
            Expanded(
              child: _buildNutritionField(
                fieldKey: const ValueKey('custom_food.fat_field'),
                context: context,
                controller: fatController,
                label: 'Fat',
                suffix: 'g',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildNutritionField(
                fieldKey: const ValueKey('custom_food.sodium_field'),
                context: context,
                controller: sodiumController,
                label: 'Sodium',
                suffix: 'mg',
                isDark: isDark,
                allowDecimals: false,
              ),
            ),
          ],
        ),

        // Fluid amount field (conditional)
        if (showFluidField) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildNutritionField(
            context: context,
            controller: fluidController,
            label: 'Fluid Amount',
            suffix: 'ml',
            isDark: isDark,
            allowDecimals: false,
          ),
        ],
      ],
    );
  }

  Widget _buildNutritionField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isDark,
    bool allowDecimals = true,
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
          inputFormatters: [
            if (allowDecimals)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => onFieldChanged(),
          decoration: InputDecoration(
            suffixText: suffix.isNotEmpty ? suffix : null,
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.cream.withValues(alpha: 0.3)
                    : AppColors.blackberry.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.cream.withValues(alpha: 0.3)
                    : AppColors.blackberry.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: AppColors.electrolyte,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            isDense: true,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
