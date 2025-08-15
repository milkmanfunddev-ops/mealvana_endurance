import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/food_item_data.dart';
import '../widgets/plan_container.dart';
import '../../../../shared/widgets/hero_image.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Demo screen showing the new UI components with sample data
/// This demonstrates how the redesigned components work together
class SamplePlanDemo extends StatefulWidget {
  const SamplePlanDemo({super.key});

  @override
  State<SamplePlanDemo> createState() => _SamplePlanDemoState();
}

class _SamplePlanDemoState extends State<SamplePlanDemo> {
  bool _showFeedbackDrawer = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        title: Text(
          'New UI Demo',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 20.sp,
          ),
        ),
        backgroundColor: AppTheme.baseWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 16.h),
            
            // Hero Image Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: LargeHeroImage(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hero image tapped!')),
                  );
                },
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // Welcome Text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  Text(
                    'Your Personalized Plan',
                    style: AppTheme.titleStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 24.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Based on your 10-mile run at 8:30 pace',
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 16.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // Plan Container with Sample Data
            PlanContainer(
              plan: _createSamplePlan(),
              onFoodItemTap: (foodItemId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tapped food item: $foodItemId')),
                );
              },
            ),
            
            SizedBox(height: 24.h),
            
            // Action Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  PrimaryButton(
                    text: 'Generate New Plan',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generating new plan...')),
                      );
                    },
                    width: double.infinity,
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showFeedbackDrawer = true;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary600,
                      side: BorderSide(color: AppTheme.primary600),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Give Feedback',
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 40.h),
          ],
        ),
      ),
      
      // Feedback Drawer as Overlay  
      floatingActionButton: _showFeedbackDrawer
          ? FloatingActionButton(
              onPressed: () => setState(() => _showFeedbackDrawer = false),
              child: const Icon(Icons.close),
            )
          : null,
    );
  }

  NutritionPlan _createSamplePlan() {
    return NutritionPlan(
      id: 'sample-plan',
      name: 'Long Run Nutrition Plan',
      totalCalories: 800,
      notes: 'This plan is optimized for your 10-mile training run. Remember to hydrate well before, during, and after your run.',
      macroTargets: const MacroTargets(
        calories: 800,
        carbs: 180,
        protein: 20,
        fat: 10,
        carbsRange: '85-90%',
        proteinRange: '5-10%',
        fatRange: '5-10%',
      ),
      sections: [
        PlanSection(
          id: 'before-run',
          title: 'Before Run',
          subtitle: '2-3 hours pre-run',
          timing: '2-3h',
          foodItems: [
            FoodItemData(
              id: 'oatmeal',
              name: 'Oatmeal with Banana',
              quantity: '1 cup + 1 banana',
              iconPath: 'assets/images/foods/oatmeal.png',
              description: 'Complex carbohydrates provide sustained energy for your long run. The banana adds quick-digesting sugars and potassium.',
              instructions: 'Cook oatmeal with water or low-fat milk. Slice banana on top.',
              nutritionalInfo: const NutritionalInfo(
                calories: 350,
                carbs: 70,
                protein: 8,
                fat: 4,
                sodium: 150,
              ),
            ),
            FoodItemData(
              id: 'coffee',
              name: 'Coffee',
              quantity: '8 oz',
              iconPath: 'assets/images/foods/coffee.png',
              description: 'Caffeine can improve performance and reduce perceived effort during endurance exercise.',
              instructions: 'Drink 30-60 minutes before run. Avoid if sensitive to caffeine.',
              nutritionalInfo: const NutritionalInfo(
                calories: 5,
                carbs: 0,
                protein: 0,
                fat: 0,
                sodium: 5,
              ),
            ),
          ],
        ),
        PlanSection(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Every 45-60 minutes',
          timing: '45-60min',
          foodItems: [
            FoodItemData(
              id: 'energy-gel',
              name: 'Energy Gel',
              quantity: '1 packet',
              iconPath: 'assets/images/foods/energy_gel.png',
              description: 'Fast-absorbing carbohydrates to maintain blood sugar and energy levels during your run.',
              instructions: 'Take with 4-6 oz water. Start fueling before you feel tired.',
              nutritionalInfo: const NutritionalInfo(
                calories: 100,
                carbs: 25,
                protein: 0,
                fat: 0,
                sodium: 50,
              ),
            ),
            FoodItemData(
              id: 'sports-drink',
              name: 'Sports Drink',
              quantity: '16-20 oz',
              iconPath: 'assets/images/foods/sports_drink.png',
              description: 'Provides carbohydrates and electrolytes to replace what you lose through sweat.',
              instructions: 'Sip regularly throughout run. Aim for 6-8 oz every 15-20 minutes.',
              nutritionalInfo: const NutritionalInfo(
                calories: 80,
                carbs: 20,
                protein: 0,
                fat: 0,
                sodium: 160,
              ),
            ),
          ],
        ),
        PlanSection(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Within 30 minutes',
          timing: '30min',
          foodItems: [
            FoodItemData(
              id: 'chocolate-milk',
              name: 'Chocolate Milk',
              quantity: '12 oz',
              iconPath: 'assets/images/foods/chocolate_milk.png',
              description: 'Ideal 3:1 carb to protein ratio for recovery. Helps replenish glycogen and repair muscles.',
              instructions: 'Drink immediately after run while muscles are most receptive to nutrients.',
              nutritionalInfo: const NutritionalInfo(
                calories: 190,
                carbs: 26,
                protein: 8,
                fat: 5,
                sodium: 150,
              ),
            ),
            FoodItemData(
              id: 'banana',
              name: 'Banana',
              quantity: '1 medium',
              iconPath: 'assets/images/foods/banana.png',
              description: 'Quick carbohydrates and potassium to help with muscle recovery and prevent cramping.',
              instructions: 'Eat within 30 minutes post-run for optimal recovery.',
              nutritionalInfo: const NutritionalInfo(
                calories: 105,
                carbs: 27,
                protein: 1,
                fat: 0,
                sodium: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}