import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../theme/app_theme.dart';
import '../../application/food_import_service.dart';
import '../../domain/meal_type.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../auth/application/auth_service.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Screen for creating a custom carb loading food from scratch
class CreateCustomCarbLoadingFoodScreen extends ConsumerStatefulWidget {
  final String dayId;
  final MealType mealType;

  const CreateCustomCarbLoadingFoodScreen({
    super.key,
    required this.dayId,
    required this.mealType,
  });

  @override
  ConsumerState<CreateCustomCarbLoadingFoodScreen> createState() =>
      _CreateCustomCarbLoadingFoodScreenState();
}

class _CreateCustomCarbLoadingFoodScreenState
    extends ConsumerState<CreateCustomCarbLoadingFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _carbsController = TextEditingController();

  // Selected meal types (multi-select)
  final Set<MealType> _selectedMealTypes = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-select the current meal type
    _selectedMealTypes.add(widget.mealType);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMealTypes.isEmpty) {
      MealvanaSnackbar.showWarning(context, 'Please select at least one meal type');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final deviceId = await ref.read(userIdProvider.future);
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      final userId = user?.id ?? deviceId; // Fallback to deviceId if no user
      final importService = ref.read(foodImportServiceProvider);

      // Create the custom food
      final newFood = await importService.createCustomFood(
        deviceId: deviceId,
        userId: userId,
        name: _nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
        displayName: _displayNameController.text.trim(),
        displayNamePlural: _displayNameController.text.trim(),
        carbsPerServing: double.parse(_carbsController.text.trim()),
        imageAddress: null, // TODO: Add image picker in future
        barcode: null,
        mealTypes: _selectedMealTypes.toList(),
      );

      if (mounted) {
        // Return the created food
        context.pop(newFood);
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to create food: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Custom Food',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food Name
                      _buildSectionTitle('Food Name'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Enter food name',
                        isDark: isDark,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Display Name
                      _buildSectionTitle('Display Name (with serving)'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTextField(
                        controller: _displayNameController,
                        hint: 'e.g., 2 cups cooked pasta',
                        isDark: isDark,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Carbs Per Serving
                      _buildSectionTitle('Carbs Per Serving (grams)'),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _carbsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g., 65',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          suffixText: 'g',
                          suffixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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

                      const SizedBox(height: AppSpacing.lg),

                      // Meal Type Selection
                      _buildSectionTitle('Suitable for Meals'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Select which meals this food is suitable for',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: MealType.values.map((mealType) {
                          final isSelected = _selectedMealTypes.contains(mealType);
                          String mealName;
                          switch (mealType) {
                            case MealType.breakfast:
                              mealName = 'Breakfast';
                            case MealType.lunch:
                              mealName = 'Lunch';
                            case MealType.dinner:
                              mealName = 'Dinner';
                            case MealType.snacks:
                              mealName = 'Snacks';
                            case MealType.morningSnack:
                              mealName = 'Morning Snack';
                            case MealType.afternoonSnack:
                              mealName = 'Afternoon Snack';
                            case MealType.eveningSnack:
                              mealName = 'Evening Snack';
                          }

                          return FilterChip(
                            label: Text(mealName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedMealTypes.add(mealType);
                                } else {
                                  _selectedMealTypes.remove(mealType);
                                }
                              });
                            },
                            selectedColor: AppColors.electrolyte,
                            checkmarkColor: AppColors.cream,
                            labelStyle: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected
                                  ? AppColors.cream
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.electrolyte
                                  : (isDark
                                      ? AppColors.cream.withValues(alpha: 0.3)
                                      : AppColors.blackberry.withValues(alpha: 0.3)),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ),

              // Save Button (fixed at bottom)
              Padding(
                padding: AppSpacing.screenPadding,
                child: PrimaryButton(
                  text: _isSaving ? 'Saving...' : 'Save Food',
                  onPressed: _isSaving ? null : _handleSave,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
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
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
          borderSide: const BorderSide(color: AppColors.electrolyte, width: 2),
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
}
