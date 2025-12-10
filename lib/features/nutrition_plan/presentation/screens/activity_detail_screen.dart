import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/domain/activity_type.dart';
import '../providers/activity_detail_controller.dart';
import '../../domain/nutrition_plan.dart';

/// Activity Detail Screen - Kyle's Design System
/// Shows activity details with nutrition sections and food items
///
/// SIMPLIFIED: Uses only activityId for provider. Always allows editing
/// regardless of how the user arrived at the screen. This eliminates
/// provider instance mismatches that caused food swap bugs.
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.isNewActivity = false,
  });

  final int activityId; // Activity ID is always required
  final bool isNewActivity; // True if just created (for showing "Save Workout" button)

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  static const String _swipeHintShownKey = 'activity_detail_swipe_hint_shown';
  bool _hasShownSwipeHint = false;
  bool _swipeHintChecked = false;

  @override
  void initState() {
    super.initState();
    _checkSwipeHintShown();
  }

  /// Check SharedPreferences for swipe hint status (only once per app install)
  Future<void> _checkSwipeHintShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasShown = prefs.getBool(_swipeHintShownKey) ?? false;
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = hasShown;
          _swipeHintChecked = true;
        });
      }
    } catch (e) {
      // On error, just don't show the hint
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = true;
          _swipeHintChecked = true;
        });
      }
    }
  }

  /// Mark swipe hint as shown and persist to SharedPreferences
  Future<void> _markSwipeHintShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_swipeHintShownKey, true);
    } catch (e) {
      // Silently fail - hint will just show again next time
    }
  }

  /// Consume swipe hint - returns true only the first time, then persists
  bool _consumeSwipeHint() {
    // Don't show hint until we've checked SharedPreferences
    if (!_swipeHintChecked) return false;
    // Already shown this session or previously
    if (_hasShownSwipeHint) return false;
    // Mark as shown for this session
    _hasShownSwipeHint = true;
    // Persist to SharedPreferences
    _markSwipeHintShown();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // SIMPLIFIED: Only activityId needed for provider
    final activityDetailAsync = ref.watch(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: activityDetailAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Custom back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: AppIconSizes.controlIcon,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            widget.isNewActivity ? 'New Activity' : 'Activity Details',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading activity...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.triangleExclamation,
              size: AppIconSizes.xxl,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Error Loading Activity',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            KyleSecondaryButton(
              text: 'Go Back',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ActivityDetailState state) {
    // Get activity data from state
    final activity = state.activity;

    // If we have no activity, show error
    if (activity == null) {
      return _buildErrorState(context, 'No activity data available');
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Hero image with activity info
          _buildHeroSection(context, state),

          const SizedBox(height: AppSpacing.lg),

          // Nutrition Sections (only show if we have a nutrition plan)
          if (state.nutritionPlan != null)
            _buildNutritionSections(context, state),

          // Show placeholder if no nutrition plan yet
          if (state.nutritionPlan == null)
            _buildNoNutritionPlanState(context),

          const SizedBox(height: AppSpacing.xl),

          // Action Buttons
          _buildActionButtons(context, state),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ActivityDetailState state) {
    final activity = state.activity;

    // Get activity details from activity (always available at this point)
    final activityType = activity?.activityType ?? ActivityType.running;
    final scheduledDateTime = state.scheduledDateTime ?? DateTime.now();

    return Column(
      children: [
        // Hero image with geometric background pattern
        _buildHeroImageWithPattern(context, activityType),

        const SizedBox(height: AppSpacing.lg),

        // Schedule info section
        _buildScheduleInfo(context, scheduledDateTime, activityType),
      ],
    );
  }

  Widget _buildHeroImageWithPattern(BuildContext context, ActivityType activityType) {
    // Get the appropriate image based on activity type
    String imagePath = 'assets/images/Runner.png';
    if (activityType == ActivityType.cycling) {
      imagePath = 'assets/images/Biker.png';
    } else if (activityType == ActivityType.swimming) {
      imagePath = 'assets/images/Swimmer.png';
    }

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blackberry.withValues(alpha: 0.3),
            AppColors.electrolyte.withValues(alpha: 0.2),
            AppColors.dragonfruit.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Geometric pattern background
          CustomPaint(
            size: const Size(double.infinity, 280),
            painter: _GeometricPatternPainter(),
          ),

          // Hero image
          Image.asset(
            imagePath,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                FontAwesomeIcons.personRunning,
                size: 120,
                color: AppColors.cream.withValues(alpha: 0.5),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo(BuildContext context, DateTime scheduledDateTime, ActivityType activityType) {
    // Generate the appropriate label based on activity type
    String activityLabel;
    switch (activityType) {
      case ActivityType.running:
        activityLabel = 'RUN';
        break;
      case ActivityType.cycling:
        activityLabel = 'BIKE';
        break;
      case ActivityType.swimming:
        activityLabel = 'SWIM';
        break;
      default:
        activityLabel = 'ACTIVITY';
    }

    return Column(
      children: [
        Text(
          '$activityLabel SCHEDULED FOR',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Date
            Column(
              children: [
                Text(
                  'DATE',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatDateShort(scheduledDateTime),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppSpacing.xxl),

            // Time
            Column(
              children: [
                Text(
                  'TIME',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatTime(scheduledDateTime),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildNoNutritionPlanState(BuildContext context) {
    return BaseCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(
                FontAwesomeIcons.utensils,
                size: AppIconSizes.xl,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No nutrition plan yet',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Generate a nutrition plan to see recommendations',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionSections(BuildContext context, ActivityDetailState state) {
    final plan = state.nutritionPlan!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plan.sections.map((section) {
        // Map section title to category
        String category = 'before_run';
        Color sectionColor = AppColors.orange;

        if (section.title.contains('During')) {
          category = 'during_run';
          sectionColor = AppColors.electrolyte;
        } else if (section.title.contains('After')) {
          category = 'after_run';
          sectionColor = AppColors.dragonfruit;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _buildNutritionSection(
            context: context,
            state: state,
            title: section.title.toUpperCase(),
            section: section,
            category: category,
            sectionColor: sectionColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNutritionSection({
    required BuildContext context,
    required ActivityDetailState state,
    required String title,
    required PlanSection section,
    required String category,
    required Color sectionColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Macro summary - pass section for targets
          _buildMacroSummaryRow(context, state, section.foodItems, category, section),

          const SizedBox(height: AppSpacing.md),

          // Food items list
          ...section.foodItems.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < section.foodItems.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _buildExpandableFoodItem(
                context,
                state,
                food,
                category,
                showSwipeHint: _consumeSwipeHint(),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.md),

          // Add Food button
          KyleAddFoodButton(
            text: 'ADD FOOD',
            onPressed: () => _addFood(context, category),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSummaryRow(
    BuildContext context,
    ActivityDetailState state,
    List<FoodItemData> foods,
    String category,
    PlanSection section,
  ) {
    // Calculate totals from current food items
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalSodium = 0;
    double totalFluids = 0;

    for (final food in foods) {
      if (food.nutritionalInfo != null) {
        totalCarbs += food.nutritionalInfo!.carbs ?? 0;
        totalProtein += food.nutritionalInfo!.protein ?? 0;
        totalSodium += food.nutritionalInfo!.sodium ?? 0;
        totalFluids += food.nutritionalInfo!.fluids ?? 0;
      }
    }

    // Get target values from the section's stored targets (from nutrition plan)
    // These are the originally calculated targets when the plan was created
    int targetCarbs = section.carbsTarget?.round() ?? totalCarbs;
    int targetProtein = section.proteinTarget?.round() ?? totalProtein;
    int targetSodium = section.sodiumTarget?.round() ?? totalSodium;
    int targetFluids = section.fluidsTarget?.round() ?? totalFluids.round();

    // Note: Section targets are now always stored in the nutrition plan
    // No need for macroTargets fallback

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMacroSummaryItem(
          context: context,
          actual: totalCarbs,
          target: targetCarbs,
          unit: 'g',
          label: 'CARBS',
        ),
        if (category == 'during_run')
          _buildMacroSummaryItem(
            context: context,
            actual: totalFluids.round(),
            target: targetFluids,
            unit: 'mL',
            label: 'FLUIDS',
          )
        else
          _buildMacroSummaryItem(
            context: context,
            actual: totalProtein,
            target: targetProtein,
            unit: 'g',
            label: 'PROTEIN',
          ),
        _buildMacroSummaryItem(
          context: context,
          actual: totalSodium,
          target: targetSodium,
          unit: 'mg',
          label: 'SODIUM',
        ),
      ],
    );
  }

  /// Get color for macro value based on deviation from target
  /// Returns red shades if significantly off from target
  Color _getMacroDeviationColor(BuildContext context, int actual, int target) {
    // If target is 0, can't calculate deviation
    if (target == 0) return Theme.of(context).colorScheme.onSurface;

    // Calculate percentage deviation from target
    final deviation = ((actual - target).abs() / target * 100);

    // > 30% off target: darker red (more visible)
    if (deviation > 30) {
      return AppColors.dragonfruitDark;
    }
    // 15-30% off target: medium red
    else if (deviation > 15) {
      return AppColors.dragonfruit;
    }
    // Within 15% tolerance: normal color
    else {
      return Theme.of(context).colorScheme.onSurface;
    }
  }

  Widget _buildMacroSummaryItem({
    required BuildContext context,
    required int actual,
    required int target,
    required String unit,
    required String label,
  }) {
    // Get color for the actual value based on deviation
    final actualColor = _getMacroDeviationColor(context, actual, target);
    final targetColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        // Display numerator/denominator with colored numerator
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$actual',
                style: AppTextStyles.dataNumber.copyWith(
                  color: actualColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '/',
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '$target',
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: unit,
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableFoodItem(
    BuildContext context,
    ActivityDetailState state,
    FoodItemData food,
    String category,
    {bool showSwipeHint = false}
  ) {
    return Dismissible(
      key: Key(food.id),
      // Swipe right-to-left for swap
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.trash,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      // Swipe left-to-right for delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.electrolyte,
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Swap',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              FontAwesomeIcons.arrowRightArrowLeft,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Delete - show confirmation
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete Food Item'),
              content: Text('Remove ${food.name} from this section?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.dragonfruit),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            // Perform deletion via controller and rely on rebuild to remove widget
            await _deleteFood(context, state, food.id, category);
          }
          return false; // Keep Dismissible in place; rebuild will drop it
        } else if (direction == DismissDirection.endToStart) {
          // Swap - navigate to swap screen, don't dismiss
          _swapFood(context, state, food.id, food.name, category);
          return false; // Don't dismiss the item
        }
        return false;
      },
      child: _ExpandableFoodItem(
        food: food,
        onSwap: () => _swapFood(context, state, food.id, food.name, category),
        onRemove: () => _deleteFood(context, state, food.id, category),
        showSwipeHint: showSwipeHint,
        onQuantityChange: (newQuantity) => _updateFoodQuantity(context, state, food.id, category, newQuantity),
      ),
    );
  }

  Widget _buildCompletedState(BuildContext context, ActivityDetailState state) {
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              FontAwesomeIcons.circleCheck,
              size: AppIconSizes.xl,
              color: AppColors.electrolyte,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Workout Completed',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (state.completion?.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Completed on ${_formatDate(state.completion!.completedAt)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  void _showFoodDetailsDialog(
    BuildContext context,
    ActivityDetailState state,
    FoodItemData food,
    String category,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _FoodDetailsDialog(
        food: food,
        onSwap: () {
          Navigator.of(dialogContext).pop();
          _swapFood(context, state, food.id, food.name, category);
        },
        onDelete: () {
          Navigator.of(dialogContext).pop();
          _deleteFood(context, state, food.id, category);
        },
      ),
    );
  }

  /// Build action buttons based on current state
  Widget _buildActionButtons(BuildContext context, ActivityDetailState state) {
    // If completed, show completion info but still allow editing foods
    if (state.isCompleted) {
      return _buildCompletedState(context, state);
    }

    // New activity: Show "Save Workout" button
    if (state.isNewActivity) {
      return KylePrimaryButton(
        text: state.isSaving ? 'Saving...' : 'Save Workout',
        onPressed: state.isSaving ? null : () => _saveWorkout(context, state),
      );
    }

    // Existing activity (not completed): Show "Save" and "Complete" buttons
    // Always show both buttons so user can enter edit flow even if no detected changes
    return Row(
      children: [
        Expanded(
          child: KyleSecondaryButton(
            text: state.isSaving ? 'Saving...' : 'Save',
            onPressed: state.isSaving ? null : () => _saveWorkout(context, state),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: KylePrimaryButton(
            text: state.isCompleting ? 'Completing...' : 'Complete',
            onPressed: state.isCompleting ? null : () => _completeWorkout(context, state),
          ),
        ),
      ],
    );
  }

  void _saveWorkout(BuildContext context, ActivityDetailState state) async {
    // Call controller to save the activity
    final controller = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );

    await controller.saveActivity();

    // Track analytics
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('workout_saved', properties: {
      'activity_id': state.activity?.id,
      'has_nutrition_plan': state.nutritionPlan != null,
      'is_new_activity': state.isNewActivity,
    });

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved successfully!'),
          backgroundColor: AppColors.electrolyte,
        ),
      );

      // If new activity, navigate to activities list after saving
      // Otherwise stay on screen (user might want to continue editing or complete)
      if (state.isNewActivity) {
        context.go('/main');
      }
    }
  }


  void _completeWorkout(BuildContext context, ActivityDetailState state) {
    // Show completion dialog
    showDialog(
      context: context,
      builder: (dialogContext) => _CompletionDialog(
        onComplete: (rating, notes) async {
          Navigator.of(dialogContext).pop();

          // Call controller to complete the activity
          final controller = ref.read(
            activityDetailControllerProvider(
              activityId: widget.activityId,
              isNewActivity: widget.isNewActivity,
            ).notifier,
          );

          await controller.completeActivity(
            overallSatisfaction: rating,
            textNotes: notes,
          );

          // Track analytics
          final analytics = ref.read(appExternalDepsProvider);
          analytics.analytics.track('workout_completed', properties: {
            'activity_id': state.activity?.id,
            'rating': rating,
            'has_notes': notes?.isNotEmpty ?? false,
          });

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Workout completed successfully!'),
                backgroundColor: AppColors.electrolyte,
              ),
            );
          }
        },
      ),
    );
  }

  void _swapFood(BuildContext context, ActivityDetailState state, String foodId, String foodName, String category) {
    // Track swap food action
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('swap_food_tapped', properties: {
      'food_id': foodId,
      'food_name': foodName,
      'section': category,
    });

    // SIMPLIFIED: Just pass activityId to swap food screen (activityId is always required now)
    context.push('/swap-food', extra: {
      'foodToSwapId': foodId,
      'foodToSwapName': foodName,
      'category': category,
      'activityId': widget.activityId,
      'isNewActivity': widget.isNewActivity,
    });
  }

  Future<void> _deleteFood(BuildContext context, ActivityDetailState state, String foodId, String category) async {
    final controller = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );

    await controller.deleteFoodItem(foodId, category);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food item removed'),
        ),
      );
    }
  }

  Future<void> _updateFoodQuantity(BuildContext context, ActivityDetailState state, String foodId, String category, double newQuantity) async {
    final controller = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );

    await controller.updateFoodQuantity(foodId, category, newQuantity);
  }

  void _addFood(BuildContext context, String category) {
    // Track add food
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('add_food_tapped', properties: {
      'section': category,
    });

    // SIMPLIFIED: Just pass activityId to swap food screen (activityId is always required now)
    context.push('/swap-food', extra: {
      'foodToSwapId': null, // null = add mode
      'foodToSwapName': null,
      'category': category,
      'activityId': widget.activityId,
      'isNewActivity': widget.isNewActivity,
    });
  }

  String _formatDate(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatDateShort(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute$period';
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  KyleActivityType _mapActivityType(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return KyleActivityType.running;
      case ActivityType.cycling:
        return KyleActivityType.cycling;
      case ActivityType.swimming:
        return KyleActivityType.swimming;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        return KyleActivityType.triathlon;
    }
  }

  KyleFoodType _mapFoodType(String foodName) {
    // Simple mapping based on food name
    final name = foodName.toLowerCase();

    if (name.contains('banana') || name.contains('fruit')) {
      return KyleFoodType.fruit;
    } else if (name.contains('bread') || name.contains('sandwich')) {
      return KyleFoodType.sandwich;
    } else if (name.contains('pasta')) {
      return KyleFoodType.pasta;
    } else if (name.contains('rice')) {
      return KyleFoodType.rice;
    } else if (name.contains('gel') || name.contains('gummy')) {
      return KyleFoodType.gel;
    } else if (name.contains('bar') || name.contains('energy')) {
      return KyleFoodType.energyBar;
    } else if (name.contains('drink') || name.contains('water') || name.contains('fluid')) {
      return KyleFoodType.drink;
    } else if (name.contains('protein') || name.contains('meat') || name.contains('chicken')) {
      return KyleFoodType.protein;
    } else if (name.contains('vegetable') || name.contains('carrot') || name.contains('salad')) {
      return KyleFoodType.vegetable;
    } else if (name.contains('snack') || name.contains('cookie') || name.contains('cracker')) {
      return KyleFoodType.snack;
    } else if (name.contains('supplement') || name.contains('pill') || name.contains('vitamin')) {
      return KyleFoodType.supplement;
    } else {
      return KyleFoodType.other;
    }
  }
}

class _CompletionDialog extends StatefulWidget {
  final Function(int rating, String? notes) onComplete;

  const _CompletionDialog({required this.onComplete});

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  int _rating = 3;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.check,
                size: AppIconSizes.xl,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Success message
            Text(
              'Complete Workout',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Rating
            Text(
              'How did it go?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final rating = index + 1;
                return IconButton(
                  icon: Icon(
                    rating <= _rating ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
                    color: AppColors.orange,
                    size: AppIconSizes.md,
                  ),
                  onPressed: () => setState(() => _rating = rating),
                );
              }),
            ),

            const SizedBox(height: AppSpacing.md),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Complete button
            KylePrimaryButton(
              text: 'Complete',
              onPressed: () {
                widget.onComplete(
                  _rating,
                  _notesController.text.isEmpty ? null : _notesController.text,
                );
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            // Cancel button
            KyleTertiaryButton(
              text: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodDetailsDialog extends StatelessWidget {
  final FoodItemData food;
  final VoidCallback onSwap;
  final VoidCallback onDelete;

  const _FoodDetailsDialog({
    required this.food,
    required this.onSwap,
    required this.onDelete,
  });

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
            // Food icon and name
            Row(
              children: [
                KyleFoodIcon(
                  foodType: _mapFoodType(food.name),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: AppTextStyles.subtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        food.quantity,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Nutrition facts
            if (food.nutritionalInfo != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Column(
                  children: [
                    _buildNutritionRow(
                      context,
                      'Calories',
                      '${food.nutritionalInfo!.calories ?? 0} kcal',
                      AppColors.orange,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionRow(
                      context,
                      'Carbohydrates',
                      '${food.nutritionalInfo!.carbs ?? 0}g',
                      AppColors.electrolyte,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionRow(
                      context,
                      'Protein',
                      '${food.nutritionalInfo!.protein ?? 0}g',
                      AppColors.dragonfruit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionRow(
                      context,
                      'Fat',
                      '${food.nutritionalInfo!.fat ?? 0}g',
                      Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: KyleSecondaryButton(
                    text: 'Swap',
                    onPressed: onSwap,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: KyleSecondaryButton(
                    text: 'Remove',
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Close button
            KyleTertiaryButton(
              text: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(BuildContext context, String label, String value, Color color) {
    return Row(
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
          style: AppTextStyles.dataNumber.copyWith(
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  KyleFoodType _mapFoodType(String foodName) {
    final name = foodName.toLowerCase();

    if (name.contains('banana') || name.contains('fruit')) {
      return KyleFoodType.fruit;
    } else if (name.contains('bread') || name.contains('sandwich')) {
      return KyleFoodType.sandwich;
    } else if (name.contains('pasta')) {
      return KyleFoodType.pasta;
    } else if (name.contains('rice')) {
      return KyleFoodType.rice;
    } else if (name.contains('gel') || name.contains('gummy')) {
      return KyleFoodType.gel;
    } else if (name.contains('bar') || name.contains('energy')) {
      return KyleFoodType.energyBar;
    } else if (name.contains('drink') || name.contains('water') || name.contains('fluid')) {
      return KyleFoodType.drink;
    } else if (name.contains('protein') || name.contains('meat') || name.contains('chicken')) {
      return KyleFoodType.protein;
    } else if (name.contains('vegetable') || name.contains('carrot') || name.contains('salad')) {
      return KyleFoodType.vegetable;
    } else if (name.contains('snack') || name.contains('cookie') || name.contains('cracker')) {
      return KyleFoodType.snack;
    } else if (name.contains('supplement') || name.contains('pill') || name.contains('vitamin')) {
      return KyleFoodType.supplement;
    } else {
      return KyleFoodType.other;
    }
  }
}

// Expandable Food Item Widget with Quantity Controls
class _ExpandableFoodItem extends StatefulWidget {
  final FoodItemData food;
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final Function(double)? onQuantityChange;
  final bool showSwipeHint;

  const _ExpandableFoodItem({
    required this.food,
    this.onSwap,
    this.onRemove,
    this.onQuantityChange,
    this.showSwipeHint = false,
  });

  @override
  State<_ExpandableFoodItem> createState() => _ExpandableFoodItemState();
}

class _ExpandableFoodItemState extends State<_ExpandableFoodItem> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late double _quantity;
  late final AnimationController _swipeHintController;
  late final Animation<double> _swipeHintOffset;
  bool _hasPlayedSwipeHint = false;

  @override
  void initState() {
    super.initState();
    // Extract numeric quantity from the quantity string (e.g., "2 banana" -> 2.0)
    // The quantity string format is like "2 banana", "1.5 gel", etc.
    final quantityMatch = RegExp(r'^([\d.]+)').firstMatch(widget.food.quantity);
    _quantity = quantityMatch != null
        ? double.tryParse(quantityMatch.group(1)!) ?? 1.0
        : 1.0;

    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _swipeHintOffset = TweenSequence<double>([
      // Swipe left to show "Delete" button
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -80.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      // Pause on Delete to let user see it
      TweenSequenceItem(
        tween: ConstantTween(-80.0),
        weight: 15,
      ),
      // Swipe right to show "Swap" button
      TweenSequenceItem(
        tween: Tween(begin: -80.0, end: 80.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25,
      ),
      // Pause on Swap to let user see it
      TweenSequenceItem(
        tween: ConstantTween(80.0),
        weight: 15,
      ),
      // Return to center
      TweenSequenceItem(
        tween: Tween(begin: 80.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_swipeHintController);

    if (widget.showSwipeHint) {
      _playSwipeHint();
    }
  }

  @override
  void didUpdateWidget(covariant _ExpandableFoodItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSwipeHint && !_hasPlayedSwipeHint) {
      _playSwipeHint();
    }
  }

  @override
  void dispose() {
    _swipeHintController.dispose();
    super.dispose();
  }

  void _playSwipeHint() {
    if (_hasPlayedSwipeHint) return;
    _hasPlayedSwipeHint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _swipeHintController.forward(from: 0);
      }
    });
  }

  /// Get the appropriate icon for a food based on its name
  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();

    // Map generic foods to specific icons
    if (name.contains('apple') && !name.contains('applesauce')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('applesauce') || name.contains('purée')) {
      return FontAwesomeIcons.bottleDroplet;
    } else if (name.contains('bagel')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('banana')) {
      return FontAwesomeIcons.appleWhole; // Use apple as generic fruit
    } else if (name.contains('berr')) { // matches berry/berries
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('chocolate milk')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coconut water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coffee')) {
      return FontAwesomeIcons.mugHot;
    } else if (name.contains('date')) {
      return FontAwesomeIcons.appleWhole; // Use apple as generic fruit
    } else if (name.contains('electrolyte drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('electrolyte tablet')) {
      return FontAwesomeIcons.pills;
    } else if (name.contains('energy bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('energy chew')) {
      return FontAwesomeIcons.candyCane;
    } else if (name.contains('energy waffle') || name.contains('stroopwafel')) {
      return FontAwesomeIcons.cookie;
    } else if (name.contains('fig bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('gel')) {
      return FontAwesomeIcons.droplet;
    } else if (name.contains('oatmeal')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('orange juice')) {
      return FontAwesomeIcons.glassWater;
    } else if (name.contains('peanut butter')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('pickle juice')) {
      return FontAwesomeIcons.vial;
    } else if (name.contains('pretzel')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('protein bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('protein powder')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('protein shake')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('salt packet')) {
      return FontAwesomeIcons.bagShopping;
    } else if (name.contains('sports drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('sports drink')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('toast')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('trail mix')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('yogurt')) {
      return FontAwesomeIcons.bowlFood;
    }

    // Check if this is a user-imported food
    if (_isUserImportedFood(widget.food)) {
      return FontAwesomeIcons.userPen;
    }

    // Default fallback icon
    return FontAwesomeIcons.utensils;
  }

  /// Determine if a food is user-imported (vs generic system food)
  /// User-imported foods come from barcode scanning or manual entry
  bool _isUserImportedFood(FoodItemData food) {
    // Check if the ID indicates it's from user_foods table
    // User-imported foods typically have UUIDs from user_foods table
    // Generic foods have UUIDs from foods table

    // We can add more sophisticated logic here if needed, such as:
    // - Checking against a list of known generic food IDs
    // - Checking if the food has a barcode (from Open Food Facts)
    // - Using a flag from the repository layer

    // For now, use a simple heuristic: if the food name doesn't match
    // any of the known generic foods, it's likely user-imported
    final name = food.name.toLowerCase();

    final knownGenericFoods = [
      'apple', 'applesauce', 'purée', 'bagel', 'banana', 'berr',
      'chocolate milk', 'coconut water', 'coffee', 'date',
      'electrolyte drink', 'electrolyte tablet', 'energy bar',
      'energy chew', 'energy waffle', 'stroopwafel', 'fig bar',
      'gel', 'oatmeal', 'orange juice', 'peanut butter',
      'pickle juice', 'pretzel', 'protein bar', 'protein powder',
      'protein shake', 'salt packet', 'sports drink', 'toast',
      'trail mix', 'water', 'yogurt',
    ];

    // If none of the generic food keywords are in the name, it's likely user-imported
    return !knownGenericFoods.any((keyword) => name.contains(keyword));
  }

  /// Get the background color for the food icon
  Color _getFoodIconColor() {
    // Use different color for user-imported foods
    if (_isUserImportedFood(widget.food)) {
      return AppColors.orange;
    }
    return AppColors.electrolyte;
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.smRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Main row - always visible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.smRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  // Food icon
                  Container(
                    width: AppIconSizes.foodIcon,
                    height: AppIconSizes.foodIcon,
                    decoration: BoxDecoration(
                      color: _getFoodIconColor(),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getFoodIcon(widget.food.name),
                      size: AppIconSizes.controlIcon,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Food name and quantity
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.food.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.food.quantity,
                          style: AppTextStyles.smallLabel.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chevron icon
                  Icon(
                    _isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                    size: AppIconSizes.controlIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.orange,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Decrease button
                            IconButton(
                              icon: Icon(
                                FontAwesomeIcons.minus,
                                size: AppIconSizes.controlIcon,
                                color: AppColors.orange,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_quantity > 0.5) {
                                    _quantity -= 0.5;
                                    // Call the callback to persist the change
                                    widget.onQuantityChange?.call(_quantity);
                                  }
                                });
                              },
                            ),

                            // Quantity display
                            Text(
                              _quantity.toStringAsFixed(1),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Increase button
                            IconButton(
                              icon: Icon(
                                FontAwesomeIcons.plus,
                                size: AppIconSizes.controlIcon,
                                color: AppColors.orange,
                              ),
                              onPressed: () {
                                setState(() {
                                  _quantity += 0.5;
                                  // Call the callback to persist the change
                                  widget.onQuantityChange?.call(_quantity);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Nutritional Facts
                  Text(
                    'Nutritional Fact',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNutritionItem(
                          context: context,
                          value: '${widget.food.nutritionalInfo?.calories?.toInt() ?? 0}',
                          label: 'CALORIES',
                        ),
                        _buildNutritionItem(
                          context: context,
                          value: '${widget.food.nutritionalInfo?.carbs ?? 0}g',
                          label: 'CARBS',
                        ),
                        _buildNutritionItem(
                          context: context,
                          value: '${widget.food.nutritionalInfo?.protein ?? 0}g',
                          label: 'PROTEIN',
                        ),
                        _buildNutritionItem(
                          context: context,
                          value: '${widget.food.nutritionalInfo?.fat ?? 0}%',
                          label: 'FAT',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Remove food item button
                  if (widget.onRemove != null)
                    InkWell(
                      onTap: widget.onRemove,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.trash,
                            size: AppIconSizes.controlIcon,
                            color: AppColors.dragonfruit,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Remove food item',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.dragonfruit,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!_hasPlayedSwipeHint && !widget.showSwipeHint) {
      return content;
    }

    // Show backgrounds during animation to demonstrate swipe actions
    return AnimatedBuilder(
      animation: _swipeHintOffset,
      builder: (context, child) {
        final offset = _hasPlayedSwipeHint ? _swipeHintOffset.value : 0;

        return ClipRRect(
          borderRadius: AppRadius.smRadius,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Swap background (visible when swiping left - revealed on right side)
              Positioned.fill(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: offset < 0 ? AppColors.electrolyte : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: offset < 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Swap',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              FontAwesomeIcons.arrowRightArrowLeft,
                              color: Colors.white,
                              size: AppIconSizes.md,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Delete background (visible when swiping right - revealed on left side)
              Positioned.fill(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: offset > 0 ? AppColors.dragonfruit : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: offset > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FontAwesomeIcons.trash,
                              color: Colors.white,
                              size: AppIconSizes.md,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Delete',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Animated card on top
              Transform.translate(
                offset: Offset(offset.toDouble(), 0),
                child: child,
              ),
            ],
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildNutritionItem({
    required BuildContext context,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// Geometric Pattern Painter for Hero Section
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blackberry.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw geometric star/polygon pattern similar to Kyle's design
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 120.0;

    // Draw multiple polygons at different sizes
    for (int i = 0; i < 3; i++) {
      final currentRadius = radius + (i * 30);
      final path = Path();
      const sides = 12; // 12-sided polygon for star effect

      for (int j = 0; j <= sides; j++) {
        final angle = (j * 2 * 3.14159) / sides;
        final x = center.dx + currentRadius * cos(angle);
        final y = center.dy + currentRadius * sin(angle);

        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }

    // Draw connecting lines for star effect
    paint.color = AppColors.electrolyte.withValues(alpha: 0.15);
    for (int i = 0; i < 12; i++) {
      final angle = (i * 2 * 3.14159) / 12;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Extension for ActivityType display name
extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.running:
        return 'Running';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.swimming:
        return 'Swimming';
      case ActivityType.triathlon:
        return 'Triathlon';
      case ActivityType.duathlon:
        return 'Duathlon';
      case ActivityType.multisport:
        return 'Multisport';
    }
  }
}
