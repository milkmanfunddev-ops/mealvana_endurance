import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../features/nutrition_plan/domain/food_item.dart';
import 'kyle_design/kyle_design.dart';

/// Shared full-screen bottom modal sheet for category selection
/// Used by both onboarding and swap food screens when scanning products
class ScannedFoodCategorySheet extends ConsumerStatefulWidget {
  const ScannedFoodCategorySheet({
    super.key,
    required this.scannedFood,
    required this.context,
    required this.onSave,
    this.fluidMlPerServing,
  });

  final FoodItem scannedFood;
  final String context; // 'onboarding' or 'swap_food'
  final Function(List<int> categoryIds, double? fluidMlPerServing, {
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    double? sodiumMg,
  }) onSave;
  final double? fluidMlPerServing;

  @override
  ConsumerState<ScannedFoodCategorySheet> createState() => _ScannedFoodCategorySheetState();
}

class _ScannedFoodCategorySheetState extends ConsumerState<ScannedFoodCategorySheet> {
  // Category selections - all checked by default as per requirements
  final Map<int, bool> _selectedCategories = {
    1: true, // Before Run
    2: true, // During Run
    3: true, // After Run
  };

  late TextEditingController _fluidController;
  late TextEditingController _carbsController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _sodiumController;
  bool _isBeverage = false;

  @override
  void initState() {
    super.initState();

    // Initialize fluid controller with provided value or 0
    _fluidController = TextEditingController(
      text: widget.fluidMlPerServing?.toStringAsFixed(0) ?? '0',
    );

    // Initialize nutrition controllers with pre-filled values from Open Food Facts
    _carbsController = TextEditingController(
      text: (widget.scannedFood.carbsPerServing ?? 0).toStringAsFixed(1),
    );
    _proteinController = TextEditingController(
      text: (widget.scannedFood.proteinPerServing ?? 0).toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: (widget.scannedFood.fatPerServing ?? 0).toStringAsFixed(1),
    );
    _sodiumController = TextEditingController(
      text: (widget.scannedFood.sodiumMg ?? 0).toStringAsFixed(0),
    );

    // Check if this is a beverage based on fluid content
    _isBeverage = (widget.fluidMlPerServing ?? 0) > 0;
  }

  @override
  void dispose() {
    _fluidController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  bool get _hasValidSelection => _selectedCategories.values.any((selected) => selected);

  double? get _fluidAmount {
    final text = _fluidController.text.trim();
    if (text.isEmpty || !_isBeverage) return null;
    return double.tryParse(text);
  }

  void _handleSave() {
    if (!_hasValidSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedCategoryIds = _selectedCategories.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // Parse edited nutrition values
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;
    final sodium = double.tryParse(_sodiumController.text) ?? 0.0;

    widget.onSave(
      selectedCategoryIds,
      _fluidAmount,
      carbsPerServing: carbs,
      proteinPerServing: protein,
      fatPerServing: fat,
      sodiumMg: sodium,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cream.withValues(alpha: 0.3) : AppColors.blackberry.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: AppSpacing.screenPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.context == 'swap_food' ? 'Swap Food' : 'Add Food',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    FontAwesomeIcons.xmark,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: AppIconSizes.md,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: isDark ? AppColors.cream.withValues(alpha: 0.2) : AppColors.blackberry.withValues(alpha: 0.2),
            height: 1,
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scanned food details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.blackberry.withValues(alpha: 0.3) : Theme.of(context).colorScheme.surface,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                        color: AppColors.electrolyte.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Food name
                        Text(
                          widget.scannedFood.name,
                          style: AppTextStyles.foodTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Editable nutrition fields
                        Text(
                          'Nutrition Information',
                          style: AppTextStyles.subtitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Carbs and Protein row
                        Row(
                          children: [
                            Expanded(
                              child: _buildNutritionField(
                                controller: _carbsController,
                                label: 'Carbs',
                                suffix: 'g',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildNutritionField(
                                controller: _proteinController,
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
                                controller: _fatController,
                                label: 'Fat',
                                suffix: 'g',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildNutritionField(
                                controller: _sodiumController,
                                label: 'Sodium',
                                suffix: 'mg',
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        // Fluid amount field for beverages
                        if (_isBeverage) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildNutritionField(
                            controller: _fluidController,
                            label: 'Fluid Amount',
                            suffix: 'ml',
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Category selection
                  Text(
                    'When would you eat this?',
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Select one or more categories (at least one required)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category checkboxes
                  _buildCategoryCheckbox(1, 'Before Run', 'Fuel up before your workout', isDark),
                  const SizedBox(height: AppSpacing.sm),
                  _buildCategoryCheckbox(2, 'During Run', 'Energy during long workouts', isDark),
                  const SizedBox(height: AppSpacing.sm),
                  _buildCategoryCheckbox(3, 'After Run', 'Recovery after your workout', isDark),
                ],
              ),
            ),
          ),

          // Bottom action area
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: KylePrimaryButton(
              onPressed: _hasValidSelection ? _handleSave : null,
              text: widget.context == 'onboarding'
                  ? 'Add to My Foods'
                  : widget.context == 'swap_food'
                      ? 'Swap Food'
                      : 'Add Food',
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isDark,
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
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: suffix,
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: isDark ? AppColors.cream.withValues(alpha: 0.3) : AppColors.blackberry.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: isDark ? AppColors.cream.withValues(alpha: 0.3) : AppColors.blackberry.withValues(alpha: 0.3),
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

  Widget _buildCategoryCheckbox(int categoryId, String title, String subtitle, bool isDark) {
    final isSelected = _selectedCategories[categoryId] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategories[categoryId] = !isSelected;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electrolyte.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.electrolyte
                : isDark ? AppColors.cream.withValues(alpha: 0.3) : AppColors.blackberry.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.electrolyte : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? AppColors.electrolyte
                      : isDark ? AppColors.cream.withValues(alpha: 0.5) : AppColors.blackberry.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      FontAwesomeIcons.check,
                      color: AppColors.blackberry,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}