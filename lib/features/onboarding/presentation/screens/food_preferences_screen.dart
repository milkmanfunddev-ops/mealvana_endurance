import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/data/food_database.dart';
import '../../../nutrition_plan/domain/food_item.dart';

/// Food preferences screen - final step of onboarding
/// Users select their food preferences using a checkbox list
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  final Map<String, bool> _selectedFoods = {};

  @override
  void initState() {
    super.initState();
    // Initialize all foods as unchecked (disliked)
    for (final food in FoodDatabase.getAllFoods()) {
      _selectedFoods[food.id] = false;
    }
  }

  void _selectAll() {
    setState(() {
      for (final key in _selectedFoods.keys) {
        _selectedFoods[key] = true;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final key in _selectedFoods.keys) {
        _selectedFoods[key] = false;
      }
    });
  }

  void _showFoodDetails(FoodItem food) {
    showDialog(
      context: context,
      builder: (context) => _FoodDetailDialog(food: food),
    );
  }

  Future<void> _completeOnboarding() async {
    // Convert checkbox selections to FoodPreference enum
    final preferences = <String, FoodPreference>{};
    
    _selectedFoods.forEach((foodId, isSelected) {
      preferences[foodId] = isSelected ? FoodPreference.like : FoodPreference.dislike;
    });

    final controller = ref.read(onboardingControllerProvider.notifier);
    final success = await controller.saveFoodPreferences(preferences);

    if (success && mounted) {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(onboardingControllerProvider);
    final foods = FoodDatabase.getAllFoods();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Preferences'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: 1.0, // 100% through onboarding
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Final Step: Food Preferences',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Header and instructions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose the foods you like',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                SizedBox(height: 8.h),
                
                Text(
                  'Check the foods you enjoy eating. Unchecked foods will be avoided in your nutrition plans.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                
                SizedBox(height: 16.h),
                
                // Select All / Clear All buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectAll,
                        icon: const Icon(Icons.check_box, size: 18),
                        label: const Text('Select All'),
                      ),
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.check_box_outline_blank, size: 18),
                        label: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Food checklist
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              itemCount: foods.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final food = foods[index];
                final isSelected = _selectedFoods[food.id] ?? false;
                
                return _FoodChecklistItem(
                  food: food,
                  isSelected: isSelected,
                  onChanged: (value) {
                    setState(() {
                      _selectedFoods[food.id] = value ?? false;
                    });
                  },
                  onTapDetails: () => _showFoodDetails(food),
                );
              },
            ),
          ),

          // Bottom actions
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                // Summary
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: theme.colorScheme.primary,
                        size: 20.w,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${_selectedFoods.values.where((v) => v).length} foods selected',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16.h),
                
                // Complete button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: asyncState.isLoading ? null : _completeOnboarding,
                    child: asyncState.isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Complete Setup'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodChecklistItem extends StatelessWidget {
  final FoodItem food;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTapDetails;

  const _FoodChecklistItem({
    required this.food,
    required this.isSelected,
    required this.onChanged,
    required this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onChanged,
        title: Row(
          children: [
            Expanded(
              child: Text(
                food.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            
            // Info button
            IconButton(
              onPressed: onTapDetails,
              icon: Icon(
                Icons.info_outline,
                size: 20.w,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'More info',
            ),
          ],
        ),
        subtitle: Text(
          _getCategoryDisplayName(food.category),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.only(left: 8.w, right: 4.w),
      ),
    );
  }

  String _getCategoryDisplayName(FoodCategory category) {
    switch (category) {
      case FoodCategory.preRun:
        return 'Pre-Run';
      case FoodCategory.duringRun:
        return 'During-Run';
      case FoodCategory.postRun:
        return 'Post-Run';
    }
  }
}

class _FoodDetailDialog extends StatelessWidget {
  final FoodItem food;

  const _FoodDetailDialog({required this.food});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(food.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _getCategoryDisplayName(food.category),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Description
            Text(
              food.description,
              style: theme.textTheme.bodyMedium,
            ),
            
            SizedBox(height: 12.h),
            
            // Serving size
            Text(
              'Serving: ${food.servingSize}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Additional info if available
            if (food.additionalInfo != null) ...[
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: theme.colorScheme.primary,
                      size: 16.w,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        food.additionalInfo!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _getCategoryDisplayName(FoodCategory category) {
    switch (category) {
      case FoodCategory.preRun:
        return 'Pre-Run Food';
      case FoodCategory.duringRun:
        return 'During-Run Food';
      case FoodCategory.postRun:
        return 'Post-Run Food';
    }
  }
}