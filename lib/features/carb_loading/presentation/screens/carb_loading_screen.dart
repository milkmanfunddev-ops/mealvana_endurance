import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Carb Loading Screen - Kyle's Design System
/// Main screen for carb loading protocol management
class CarbLoadingScreen extends ConsumerWidget {
  const CarbLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildContent(context, ref),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Carb Loading',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return ContentArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const SizedBox(height: AppSpacing.lg),

          // Current protocol section
          _buildCurrentProtocolSection(context),

          const SizedBox(height: AppSpacing.lg),

          // Today's plan section
          _buildTodaysPlanSection(context, ref),

          const SizedBox(height: AppSpacing.lg),

          // Protocol options section
          _buildProtocolOptionsSection(context, ref),

          const SizedBox(height: AppSpacing.lg),

          // Food selection section
          _buildFoodSelectionSection(context, ref),

          const SizedBox(height: AppSpacing.xxxl),
        ],
        ),
      ),
    );
  }

  Widget _buildCurrentProtocolSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Protocol',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Protocol info
          Row(
            children: [
              // Protocol icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.electrolyte.withOpacity(0.2),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: FaIcon(
                  FontAwesomeIcons.bolt,
                  size: AppIconSizes.lg,
                  color: AppColors.electrolyte,
                ),
              ),
              
              const SizedBox(width: AppSpacing.md),
              
              // Protocol details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3-Day Loading Protocol',
                      style: AppTextStyles.activityTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Optimized for marathon performance',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Starts: Tomorrow • Duration: 3 days',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysPlanSection(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Plan",
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Day 1 meals
          _buildDayMeals(context, ref, 'Day 1', _getMockDay1Meals()),
          
          const SizedBox(height: AppSpacing.md),
          
          // Day 2 meals
          _buildDayMeals(context, ref, 'Day 2', _getMockDay2Meals()),
          
          const SizedBox(height: AppSpacing.md),
          
          // Day 3 meals
          _buildDayMeals(context, ref, 'Day 3', _getMockDay3Meals()),
        ],
      ),
    );
  }

  Widget _buildDayMeals(
    BuildContext context, 
    WidgetRef ref, 
    String dayTitle, 
    List<MockMeal> meals,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Row(
          children: [
            Text(
              dayTitle,
              style: AppTextStyles.activityTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${meals.fold(0, (sum, meal) => sum + meal.calories)} calories',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.sm),
        
        // Meals list
        ...meals.map((meal) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildMealItem(context, ref, meal),
        )),
        
        // Add meal button
        KyleAddFoodButton(
          text: 'Add Meal',
          onPressed: () => _addMeal(context, ref, dayTitle),
        ),
      ],
    );
  }

  Widget _buildMealItem(BuildContext context, WidgetRef ref, MockMeal meal) {
    return InkWell(
      onTap: () => _showMealDetails(context, ref, meal),
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Food icon
            KyleFoodIcon(
              foodType: mapFoodType(name: meal.name),
            ),
            
            const SizedBox(width: AppSpacing.md),
            
            // Meal info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${meal.calories} cal • ${meal.carbs}g carbs',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            // Quantity
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                ),
                borderRadius: AppRadius.smRadius,
              ),
              child: Text(
                '${meal.quantity}x',
                style: AppTextStyles.smallLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolOptionsSection(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protocol Options',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Protocol options
          _buildProtocolOption(
            context: context,
            title: 'Change Protocol',
            subtitle: 'Select a different carb loading protocol',
            icon: FontAwesomeIcons.exchange.data,
            onTap: () => _changeProtocol(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildProtocolOption(
            context: context,
            title: 'Custom Protocol',
            subtitle: 'Create your own carb loading plan',
            icon: FontAwesomeIcons.plus.data,
            onTap: () => _createCustomProtocol(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildProtocolOption(
            context: context,
            title: 'Protocol History',
            subtitle: 'View past carb loading protocols',
            icon: FontAwesomeIcons.clockRotateLeft.data,
            onTap: () => _viewProtocolHistory(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),
            
            const SizedBox(width: AppSpacing.md),
            
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Arrow icon
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodSelectionSection(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Add Foods',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Food categories
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildFoodCategory(
                context: context,
                icon: FontAwesomeIcons.breadSlice.data,
                label: 'Grains',
                onTap: () => _selectFoodCategory(context, ref, 'grains'),
              ),
              _buildFoodCategory(
                context: context,
                icon: FontAwesomeIcons.appleWhole.data,
                label: 'Fruits',
                onTap: () => _selectFoodCategory(context, ref, 'fruits'),
              ),
              _buildFoodCategory(
                context: context,
                icon: FontAwesomeIcons.drumstickBite.data,
                label: 'Proteins',
                onTap: () => _selectFoodCategory(context, ref, 'proteins'),
              ),
              _buildFoodCategory(
                context: context,
                icon: FontAwesomeIcons.cookie.data,
                label: 'Snacks',
                onTap: () => _selectFoodCategory(context, ref, 'snacks'),
              ),
              _buildFoodCategory(
                context: context,
                icon: FontAwesomeIcons.mugHot.data,
                label: 'Drinks',
                onTap: () => _selectFoodCategory(context, ref, 'drinks'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCategory({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        width: 100,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.lg,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.smallLabel.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMealDetails(BuildContext context, WidgetRef ref, MockMeal meal) {
    // Track meal details view
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('carb_loading_meal_details_tapped', properties: {
      'meal_name': meal.name,
      'calories': meal.calories,
      'carbs': meal.carbs,
    });

    showDialog(
      context: context,
      builder: (context) => _MealDetailsDialog(meal: meal),
    );
  }

  void _addMeal(BuildContext context, WidgetRef ref, String dayTitle) {
    // Track add meal
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('carb_loading_add_meal_tapped', properties: {
      'day': dayTitle,
    });

    // Navigate to food selection
    context.push('/carb-loading-food-selection');
  }

  void _changeProtocol(BuildContext context, WidgetRef ref) {
    // Track protocol change
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('carb_loading_change_protocol_tapped');

    context.push('/carb-loading-protocol-selection');
  }

  void _createCustomProtocol(BuildContext context, WidgetRef ref) {
    // Track custom protocol creation
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('carb_loading_custom_protocol_tapped');

    context.push('/carb-loading-custom-protocol');
  }

  void _viewProtocolHistory(BuildContext context, WidgetRef ref) {
    // Track protocol history view
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('carb_loading_protocol_history_tapped');

    context.push('/carb-loading-protocol-history');
  }

  void _selectFoodCategory(BuildContext context, WidgetRef ref, String category) {
    // Track food category selection
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('carb_loading_food_category_tapped', properties: {
      'category': category,
    });

    context.push('/carb-loading-food-selection', extra: {'category': category});
  }


  List<MockMeal> _getMockDay1Meals() {
    return [
      MockMeal(
        name: 'Oatmeal with Berries',
        calories: 320,
        carbs: 65,
        quantity: 1,
      ),
      MockMeal(
        name: 'Whole Wheat Toast',
        calories: 280,
        carbs: 55,
        quantity: 2,
      ),
      MockMeal(
        name: 'Banana',
        calories: 105,
        carbs: 27,
        quantity: 2,
      ),
    ];
  }

  List<MockMeal> _getMockDay2Meals() {
    return [
      MockMeal(
        name: 'Grilled Chicken Sandwich',
        calories: 450,
        carbs: 52,
        quantity: 1,
      ),
      MockMeal(
        name: 'Energy Bar',
        calories: 240,
        carbs: 45,
        quantity: 1,
      ),
      MockMeal(
        name: 'Sports Drink',
        calories: 140,
        carbs: 35,
        quantity: 2,
      ),
    ];
  }

  List<MockMeal> _getMockDay3Meals() {
    return [
      MockMeal(
        name: 'Pasta with Tomato Sauce',
        calories: 520,
        carbs: 85,
        quantity: 1,
      ),
      MockMeal(
        name: 'Greek Yogurt',
        calories: 180,
        carbs: 20,
        quantity: 1,
      ),
      MockMeal(
        name: 'Energy Gel',
        calories: 100,
        carbs: 25,
        quantity: 3,
      ),
    ];
  }
}

// Mock data classes
class MockMeal {
  final String name;
  final int calories;
  final int carbs;
  final int quantity;

  MockMeal({
    required this.name,
    required this.calories,
    required this.carbs,
    required this.quantity,
  });
}

// Meal details dialog
class _MealDetailsDialog extends StatelessWidget {
  final MockMeal meal;

  const _MealDetailsDialog({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Food icon
            KyleFoodIcon(
              foodType: KyleFoodType.other,
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Meal name
            Text(
              meal.name,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Nutrition facts
            _buildNutritionFacts(context),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Close button
            KylePrimaryButton(
              text: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionFacts(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Facts',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildNutritionRow(context, 'Calories', '${meal.calories}'),
          _buildNutritionRow(context, 'Carbohydrates', '${meal.carbs}g'),
          _buildNutritionRow(context, 'Protein', '${(meal.calories * 0.15).round()}g'),
          _buildNutritionRow(context, 'Fat', '${(meal.calories * 0.08).round()}g'),
          _buildNutritionRow(context, 'Fiber', '${(meal.carbs * 0.1).round()}g'),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}