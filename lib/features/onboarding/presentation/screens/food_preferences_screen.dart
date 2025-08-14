import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/data/models/user_preferences.dart';
import '../../../nutrition_plan/data/food_database.dart';
import '../../../nutrition_plan/data/models/food_item.dart';

/// Food preferences screen - final step of onboarding
/// Users select their preferences for each of the 12 food items
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  final Map<String, FoodPreference> _preferences = {};
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Initialize all preferences to neutral
    for (final food in FoodDatabase.getAllFoods()) {
      _preferences[food.id] = FoodPreference.neutral;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updatePreference(String foodId, FoodPreference preference) {
    setState(() {
      _preferences[foodId] = preference;
    });
  }

  void _nextPage() {
    if (_currentPage < FoodDatabase.getAllFoods().length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // Filter out neutral preferences to only save actual choices
    final actualPreferences = Map<String, FoodPreference>.fromEntries(
      _preferences.entries.where((entry) => entry.value != FoodPreference.neutral),
    );

    final controller = ref.read(onboardingControllerProvider.notifier);
    final success = await controller.saveFoodPreferences(actualPreferences);

    if (success && mounted) {
      context.go('/home');
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
        actions: [
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _previousPage,
            ),
        ],
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
                  '${_currentPage + 1} of ${foods.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Food preference cards
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: foods.length,
              itemBuilder: (context, index) {
                final food = foods[index];
                return _FoodPreferenceCard(
                  food: food,
                  preference: _preferences[food.id]!,
                  onPreferenceChanged: (preference) => _updatePreference(food.id, preference),
                );
              },
            ),
          ),

          // Navigation buttons
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Previous'),
                    ),
                  ),
                
                if (_currentPage > 0) SizedBox(width: 16.w),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: asyncState.isLoading 
                        ? null 
                        : (_currentPage == foods.length - 1 ? _completeOnboarding : _nextPage),
                    child: asyncState.isLoading
                        ? const CircularProgressIndicator()
                        : Text(_currentPage == foods.length - 1 ? 'Complete Setup' : 'Next'),
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

class _FoodPreferenceCard extends StatelessWidget {
  final FoodItem food;
  final FoodPreference preference;
  final ValueChanged<FoodPreference> onPreferenceChanged;

  const _FoodPreferenceCard({
    required this.food,
    required this.preference,
    required this.onPreferenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 24.h),
          
          // Food image placeholder
          Container(
            width: 200.w,
            height: 200.h,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              _getCategoryIcon(food.category),
              size: 80.w,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // Food name and category
          Text(
            food.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 8.h),
          
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12.r),
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
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 8.h),
          
          // Serving size
          Text(
            'Serving: ${food.servingSize}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 32.h),
          
          // Additional info if available
          if (food.additionalInfo != null) ...[
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      food.additionalInfo!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
          ],
          
          // Preference selection
          Text(
            'How do you feel about this food?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 20.h),
          
          // Preference buttons
          Column(
            children: [
              _PreferenceButton(
                label: 'Like',
                description: 'I enjoy eating this',
                icon: Icons.thumb_up,
                isSelected: preference == FoodPreference.like,
                onTap: () => onPreferenceChanged(FoodPreference.like),
              ),
              
              SizedBox(height: 12.h),
              
              _PreferenceButton(
                label: 'Open to Try',
                description: 'I\'m willing to give it a try',
                icon: Icons.help_outline,
                isSelected: preference == FoodPreference.willingToTry,
                onTap: () => onPreferenceChanged(FoodPreference.willingToTry),
              ),
              
              SizedBox(height: 12.h),
              
              _PreferenceButton(
                label: 'Dislike',
                description: 'I prefer not to eat this',
                icon: Icons.thumb_down,
                isSelected: preference == FoodPreference.dislike,
                onTap: () => onPreferenceChanged(FoodPreference.dislike),
              ),
            ],
          ),
          
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(FoodCategory category) {
    switch (category) {
      case FoodCategory.preRun:
        return Icons.breakfast_dining;
      case FoodCategory.duringRun:
        return Icons.sports_bar;
      case FoodCategory.postRun:
        return Icons.local_drink;
    }
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

class _PreferenceButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PreferenceButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              size: 24.w,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected 
                          ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20.w,
              ),
          ],
        ),
      ),
    );
  }
}