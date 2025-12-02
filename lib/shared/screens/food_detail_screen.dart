import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../features/nutrition_plan/domain/food.dart';
import '../../features/nutrition_plan/domain/food_item.dart';
import '../widgets/kyle_design/kyle_design.dart';

/// Mode for the FoodDetailScreen - determines behavior and visible fields
enum FoodDetailMode {
  /// Adding a new food from barcode scan - shows image, all fields editable
  addFromScan,

  /// Adding a new food from search - all fields editable
  addFromSearch,

  /// Editing an existing user food - shows delete button
  editExisting,
}

/// Context for where the FoodDetailScreen was opened from
/// Used to customize button text and behavior
enum FoodDetailContext {
  onboarding,
  swapFood,
  addFood,
  foodPreferences,
  carbLoading,
}

/// Product types available for user foods
/// These map to the product_type enum values in the database
class ProductTypeOption {
  const ProductTypeOption({
    required this.value,
    required this.label,
    required this.description,
  });

  final String value;
  final String label;
  final String description;
}

const productTypeOptions = [
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

/// Beverage-related product types that should show fluid field
const beverageProductTypes = [
  'sports_drink',
  'drink_mix',
  'electrolyte_only',
  'recovery_shake',
];

/// Data class for initializing FoodDetailScreen
/// Consolidates data from Food, FoodItem, and UserFoodData
class FoodDetailData {
  FoodDetailData({
    required this.id,
    required this.name,
    this.imageUrl,
    this.servingSize,
    this.servingAmount,
    this.servingUnit,
    this.carbsPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.sodiumMg,
    this.caloriesPerServing,
    this.fluidMlPerServing,
    this.productType,
    this.categoryIds = const [],
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? servingSize;
  final double? servingAmount;
  final String? servingUnit;
  final double? carbsPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final int? sodiumMg;
  final int? caloriesPerServing;
  final double? fluidMlPerServing;
  final String? productType;
  final List<int> categoryIds;

  /// Create from Food domain object
  factory FoodDetailData.fromFood(Food food) {
    return FoodDetailData(
      id: food.id,
      name: food.name,
      imageUrl: food.imageUrl,
      servingSize: food.servingSize,
      servingAmount: food.servingAmount,
      servingUnit: food.servingUnit,
      carbsPerServing: food.carbsPerServing,
      proteinPerServing: food.proteinPerServing,
      fatPerServing: food.fatPerServing,
      sodiumMg: food.sodiumMg,
      caloriesPerServing: food.caloriesPerServing,
      fluidMlPerServing: food.fluidMlPerServing,
      productType: food.productTypeId,
      categoryIds: food.categories
          .map((name) {
            switch (name) {
              case 'before_run':
                return 1;
              case 'during_run':
                return 2;
              case 'after_run':
                return 3;
              default:
                return 1;
            }
          })
          .toList(),
    );
  }

  /// Create from FoodItem domain object
  factory FoodDetailData.fromFoodItem(FoodItem foodItem) {
    return FoodDetailData(
      id: foodItem.id,
      name: foodItem.name,
      imageUrl: foodItem.imageUrl,
      servingSize: foodItem.servingSize,
      servingAmount: foodItem.servingAmount,
      servingUnit: foodItem.servingUnit,
      carbsPerServing: foodItem.carbsPerServing,
      proteinPerServing: foodItem.proteinPerServing,
      fatPerServing: foodItem.fatPerServing,
      sodiumMg: foodItem.sodiumMg,
      caloriesPerServing: foodItem.caloriesPerServing,
      fluidMlPerServing: foodItem.fluidMlPerServing,
      productType: foodItem.productTypeId,
      categoryIds: foodItem.categories.map((cat) {
        switch (cat) {
          case FoodCategory.beforeRun:
            return 1;
          case FoodCategory.duringRun:
            return 2;
          case FoodCategory.afterRun:
            return 3;
        }
      }).toList(),
    );
  }
}

/// Result returned when saving from FoodDetailScreen
class FoodDetailResult {
  FoodDetailResult({
    required this.foodId,
    required this.name,
    this.servingSize,
    this.servingAmount,
    this.servingUnit,
    required this.carbsPerServing,
    required this.proteinPerServing,
    required this.fatPerServing,
    required this.sodiumMg,
    required this.caloriesPerServing,
    this.fluidMlPerServing,
    required this.productType,
    required this.categoryIds,
  });

  final String foodId;
  final String name;
  final String? servingSize;
  final double? servingAmount;
  final String? servingUnit;
  final double carbsPerServing;
  final double proteinPerServing;
  final double fatPerServing;
  final int sodiumMg;
  final int caloriesPerServing;
  final double? fluidMlPerServing;
  final String productType;
  final List<int> categoryIds;
}

/// Unified full-screen page for adding and editing foods
/// Replaces: NutritionVerificationDialog, ScannedFoodCategorySheet, UserFoodEditSheet
///
/// Returns a [FoodDetailResult] when saved, or null when cancelled/deleted.
/// Use with `context.push<FoodDetailResult>('/food-detail', extra: {...})` and await result.
class FoodDetailScreen extends ConsumerStatefulWidget {
  const FoodDetailScreen({
    super.key,
    required this.foodData,
    required this.mode,
    this.screenContext = FoodDetailContext.addFood,
    this.preSelectedCategories,
    this.showCategories = true,
    this.showProductType = true,
    this.allowDelete = false,
  });

  final FoodDetailData foodData;
  final FoodDetailMode mode;
  final FoodDetailContext screenContext;

  /// Optional pre-selected categories (1=before_run, 2=during_run, 3=after_run)
  /// If null, uses categories from foodData or defaults to all selected
  final List<int>? preSelectedCategories;

  /// Whether to show category checkboxes (false for carb loading context)
  final bool showCategories;

  /// Whether to show product type dropdown
  final bool showProductType;

  /// Whether to show delete button (only for editExisting mode)
  final bool allowDelete;

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  // Category selections
  late Map<int, bool> _selectedCategories;

  // Product type selection
  late String _selectedProductType;

  // Text controllers
  late TextEditingController _nameController;
  late TextEditingController _servingSizeController;
  late TextEditingController _servingAmountController;
  late TextEditingController _servingUnitController;
  late TextEditingController _caloriesController;
  late TextEditingController _carbsController;
  late TextEditingController _proteinController;
  late TextEditingController _fatController;
  late TextEditingController _sodiumController;
  late TextEditingController _fluidController;

  bool _hasChanges = false;

  // Prevent double-tap navigation crashes
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Initialize category selections
    if (widget.preSelectedCategories != null) {
      _selectedCategories = {
        1: widget.preSelectedCategories!.contains(1),
        2: widget.preSelectedCategories!.contains(2),
        3: widget.preSelectedCategories!.contains(3),
      };
    } else if (widget.foodData.categoryIds.isNotEmpty) {
      _selectedCategories = {
        1: widget.foodData.categoryIds.contains(1),
        2: widget.foodData.categoryIds.contains(2),
        3: widget.foodData.categoryIds.contains(3),
      };
    } else {
      // Default: all checked for new foods
      _selectedCategories = {
        1: true,
        2: true,
        3: true,
      };
    }

    // Initialize product type
    _selectedProductType = widget.foodData.productType ?? 'import';

    // Initialize text controllers
    _nameController = TextEditingController(text: widget.foodData.name);
    _servingSizeController =
        TextEditingController(text: widget.foodData.servingSize ?? '');
    _servingAmountController = TextEditingController(
      text: widget.foodData.servingAmount?.toStringAsFixed(0) ?? '1',
    );
    _servingUnitController =
        TextEditingController(text: widget.foodData.servingUnit ?? 'serving');
    _caloriesController = TextEditingController(
      text: (widget.foodData.caloriesPerServing ?? 0).toString(),
    );
    _carbsController = TextEditingController(
      text: (widget.foodData.carbsPerServing ?? 0).toStringAsFixed(1),
    );
    _proteinController = TextEditingController(
      text: (widget.foodData.proteinPerServing ?? 0).toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: (widget.foodData.fatPerServing ?? 0).toStringAsFixed(1),
    );
    _sodiumController = TextEditingController(
      text: (widget.foodData.sodiumMg ?? 0).toString(),
    );
    _fluidController = TextEditingController(
      text: (widget.foodData.fluidMlPerServing ?? 0).toStringAsFixed(0),
    );

    // Add listeners to track changes
    _nameController.addListener(_onFieldChanged);
    _servingSizeController.addListener(_onFieldChanged);
    _servingAmountController.addListener(_onFieldChanged);
    _servingUnitController.addListener(_onFieldChanged);
    _caloriesController.addListener(_onFieldChanged);
    _carbsController.addListener(_onFieldChanged);
    _proteinController.addListener(_onFieldChanged);
    _fatController.addListener(_onFieldChanged);
    _sodiumController.addListener(_onFieldChanged);
    _fluidController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _servingAmountController.dispose();
    _servingUnitController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    _fluidController.dispose();
    super.dispose();
  }

  bool get _hasValidCategorySelection =>
      !widget.showCategories ||
      _selectedCategories.values.any((selected) => selected);

  bool get _hasValidName => _nameController.text.trim().isNotEmpty;

  bool get _isValid => _hasValidName && _hasValidCategorySelection;

  bool get _shouldShowFluidField {
    // Show if already has fluid value > 0
    if ((widget.foodData.fluidMlPerServing ?? 0) > 0) return true;
    // Show if product type is beverage-related
    return beverageProductTypes.contains(_selectedProductType);
  }

  String get _screenTitle {
    switch (widget.mode) {
      case FoodDetailMode.addFromScan:
        return 'Add Scanned Food';
      case FoodDetailMode.addFromSearch:
        return 'Add Food';
      case FoodDetailMode.editExisting:
        return 'Edit Food';
    }
  }

  String get _primaryButtonText {
    if (widget.mode == FoodDetailMode.editExisting) {
      return 'Save Changes';
    }
    switch (widget.screenContext) {
      case FoodDetailContext.onboarding:
        return 'Add to My Foods';
      case FoodDetailContext.swapFood:
        return 'Swap Food';
      case FoodDetailContext.carbLoading:
        return 'Add Food';
      case FoodDetailContext.foodPreferences:
      case FoodDetailContext.addFood:
        return 'Add Food';
    }
  }

  void _handleSave() {
    if (!_hasValidName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a food name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.showCategories && !_hasValidCategorySelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get selected category IDs
    final selectedCategoryIds = widget.showCategories
        ? _selectedCategories.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList()
        : <int>[];

    // Parse values
    final result = FoodDetailResult(
      foodId: widget.foodData.id,
      name: _nameController.text.trim(),
      servingSize: _servingSizeController.text.trim().isNotEmpty
          ? _servingSizeController.text.trim()
          : null,
      servingAmount: double.tryParse(_servingAmountController.text),
      servingUnit: _servingUnitController.text.trim().isNotEmpty
          ? _servingUnitController.text.trim()
          : null,
      caloriesPerServing: int.tryParse(_caloriesController.text) ?? 0,
      carbsPerServing: double.tryParse(_carbsController.text) ?? 0.0,
      proteinPerServing: double.tryParse(_proteinController.text) ?? 0.0,
      fatPerServing: double.tryParse(_fatController.text) ?? 0.0,
      sodiumMg: int.tryParse(_sodiumController.text) ?? 0,
      fluidMlPerServing: _shouldShowFluidField
          ? double.tryParse(_fluidController.text)
          : null,
      productType: _selectedProductType,
      categoryIds: selectedCategoryIds,
    );

    // Pop with the result - the calling screen handles the result
    context.pop(result);
  }

  void _handleDelete() {
    if (!widget.allowDelete) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Food'),
        content: Text(
            'Are you sure you want to delete "${_nameController.text.trim()}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close dialog
              // Pop with a special delete marker - using foodId prefixed with 'DELETE:'
              context.pop('DELETE:${widget.foodData.id}');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.chevronLeft),
          onPressed: () {
            if (_isNavigating) return;
            _isNavigating = true;
            context.pop();
          },
        ),
        actions: [
          if (widget.mode == FoodDetailMode.editExisting && widget.allowDelete)
            IconButton(
              onPressed: _handleDelete,
              icon: Icon(
                FontAwesomeIcons.trash,
                color: Colors.red.shade400,
                size: AppIconSizes.md,
              ),
              tooltip: 'Delete food',
            ),
        ],
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image (for scanned foods)
                  if (widget.foodData.imageUrl != null &&
                      widget.mode == FoodDetailMode.addFromScan) ...[
                    Center(
                      child: ClipRRect(
                        borderRadius: AppRadius.cardRadius,
                        child: Image.network(
                          widget.foodData.imageUrl!,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.blackberry.withValues(alpha: 0.3)
                                    : Colors.grey[200],
                                borderRadius: AppRadius.cardRadius,
                              ),
                              child: Icon(
                                FontAwesomeIcons.utensils,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Food name
                  _buildSectionTitle('Food Name'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Enter food name',
                    isDark: isDark,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Serving info
                  _buildSectionTitle('Serving Size'),
                  const SizedBox(height: AppSpacing.sm),

                  // Serving size text (from barcode scan)
                  if (widget.mode == FoodDetailMode.addFromScan) ...[
                    _buildTextField(
                      controller: _servingSizeController,
                      hint: 'e.g., 1 packet (32g)',
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Serving amount and unit
                  Row(
                    children: [
                      Expanded(
                        child: _buildNutritionField(
                          controller: _servingAmountController,
                          label: 'Amount',
                          suffix: '',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit',
                              style: AppTextStyles.smallLabel.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _buildTextField(
                              controller: _servingUnitController,
                              hint: 'e.g., serving, cup',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Nutrition section
                  _buildSectionTitle('Nutrition Information'),
                  const SizedBox(height: AppSpacing.sm),

                  // Calories
                  _buildNutritionField(
                    controller: _caloriesController,
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
                          allowDecimals: false,
                        ),
                      ),
                    ],
                  ),

                  // Fluid amount field (smart display)
                  if (_shouldShowFluidField) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionField(
                      controller: _fluidController,
                      label: 'Fluid Amount',
                      suffix: 'ml',
                      isDark: isDark,
                      allowDecimals: false,
                    ),
                  ],

                  // Category section
                  if (widget.showCategories) ...[
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionTitle('When would you eat this?'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Select one or more categories (at least one required)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Category checkboxes
                    _buildCategoryCheckbox(
                        1, 'Before Run', 'Fuel up before your workout', isDark),
                    const SizedBox(height: AppSpacing.sm),
                    _buildCategoryCheckbox(
                        2, 'During Run', 'Energy during long workouts', isDark),
                    const SizedBox(height: AppSpacing.sm),
                    _buildCategoryCheckbox(
                        3, 'After Run', 'Recovery after your workout', isDark),
                  ],

                  // Product type section
                  if (widget.showProductType) ...[
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionTitle('What type of food is this?'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Helps us recommend similar alternatives',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildProductTypeDropdown(isDark),
                  ],

                  const SizedBox(height: AppSpacing.xl),
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
              onPressed: _isValid ? _handleSave : null,
              text: _primaryButtonText,
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.subtitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }

  Widget _buildNutritionField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isDark,
    bool allowDecimals = true,
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
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
          inputFormatters: [
            if (allowDecimals)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
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

  Widget _buildCategoryCheckbox(
      int categoryId, String title, String subtitle, bool isDark) {
    final isSelected = _selectedCategories[categoryId] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategories[categoryId] = !isSelected;
          _hasChanges = true;
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
                : isDark
                    ? AppColors.cream.withValues(alpha: 0.3)
                    : AppColors.blackberry.withValues(alpha: 0.3),
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
                      : isDark
                          ? AppColors.cream.withValues(alpha: 0.5)
                          : AppColors.blackberry.withValues(alpha: 0.5),
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

  Widget _buildProductTypeDropdown(bool isDark) {
    return Container(
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
          value: _selectedProductType,
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
              setState(() {
                _selectedProductType = value;
                _hasChanges = true;
              });
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
    );
  }
}
