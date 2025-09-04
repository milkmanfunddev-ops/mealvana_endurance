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
import '../widgets/macro_targets_widget.dart';
import '../../domain/macro_targets.dart' as targets_model;

/// Plan Screen - Shows generated nutrition plan matching Alex's design
/// Displays the plan with Before/During/After sections and feedback integration
class CurrentPlanScreen extends ConsumerStatefulWidget {
  const CurrentPlanScreen({super.key});

  @override
  ConsumerState<CurrentPlanScreen> createState() => _CurrentPlanScreenState();
}

class _CurrentPlanScreenState extends ConsumerState<CurrentPlanScreen>
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

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(nutritionPlanControllerProvider);
    final feedbackState = ref.watch(feedbackSubmissionProvider);

    // Check if we should show the back button
    // Show back button when accessed from adjust macros ('/current-plan')
    // Hide back button when accessed from main tabs ('/plan')
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
                    // Fallback to main screen if nothing to pop
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
            loading: () => const Center(child: CircularProgressIndicator()),
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
          context.push('/distancepacegut');
        },
        backgroundColor: AppTheme.primary900,
        child: Icon(Icons.add, color: Colors.white, size: 24.sp),
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
                    // margin: EdgeInsets.only(bottom: 16.h),
                    // decoration: BoxDecoration(
                    //   color: AppTheme.primary50.withValues(alpha: 0.6),
                    //   borderRadius: BorderRadius.circular(12.r),
                    //   border: Border.all(color: AppTheme.primary600, width: 1),
                    // ),
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

          // Macro Targets with completion bars
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: FutureBuilder<targets_model.MacroTargets?>(
              future: ref
                  .read(nutritionPlanControllerProvider.notifier)
                  .getCachedMacroTargets(),
              builder: (context, snapshot) {
                return MacroTargetsWidget(plan: plan, targets: snapshot.data);
              },
            ),
          ),

          SizedBox(height: 24.h),

          // LLM Message blocks (if available)
          // if (plan.notes != null && plan.notes!.isNotEmpty) ...[
          //   ..._buildDietitianMessages(plan.notes!),
          //   SizedBox(height: 24.h),
          // ],

          // Plan content (no longer in separate scroll view)
          // Plan Container with nutrition plan
          PlanContainer(
            plan: plan,
            onFoodItemTap: (foodItemId) {
              // Handle food item tap - expand details
              // Could add navigation to food details or expand inline
            },
            onSwapFood: (foodItemId, foodName, category) {
              // Navigate to swap screen
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
              // Show confirmation dialog
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
              // Update the quantity of the food item
              await ref
                  .read(nutritionPlanControllerProvider.notifier)
                  .updateFoodQuantity(foodItemId, category, newQuantity);
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
                // Navigate to the distance/pace input screen
                context.push('/distancepacegut');
                // showModalBottomSheet(
                //   context: context,
                //   isScrollControlled: true,
                //   backgroundColor: Colors.transparent,
                //   builder: (context) => Container(
                //     height: MediaQuery.of(context).size.height * 0.9,
                //     decoration: BoxDecoration(
                //       color: AppTheme.baseCream,
                //       borderRadius: BorderRadius.vertical(
                //         top: Radius.circular(20.r),
                //       ),
                //     ),
                //     child: const DistancePaceGutEntryScreen(),
                //   ),
                // );
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
                                color: AppTheme.primary900.withValues(
                                  alpha: 0.8,
                                ),
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
                        if (paragraph.trim().isEmpty)
                          return const SizedBox.shrink();
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
