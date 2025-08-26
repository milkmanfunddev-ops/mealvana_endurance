import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/plan_container.dart';
import '../../../feedback/presentation/widgets/feedback_drawer.dart';
import '../../../feedback/presentation/providers/feedback_provider.dart';
import '../../../feedback/domain/feedback_data.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../providers/nutrition_plan_controller.dart';
import '../../domain/nutrition_plan.dart' as new_model;
import '../../domain/food_item_data.dart';
import '../widgets/macro_targets_expander.dart';

/// Plan Screen - Shows generated nutrition plan matching Alex's design
/// Displays the plan with Before/During/After sections and feedback integration
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen>
    with SingleTickerProviderStateMixin {
  bool _showFeedback = false;
  late AnimationController _feedbackController;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _showFeedbackDrawer() {
    setState(() => _showFeedback = true);
    _feedbackController.forward();
  }

  void _hideFeedbackDrawer() {
    _feedbackController.reverse().then((_) {
      if (mounted) {
        setState(() => _showFeedback = false);
      }
    });
  }

  Future<void> _handleFeedbackSubmission(FeedbackResponse feedback) async {
    try {
      final feedbackNotifier = ref.read(feedbackSubmissionProvider.notifier);
      final success = await feedbackNotifier.submitFeedback(feedback);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Thank you for your feedback!'),
              backgroundColor: AppTheme.primary900,
              duration: const Duration(seconds: 3),
            ),
          );
          _hideFeedbackDrawer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Failed to submit feedback. Please try again.'),
              backgroundColor: AppTheme.highlight600,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $error'),
            backgroundColor: AppTheme.highlight600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(nutritionPlanControllerProvider);
    final feedbackState = ref.watch(feedbackSubmissionProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.of(context).canPop() 
            ? CustomAppBarBackButton(
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'Plan',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        actions: [
          SizedBox(width: 8.w), // Small padding from edge
        ],
      ),
      
      body: Stack(
        children: [
          // Main content
          planState.when(
            data: (plan) {
              if (plan == null) {
                return _buildEmptyState();
              }
              return _buildPlanContent(plan, feedbackState);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => _buildErrorState(error.toString()),
          ),
          
          // Feedback Drawer Overlay
          if (_showFeedback)
            FeedbackDrawer(
              planName: planState.value?.name,
              isVisible: _showFeedback,
              onClose: _hideFeedbackDrawer,
              onSubmitFeedback: _handleFeedbackSubmission,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to main screen to create new plan
          context.push('/main');
        },
        backgroundColor: AppTheme.primary900,
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 24.sp,
        ),
      ),
    );
  }

  Widget _buildPlanContent(dynamic plan, dynamic feedbackState) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Checklist illustration (matching Alex's design - truly full width)
          SizedBox(
            height: 200.h,
            width: double.infinity,
            child: Image.asset(
              'assets/images/checklist.png',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // Macro Targets as separate widget - use actual plan data
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: MacroTargetsExpander(
              macroTargets: _extractMacroTargets(plan),
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // LLM Message blocks (if available)
          if (plan.notes != null && plan.notes!.isNotEmpty) ...[
            ..._buildDietitianMessages(plan.notes!),
            SizedBox(height: 24.h),
          ],
          
          // Plan content (no longer in separate scroll view)
                // Plan Container with nutrition plan
          PlanContainer(
            plan: _createSamplePlanFromOldFormat(plan),
            onFoodItemTap: (foodItemId) {
              // Handle food item tap - expand details
              // Could add navigation to food details or expand inline
            },
          ),
          
          SizedBox(height: 16.h),
          
          SizedBox(height: 32.h),
          
          // Save Button - only show if not yet saved
          if (!feedbackState.lastSubmissionSuccess)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: PrimaryButton(
                text: 'Save',
                onPressed: () {
                  _showFeedbackDrawer();
                },
                width: double.infinity,
              ),
            ),
          
          SizedBox(height: 16.h),
          
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64.sp,
            color: AppTheme.baseGrey,
          ),
          SizedBox(height: 16.h),
          Text(
            'No plan generated yet',
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 18.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Go back and generate your nutrition plan',
            style: AppTheme.noteStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 24.h),
          PrimaryButton(
            text: 'Generate Plan',
            onPressed: () => context.go('/main'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: AppTheme.highlight600,
          ),
          SizedBox(height: 16.h),
          Text(
            'Error loading plan',
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.highlight600,
              fontSize: 18.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: AppTheme.noteStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          PrimaryButton(
            text: 'Try Again',
            onPressed: () => context.go('/main'),
          ),
        ],
      ),
    );
  }

  // Extract macro targets from the plan
  new_model.MacroTargets _extractMacroTargets(dynamic plan) {
    // If we have a real plan with macro targets, use them
    if (plan != null && plan is new_model.NutritionPlan && plan.macroTargets != null) {
      return plan.macroTargets!;
    }
    
    // Fallback to default values if no plan data
    return const new_model.MacroTargets(
      calories: 0,
      carbs: 0,
      protein: 0,
      fat: 0,
      sodiumMin: 0,
      sodiumMax: 0,
      fluidsMin: 0,
      fluidsMax: 0,
      carbsRange: '80-90%',
      proteinRange: '5-15%',
      fatRange: '5-15%',
    );
  }

  // Convert calculated plan to UI display format
  new_model.NutritionPlan _createSamplePlanFromOldFormat(dynamic calculatedPlan) {
    // DEBUG: Check what plan data we received
    print('🎯 PLAN SCREEN DEBUG:');
    print('📊 Received plan: ${calculatedPlan?.runtimeType}');
    print('📊 Plan sections: ${calculatedPlan?.sections?.length ?? 0}');
    if (calculatedPlan?.sections != null && calculatedPlan.sections.isNotEmpty) {
      print('📊 During-run foods: ${calculatedPlan.sections[1].foodItems.length}');
      if (calculatedPlan.sections[1].foodItems.isNotEmpty) {
        print('📊 First during-run food: ${calculatedPlan.sections[1].foodItems[0].name} - ${calculatedPlan.sections[1].foodItems[0].quantity}');
      } else {
        print('📊 No during-run foods for this short run');
      }
    }
    
    // If we have a real plan, use its data; otherwise fall back to sample
    if (calculatedPlan != null && calculatedPlan is new_model.NutritionPlan) {
      print('✅ Using real calculated plan!');
      return calculatedPlan; // It's already the right type!
    }
    
    // Fallback to sample data if no real plan
    return new_model.NutritionPlan(
      id: 'sample-plan-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Your Nutrition Plan',
      totalCalories: 800,
      notes: 'This plan is optimized for your run. Stay hydrated and fuel consistently.',
      macroTargets: const new_model.MacroTargets(
        calories: 800,
        carbs: 180,
        protein: 20,
        fat: 10,
        carbsRange: '85-90%',
        proteinRange: '5-10%',
        fatRange: '5-10%',
      ),
      sections: [
        new_model.PlanSection(
          id: 'before-run',
          title: 'Before Run',
          subtitle: '2-3 hours pre-run',
          timing: '2-3h',
          foodItems: [
            FoodItemData(
              id: 'oatmeal',
              name: 'Oatmeal',
              quantity: '1 cup',
              iconPath: 'assets/images/oatmeal.png',
              description: 'Carb up, buttercup: gentle complex carbs = smooth 2–3-hour energy. Hit \'em 30–60 min pre-run.',
              nutritionalInfo: const NutritionalInfo(
                calories: 150,
                carbs: 30,
                protein: 4,
                fat: 2,
              ),
            ),
            FoodItemData(
              id: 'banana',
              name: 'Banana sliced',
              quantity: '1',
              iconPath: 'assets/images/banana.png',
              description: 'Quick-digesting sugars and potassium for energy.',
              nutritionalInfo: const NutritionalInfo(
                calories: 105,
                carbs: 27,
                protein: 1,
                fat: 0,
              ),
            ),
            FoodItemData(
              id: 'coffee',
              name: 'Coffee',
              quantity: '1 cup',
              iconPath: 'assets/images/coffee.png',
              description: 'Caffeine boost for performance.',
              nutritionalInfo: const NutritionalInfo(
                calories: 5,
                carbs: 0,
                protein: 0,
                fat: 0,
              ),
            ),
            FoodItemData(
              id: 'orange-juice',
              name: 'Orange juice',
              quantity: '1 cup',
              iconPath: 'assets/images/orange_juice.png',
              description: 'Quick carbohydrates and vitamin C.',
              nutritionalInfo: const NutritionalInfo(
                calories: 110,
                carbs: 26,
                protein: 2,
                fat: 0,
              ),
            ),
          ],
        ),
        new_model.PlanSection(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Every 45-60 minutes',
          timing: '45-60min',
          foodItems: [
            FoodItemData(
              id: 'gels',
              name: 'Gels',
              quantity: '4',
              iconPath: 'assets/images/gels.png',
              description: 'Fast-absorbing energy for sustained performance.',
              instructions: 'Take with water every 45-60 minutes.',
              nutritionalInfo: const NutritionalInfo(
                calories: 400,
                carbs: 100,
                protein: 0,
                fat: 0,
              ),
            ),
            FoodItemData(
              id: 'sports-drink',
              name: 'Sport drinks',
              quantity: '4 cups',
              iconPath: 'assets/images/sports_drink.png',
              description: 'Hydration with electrolytes and carbohydrates.',
              instructions: 'Sip regularly throughout your run.',
              nutritionalInfo: const NutritionalInfo(
                calories: 200,
                carbs: 50,
                protein: 0,
                fat: 0,
                sodium: 400,
              ),
            ),
          ],
        ),
        new_model.PlanSection(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Within 30 minutes',
          timing: '30min',
          foodItems: [
            FoodItemData(
              id: 'protein-bar',
              name: 'Protein bar',
              quantity: '1',
              iconPath: 'assets/images/protein_bar.png',
              description: 'Protein and carbs for recovery.',
              nutritionalInfo: const NutritionalInfo(
                calories: 200,
                carbs: 20,
                protein: 10,
                fat: 8,
              ),
            ),
            FoodItemData(
              id: 'coconut-water',
              name: 'Coconut water',
              quantity: '2 cups',
              iconPath: 'assets/images/coconut_water.png',
              description: 'Natural electrolytes for rehydration.',
              nutritionalInfo: const NutritionalInfo(
                calories: 90,
                carbs: 18,
                protein: 2,
                fat: 0,
                sodium: 120,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildDietitianMessages(String notes) {
    // Now we only have the detailed message (no more overview)
    final detailedMessage = notes.trim();
    
    return [
      // Only detailed message (expandable)
      if (detailedMessage.isNotEmpty)
        _buildMessageCard(
          title: 'Detailed Guidance',
          subtitle: 'Tap to read more',
          message: detailedMessage,
          isExpandable: true,
        ),
    ];
  }

  Widget _buildMessageCard({
    required String title,
    required String subtitle,
    required String message,
    required bool isExpandable,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: isExpandable
          ? _ExpandableMessageCard(
              title: title,
              subtitle: subtitle,
              message: message,
            )
          : Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppTheme.primary900, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary900.withValues(alpha: 0.1),
                    blurRadius: 8.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primary900.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology,
                          color: AppTheme.primary900,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTheme.titleStyle.copyWith(
                                color: AppTheme.primary900,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: AppTheme.noteStyle.copyWith(
                                color: AppTheme.primary900.withValues(alpha: 0.8),
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: AppTheme.primary900.withValues(alpha: 0.2),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    message,
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 14.sp,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ExpandableMessageCard extends StatefulWidget {
  const _ExpandableMessageCard({
    required this.title,
    required this.subtitle,
    required this.message,
  });

  final String title;
  final String subtitle;
  final String message;

  @override
  State<_ExpandableMessageCard> createState() => _ExpandableMessageCardState();
}

class _ExpandableMessageCardState extends State<_ExpandableMessageCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.primary900, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary900.withValues(alpha: 0.1),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          children: [
            // Header (always visible)
            InkWell(
              onTap: _toggleExpansion,
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppTheme.primary900.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: AppTheme.primary900,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppTheme.titleStyle.copyWith(
                              color: AppTheme.primary900,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: AppTheme.noteStyle.copyWith(
                              color: AppTheme.primary900.withValues(alpha: 0.8),
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppTheme.primary900,
                        size: 24.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable detailed content
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Container(
                width: double.infinity,
                color: AppTheme.primary50.withValues(alpha: 0.3),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: AppTheme.primary900.withValues(alpha: 0.2),
                        margin: EdgeInsets.only(bottom: 16.h),
                      ),
                      ...widget.message.split('\n\n').map((paragraph) {
                        if (paragraph.trim().isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Text(
                            paragraph.trim(),
                            style: AppTheme.textStyle.copyWith(
                              color: AppTheme.baseBlack,
                              fontSize: 14.sp,
                              height: 1.5,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}