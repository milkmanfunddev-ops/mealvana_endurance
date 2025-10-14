import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../theme/app_theme.dart';
import '../../application/food_import_service.dart';
import '../../domain/meal_type.dart';
import '../../../../shared/providers/device_id_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final deviceId = await ref.read(deviceIdProvider.future);
      final importService = ref.read(foodImportServiceProvider);

      // Create the custom food
      final newFood = await importService.createCustomFood(
        deviceId: deviceId,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create food: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Custom Food',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // Instructions
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary50.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.primary100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primary600,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Create a custom carb loading food to quickly track your carb intake.',
                        style: AppTheme.textStyle.copyWith(
                          color: AppTheme.primary900,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Food Name
              Text(
                'Food Name*',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.primary900,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., My Favorite Pasta',
                  filled: true,
                  fillColor: AppTheme.baseWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.baseGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.primary600, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a food name';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20.h),

              // Display Name (serving info)
              Text(
                'Display Name (with serving)*',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.primary900,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  hintText: 'e.g., 2 cups cooked pasta',
                  filled: true,
                  fillColor: AppTheme.baseWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.baseGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.primary600, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20.h),

              // Carbs Per Serving
              Text(
                'Carbs Per Serving (grams)*',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.primary900,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _carbsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g., 65',
                  suffixText: 'g',
                  filled: true,
                  fillColor: AppTheme.baseWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.baseGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppTheme.primary600, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter carbs per serving';
                  }
                  final carbs = double.tryParse(value.trim());
                  if (carbs == null || carbs <= 0) {
                    return 'Please enter a valid number greater than 0';
                  }
                  return null;
                },
              ),

              SizedBox(height: 24.h),

              // Meal Type Selection
              Text(
                'Suitable for Meals*',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.primary900,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Select which meals this food is suitable for',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 12.h),

              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
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
                    selectedColor: AppTheme.primary600,
                    checkmarkColor: AppTheme.baseWhite,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.baseWhite : AppTheme.primary900,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: AppTheme.baseWhite,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary600 : AppTheme.primary100,
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 32.h),

              // Save Button
              PrimaryButton(
                text: _isSaving ? 'Saving...' : 'Save Food',
                onPressed: _isSaving ? null : _handleSave,
                width: double.infinity,
              ),

              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
