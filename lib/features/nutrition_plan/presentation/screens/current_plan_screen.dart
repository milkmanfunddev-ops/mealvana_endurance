import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/plan_container.dart';
import '../../../feedback/presentation/widgets/feedback_drawer.dart';
import '../../../feedback/presentation/providers/feedback_provider.dart';
import '../../../feedback/domain/feedback_data.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/mixins/analytics_mixin.dart';
import '../../../../shared/services/analytics_service.dart';
import '../providers/nutrition_plan_controller.dart';
import '../widgets/macro_targets_widget.dart';
import '../../domain/macro_targets.dart' as targets_model;
import '../../domain/nutrition_plan.dart';

/// Plan Screen - Shows generated nutrition plan matching Alex's design
/// Displays the plan with Before/During/After sections and feedback integration
class CurrentPlanScreen extends ConsumerStatefulWidget {
  const CurrentPlanScreen({super.key});

  @override
  ConsumerState<CurrentPlanScreen> createState() => _CurrentPlanScreenState();
}

class _CurrentPlanScreenState extends ConsumerState<CurrentPlanScreen>
    with SingleTickerProviderStateMixin, AnalyticsMixin {
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


  void _hideFeedbackDrawer() {
    _feedbackController.reverse().then((_) {
      if (mounted) {
        setState(() => _showFeedback = false);
      }
    });
  }

  /// Handle save button press - show survey or go to main screen
  Future<void> _handleSavePlan() async {
    final feedbackService = ref.read(feedbackServiceProvider);
    
    // Get device ID to check survey eligibility
    final user = await ref.read(appDatabaseProvider).getCurrentUserProfile();
    final deviceId = user?.id ?? 'anonymous';
    
    // Check if user should be shown the survey
    final shouldShowSurvey = await feedbackService.shouldShowSurvey(deviceId);
    
    if (shouldShowSurvey) {
      // Get plan name for survey context
      final planState = ref.read(nutritionPlanControllerProvider);
      final planName = planState.when(
        data: (planData) => planData.plan != null ? 'Nutrition Plan' : null,
        loading: () => null,
        error: (_, __) => null,
      );
      
      // Navigate to survey with plan name
      if (mounted) {
        context.push('/survey', extra: {'planName': planName});
      }
    } else {
      // User has completed survey recently, go directly to main screen
      if (mounted) {
        context.go('/main');
      }
    }
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
          // Navigate to main tabs screen after successful save
          context.go('/main');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '❌ Failed to submit feedback. Please try again.',
              ),
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

  /// Show date/time picker and update the plan
  Future<void> _showDateTimePicker(NutritionPlan plan) async {
    final now = DateTime.now();
    final nextSaturday = _getNextSaturday();
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: plan.runDateTime ?? nextSaturday,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    
    if (selectedDate == null) return;
    
    if (!mounted) return;
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        plan.runDateTime ?? DateTime(nextSaturday.year, nextSaturday.month, nextSaturday.day, 8, 0)
      ),
    );
    
    if (selectedTime == null) return;
    
    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month, 
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    
    // Update the plan's run date/time via the controller
    await ref
        .read(nutritionPlanControllerProvider.notifier)
        .updateRunDateTime(plan.id, selectedDateTime);
  }

  /// Get next Saturday as default date
  DateTime _getNextSaturday() {
    final now = DateTime.now();
    final daysUntilSaturday = 6 - now.weekday;
    final nextSaturday = now.add(Duration(days: daysUntilSaturday == -1 ? 6 : daysUntilSaturday));
    return DateTime(nextSaturday.year, nextSaturday.month, nextSaturday.day, 8, 0);
  }

  /// Format date/time for display
  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('EEEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(nutritionPlanControllerProvider);
    final feedbackState = ref.watch(feedbackSubmissionProvider);

    // Check if we should show the back button
    final currentRoute = GoRouterState.of(context).uri.toString();
    final shouldShowBackButton =
        Navigator.of(context).canPop() && currentRoute != '/plan';

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: shouldShowBackButton
            ? CustomAppBarBackButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                  } else {
                    context.go('/main');
                  }
                },
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
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(
        children: [
          planState.when(
            data: (planData) {
              if (planData.plan == null) {
                return _buildEmptyState();
              }
              return _buildPlanContent(planData.plan!, feedbackState);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error.toString()),
          ),
          if (_showFeedback)
            FeedbackDrawer(
              planName: planState.valueOrNull?.plan?.name,
              isVisible: _showFeedback,
              onClose: _hideFeedbackDrawer,
              onSubmitFeedback: _handleFeedbackSubmission,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "nutrition-plan-fab",
        onPressed: () {
          context.push('/distancepacegut');
        },
        backgroundColor: AppTheme.primary900,
        child: Icon(Icons.add, color: Colors.white, size: 24.sp),
      ),
    );
  }

  Widget _buildPlanContent(NutritionPlan plan, dynamic feedbackState) {
    final planState = ref.watch(nutritionPlanControllerProvider).valueOrNull;
    final isSaved = planState?.isSaved ?? true;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Checklist illustration
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

          // Workout Reference Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: FutureBuilder<targets_model.MacroTargets?>(
              future: ref
                  .read(nutritionPlanControllerProvider.notifier)
                  .getCachedMacroTargets(),
              builder: (context, targetSnapshot) {
                if (targetSnapshot.hasData && targetSnapshot.data != null) {
                  final targets = targetSnapshot.data!;
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(8.w, 0.h, 16.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_run,
                              color: AppTheme.primary600,
                              size: 20.sp,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Text(
                                '${targets.metrics.distanceMi.toStringAsFixed(1)} miles at ${targets.metrics.formattedPace} pace',
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.primary900,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Run Date/Time Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(8.w, 0.h, 16.w, 12.h),
              child: InkWell(
                onTap: () => _showDateTimePicker(plan),
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.primary600,
                        size: 20.sp,
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Text(
                          plan.runDateTime != null
                              ? 'Run scheduled for ${_formatDateTime(plan.runDateTime!)}'
                              : 'Schedule your run',
                          style: AppTheme.textStyle.copyWith(
                            color: plan.runDateTime != null 
                                ? AppTheme.primary900 
                                : AppTheme.baseGrey,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.edit,
                        color: AppTheme.baseGrey,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Macro Targets with completion bars
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 0.w),
            child: FutureBuilder<targets_model.MacroTargets?>(
              future: ref
                  .read(nutritionPlanControllerProvider.notifier)
                  .getCachedMacroTargets(),
              builder: (context, snapshot) {
                final targets = snapshot.data;

                // Track targets_viewed event when targets are loaded and displayed
                if (targets != null && snapshot.connectionState == ConnectionState.done) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _trackTargetsViewed(plan, targets);
                  });
                }

                return MacroTargetsWidget(plan: plan, targets: targets);
              },
            ),
          ),

          SizedBox(height: 24.h),

          // Plan Container with nutrition plan
          FutureBuilder<targets_model.MacroTargets?>(
            future: ref
                .read(nutritionPlanControllerProvider.notifier)
                .getCachedMacroTargets(),
            builder: (context, snapshot) {
              final macroTargets = snapshot.data;

              return PlanContainer(
                plan: plan,
                macroTargets: macroTargets,
                onFoodItemTap: (foodItemId) {
                  // Handle food item tap - expand details
                },
                onSwapFood: (foodItemId, foodName, category) {
                  context.push(
                    '/swap-food',
                    extra: {
                      'foodToSwapId': foodItemId,
                      'foodToSwapName': foodName,
                      'category': category,
                    },
                  );
                },
            onDeleteFood: (foodItemId, category) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Food Item'),
                  content: Text(
                    'Are you sure you want to remove this item from your plan?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppTheme.highlight600),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref
                    .read(nutritionPlanControllerProvider.notifier)
                    .deleteFoodItem(foodItemId, category);
              }
            },
            onUpdateQuantity: (foodItemId, category, newQuantity) async {
              await ref
                  .read(nutritionPlanControllerProvider.notifier)
                  .updateFoodQuantity(foodItemId, category, newQuantity);
            },
              );
            },
          ),

          SizedBox(height: 16.h),

          // Save Button - only show if plan is not yet saved
          if (!isSaved)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: PrimaryButton(
                text: 'Save',
                onPressed: () async {
                  final success = await ref.read(nutritionPlanControllerProvider.notifier).savePlan();
                  if (success) {
                    _handleSavePlan();
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Failed to save plan. Please try again.'),
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                    }
                  }
                },
                width: double.infinity,
              ),
            ),

          SizedBox(height: 120.h), // Bottom padding for FAB
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.primary50.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 64.sp,
                color: AppTheme.primary600,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Nutrition Plan Yet',
              style: AppTheme.heading2Style.copyWith(
                color: AppTheme.primary900,
                fontSize: 24.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Create a personalized nutrition plan\nfor your next run',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 16.sp,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            PrimaryButton(
              text: 'Create Your First Plan',
              onPressed: () {
                context.push('/distancepacegut');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: AppTheme.highlight600),
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

  /// Track targets_viewed event when macro targets card is displayed
  void _trackTargetsViewed(NutritionPlan? plan, targets_model.MacroTargets targets) {
    // Call the analytics service method for targets_viewed
    AnalyticsService.trackTargetsViewed(
      planId: plan?.id ?? 'unknown',
      screen: 'plan_screen',
      experimentVariant: 'auto_items_v1', // Default variant
      carbsPreG: targets.preRun.carbsG,
      carbsDuringG: targets.duringRun.carbTotalG,
      carbsPostG: targets.postRun.carbsG,
      proteinPreG: targets.preRun.proteinG,
      proteinPostG: targets.postRun.proteinG,
      fluidsPreMl: targets.preRun.fluidsMl,
      fluidsDuringMl: targets.duringRun.fluidTotalMl,
      fluidsPostMl: targets.postRun.fluidsMl,
      sodiumPreMg: targets.preRun.sodiumMg,
      sodiumDuringMg: targets.duringRun.sodiumTotalMg,
      sodiumPostMg: targets.postRun.sodiumMg,
    );
  }
}