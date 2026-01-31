import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/activity_detail/completion_dialog.dart';
import '../widgets/activity_detail/brick_completion_dialog.dart';
import '../widgets/activity_detail/macro_summary_row.dart';
import '../widgets/activity_detail/dismissible_food_item.dart';
import '../widgets/activity_detail/single_sport_hero_image.dart';
import '../widgets/activity_detail/activity_schedule_info.dart';
import '../widgets/activity_detail/activity_completed_badge.dart';
import '../widgets/activity_detail/brick_header.dart';
import '../widgets/activity_detail/brick_nutrition_sections.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/activity_detail_controller.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/run_parameters.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../../activities/domain/activity.dart';
import '../../../coach_mode/presentation/widgets/activity_coach_feedback_widget.dart';
import '../../../coach_mode/presentation/providers/coach_activity_detail_controller.dart';
import '../providers/activity_detail_state.dart';
import '../../../integrations/presentation/widgets/sync_status_widget.dart';
import '../widgets/stale_plan_warning.dart';
import '../widgets/low_fuel_risk_badge.dart';

/// Activity Detail Screen - Refactored with extracted widgets
/// Shows activity details with nutrition sections and food items
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.isNewActivity = false,
    this.isCoachView = false,
  });

  final String activityId;
  final bool isNewActivity;
  final bool isCoachView;

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  bool _hasShownSwipeHint = false;
  bool _swipeHintChecked = false;

  @override
  void initState() {
    super.initState();
    _checkSwipeHintShown();
  }

  void _checkSwipeHintShown() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final controller = _getControllerNotifier();
      final hasShown = controller.checkSwipeHintShown(prefs);
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = hasShown;
          _swipeHintChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = true;
          _swipeHintChecked = true;
        });
      }
    }
  }

  bool _consumeSwipeHint() {
    if (!_swipeHintChecked) return false;
    if (_hasShownSwipeHint) return false;
    _hasShownSwipeHint = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final controller = _getControllerNotifier();
      controller.markSwipeHintShown(prefs);
    } catch (e) {
      // Silently fail
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<dynamic> activityDetailAsync = widget.isCoachView
        ? ref.watch(coachActivityDetailControllerProvider(widget.activityId))
        : ref.watch(
            activityDetailControllerProvider(
              activityId: widget.activityId,
              isNewActivity: widget.isNewActivity,
            ),
          );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: activityDetailAsync.when(
                data: (data) {
                  final ActivityDetailState state;
                  if (data is ActivityDetailState) {
                    state = data;
                  } else {
                    final dynamic d = data;
                    state = ActivityDetailState(
                      activity: d.activity,
                      nutritionPlan: d.nutritionPlan,
                      completion: d.completion,
                      scheduledDateTime: d.scheduledDateTime,
                      isSaving: d.isSaving ?? false,
                      isCompleting: d.isCompleting ?? false,
                      hasUnsavedChanges: d.hasUnsavedChanges ?? false,
                      error: d.error,
                    );
                  }
                  return _buildContent(context, state);
                },
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
      actions: [
        // Only show delete button for existing activities (not new ones, not coach view)
        if (!widget.isNewActivity && !widget.isCoachView)
          IconButton(
            icon: Icon(
              FontAwesomeIcons.trash,
              size: AppIconSizes.md,
              color: AppColors.dragonfruit,
            ),
            onPressed: () => _showDeleteConfirmationDialog(context),
            tooltip: 'Delete Activity',
          ),
        const SizedBox(width: AppSpacing.sm),
      ],
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
    final activity = state.activity;
    if (activity == null) {
      return _buildErrorState(context, 'No activity data available');
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          _buildHeroSection(context, state),
          const SizedBox(height: AppSpacing.lg),

          // Stale plan warning (shown when needsNutritionRefresh is true)
          if (activity.needsNutritionRefresh == true) ...[
            StalePlanWarning(
              onRegeneratePlan: () => _handleRegeneratePlan(context, state),
              isRegenerating: state.isSaving, // Use existing saving state to prevent double operations
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Low fuel risk badge (shown when carbs are 33%+ below target)
          if (state.nutritionPlan != null)
            LowFuelRiskBadge(nutritionPlan: state.nutritionPlan!),

          if (state.nutritionPlan != null)
            _buildNutritionSections(context, state),
          if (state.nutritionPlan == null)
            _buildNoNutritionPlanState(context, state),
          const SizedBox(height: AppSpacing.md),
          // Collapsible coach feedback section
          ActivityCoachFeedbackWidget(
            activityId: widget.activityId,
            isCoachView: widget.isCoachView,
            activityUserId: activity.userId,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildActionButtons(context, state),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ActivityDetailState state) {
    final activity = state.activity;
    final activityType = activity?.activityType ?? ActivityType.running;
    final scheduledDateTime = state.scheduledDateTime ?? DateTime.now();

    // Check if this is a brick workout
    if (activity != null && activity.isBrick && activity.brickMetadata != null) {
      return BrickHeader(
        brick: activity,
        metadata: activity.brickMetadata!,
      );
    }

    // Standard single-sport header
    return Column(
      children: [
        SingleSportHeroImage(activityType: activityType),
        const SizedBox(height: AppSpacing.lg),
        ActivityScheduleInfo(
          scheduledDateTime: scheduledDateTime,
          activityType: activityType,
        ),

        // Sync status widget (only for synced activities)
        if (activity != null && activity.syncedFromProvider != null) ...[
          const SizedBox(height: AppSpacing.md),
          SyncStatusWidget(
            lastSyncAt: activity.lastSyncedAt,
            isSyncedActivity: activity.syncedFromProvider != null,
            isLoading: false,
            onRefresh: () => _handleRefreshActivity(context, state),
          ),
        ],
      ],
    );
  }

  Widget _buildNoNutritionPlanState(BuildContext context, ActivityDetailState state) {
    final activity = state.activity;

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
              const SizedBox(height: AppSpacing.lg),
              // Generate Plan Button
              KylePrimaryButton(
                onPressed: () => _navigateToGeneratePlan(context, activity),
                text: 'Generate Plan',
                icon: FontAwesomeIcons.wandMagicSparkles,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to NewActivityScreen with activity details pre-filled
  void _navigateToGeneratePlan(BuildContext context, Activity? activity) {
    if (activity == null) return;

    context.pushNamed(
      'distance-pace-gut-entry',
      extra: {
        'initialDate': activity.scheduledDateTime,
        'distance': activity.distanceMiles,
        'pace': activity.paceTargetMinutesPerMile,
        'duration': activity.durationMinutes,
        'activityId': activity.id,
      },
    );
  }

  Widget _buildNutritionSections(BuildContext context, ActivityDetailState state) {
    final plan = state.nutritionPlan!;
    final activity = state.activity;

    // Check if this is a brick workout
    if (activity != null && activity.isBrick && activity.brickMetadata != null) {
      return BrickNutritionSections(
        brick: activity,
        planData: plan,
        useImperial: ref.watch(settingsControllerProvider).value?.preferredDistanceUnit == DistanceUnit.miles,
        onAddFood: (category) => _addFood(context, category),
        onSwapFood: (foodId, foodName, category) => _swapFood(context, state, foodId, foodName, category),
        onDeleteFood: (foodId, category) => _deleteFood(context, state, foodId, category),
        onUpdateQuantity: (foodId, category, newQuantity) => _updateFoodQuantity(context, state, foodId, category, newQuantity),
        showSwipeHint: _consumeSwipeHint(),
      );
    }

    // Get activity type for sport-specific section titles (e.g., "Before Swim", "During Ride")
    final activityType = state.activity?.activityType ?? ActivityType.running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plan.sections.map((section) {
        // Determine category from section.id (preferred) or fallback to parsing title
        String category;
        Color sectionColor;

        if (section.id.contains('during')) {
          category = 'during_run';
          sectionColor = AppColors.electrolyte;
        } else if (section.id.contains('after')) {
          category = 'after_run';
          sectionColor = AppColors.dragonfruit;
        } else {
          category = 'before_run';
          sectionColor = AppColors.orange;
        }

        // Generate sport-specific title using ActivityType
        final sectionTitle = activityType.getSectionTitle(category);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _buildNutritionSection(
            context: context,
            state: state,
            title: sectionTitle.toUpperCase(),
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
    // Check unit preference
    final settings = ref.watch(settingsControllerProvider).value;
    final useImperial = settings?.preferredDistanceUnit == DistanceUnit.miles;

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
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MacroSummaryRow(
            foods: section.foodItems,
            section: section,
            category: category,
            useImperial: useImperial,
          ),
          const SizedBox(height: AppSpacing.md),
          ...section.foodItems.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < section.foodItems.length - 1 ? AppSpacing.sm : 0,
              ),
              child: DismissibleFoodItem(
                food: food,
                category: category,
                onSwap: () => _swapFood(context, state, food.id, food.name, category),
                onDelete: () => _deleteFood(context, state, food.id, category),
                onQuantityChange: (newQuantity) => _updateFoodQuantity(context, state, food.id, category, newQuantity),
                showSwipeHint: _consumeSwipeHint(),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          KyleAddFoodButton(
            text: 'ADD FOOD',
            onPressed: () => _addFood(context, category),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ActivityDetailState state) {
    if (state.isCompleted) {
      return ActivityCompletedBadge(completion: state.completion);
    }

    // Coach view: Only show Save button (for saving feedback/notes)
    if (widget.isCoachView) {
      return KylePrimaryButton(
        text: state.isSaving ? 'Saving...' : 'Save',
        onPressed: state.isSaving ? null : () => _saveWorkout(context, state),
      );
    }

    if (state.isNewActivity) {
      return KylePrimaryButton(
        text: state.isSaving ? 'Saving...' : 'Save Workout',
        onPressed: state.isSaving ? null : () => _saveWorkout(context, state),
      );
    }

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

  // Helper to get the correct controller notifier based on view mode
  dynamic _getControllerNotifier() {
    if (widget.isCoachView) {
      return ref.read(coachActivityDetailControllerProvider(widget.activityId).notifier);
    }
    return ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );
  }

  // Action handlers
  void _saveWorkout(BuildContext context, ActivityDetailState state) async {
    final controller = _getControllerNotifier();

    await controller.saveActivity();

    controller.trackEvent('workout_saved', {
      'activity_id': state.activity?.id,
      'has_nutrition_plan': state.nutritionPlan != null,
      'is_new_activity': state.isNewActivity,
      'is_coach_view': widget.isCoachView,
    });

    if (context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Changes saved successfully!');

      if (state.isNewActivity) {
        context.go('/main');
      }
    }
  }

  void _completeWorkout(BuildContext context, ActivityDetailState state) {
    final activity = state.activity;
    final isBrick = activity != null && activity.isBrick;

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use brick-specific dialog if this is a brick workout
        if (isBrick && activity.brickMetadata != null) {
          return BrickCompletionDialog(
            brick: activity,
            onComplete: (rating, notes) async {
              Navigator.of(dialogContext).pop();
              await _handleCompletion(context, state, rating, notes, isBrick: true);
            },
          );
        }

        // Use standard dialog for single-sport workouts
        return CompletionDialog(
          onComplete: (rating, notes) async {
            Navigator.of(dialogContext).pop();
            await _handleCompletion(context, state, rating, notes, isBrick: false);
          },
        );
      },
    );
  }

  /// Handle workout completion after dialog confirmation
  Future<void> _handleCompletion(
    BuildContext context,
    ActivityDetailState state,
    int rating,
    String? notes, {
    required bool isBrick,
  }) async {
    final controller = _getControllerNotifier();

    await controller.completeActivity(
      overallSatisfaction: rating,
      textNotes: notes,
    );

    controller.trackEvent('workout_completed', {
      'activity_id': state.activity?.id,
      'rating': rating,
      'has_notes': notes?.isNotEmpty ?? false,
      'is_coach_view': widget.isCoachView,
      'is_brick': isBrick,
    });

    if (mounted) {
      final message = isBrick
          ? 'Brick workout completed successfully!'
          : 'Workout completed successfully!';
      MealvanaSnackbar.showSuccess(context, message);
    }
  }

  void _swapFood(BuildContext context, ActivityDetailState state, String foodId, String foodName, String category) {
    final controller = _getControllerNotifier();
    controller.trackEvent('swap_food_tapped', {
      'food_id': foodId,
      'food_name': foodName,
      'section': category,
      'is_coach_view': widget.isCoachView,
    });

    context.push('/swap-food', extra: {
      'foodToSwapId': foodId,
      'foodToSwapName': foodName,
      'category': category,
      'activityId': widget.activityId,
      'isNewActivity': widget.isNewActivity,
      'isCoachView': widget.isCoachView,
    });
  }

  Future<void> _deleteFood(BuildContext context, ActivityDetailState state, String foodId, String category) async {
    final controller = _getControllerNotifier();

    await controller.deleteFoodItem(foodId, category);

    if (mounted) {
      MealvanaSnackbar.showInfo(context, 'Food item removed');
    }
  }

  Future<void> _updateFoodQuantity(BuildContext context, ActivityDetailState state, String foodId, String category, double newQuantity) async {
    final controller = _getControllerNotifier();

    await controller.updateFoodQuantity(foodId, category, newQuantity);
  }

  void _addFood(BuildContext context, String category) {
    final controller = _getControllerNotifier();
    controller.trackEvent('add_food_tapped', {
      'section': category,
    });

    context.push('/swap-food', extra: {
      'foodToSwapId': null,
      'foodToSwapName': null,
      'category': category,
      'activityId': widget.activityId,
      'isNewActivity': widget.isNewActivity,
      'isCoachView': widget.isCoachView,
    });
  }

  /// Handle refresh button tap for synced activities
  void _handleRefreshActivity(BuildContext context, ActivityDetailState state) {
    if (mounted) {
      MealvanaSnackbar.showInfo(context, 'Refresh coming soon');
    }
  }

  /// Handle regenerate plan button tap for stale nutrition plans
  Future<void> _handleRegeneratePlan(BuildContext context, ActivityDetailState state) async {
    if (state.activity == null) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Activity not found');
      }
      return;
    }

    final controller = _getControllerNotifier();
    final success = await controller.regenerateNutritionPlan();

    if (mounted) {
      if (success) {
        MealvanaSnackbar.showSuccess(context, 'Nutrition plan regenerated successfully!');
      } else {
        MealvanaSnackbar.showError(context, 'Failed to regenerate nutrition plan. Please try again.');
      }
    }
  }

  /// Show confirmation dialog before deleting activity
  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.dragonfruit,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteActivity(context);
    }
  }

  /// Delete the current activity and navigate back
  Future<void> _deleteActivity(BuildContext context) async {
    final controller = _getControllerNotifier();
    final success = await controller.deleteActivity();

    if (mounted) {
      if (success) {
        MealvanaSnackbar.showSuccess(context, 'Activity deleted successfully');
        context.go('/main');
      } else {
        MealvanaSnackbar.showError(context, 'Failed to delete activity. Please try again.');
      }
    }
  }
}
