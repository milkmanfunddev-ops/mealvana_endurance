import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/activity_detail/completion_dialog.dart';
import '../widgets/activity_detail/expandable_food_item_widget.dart';
import '../widgets/activity_detail/geometric_pattern_painter.dart';
import '../utils/activity_detail_helpers.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/domain/activity_type.dart';
import '../providers/activity_detail_controller.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/food_item_data.dart';

/// Activity Detail Screen - Refactored with extracted widgets
/// Shows activity details with nutrition sections and food items
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.isNewActivity = false,
  });

  final String activityId;
  final bool isNewActivity;

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
      if (mounted) {
        setState(() {
          _hasShownSwipeHint = true;
          _swipeHintChecked = true;
        });
      }
    }
  }

  Future<void> _markSwipeHintShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_swipeHintShownKey, true);
    } catch (e) {
      // Silently fail
    }
  }

  bool _consumeSwipeHint() {
    if (!_swipeHintChecked) return false;
    if (_hasShownSwipeHint) return false;
    _hasShownSwipeHint = true;
    _markSwipeHintShown();
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
          if (state.nutritionPlan != null)
            _buildNutritionSections(context, state),
          if (state.nutritionPlan == null)
            _buildNoNutritionPlanState(context),
          const SizedBox(height: AppSpacing.xl),
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

    return Column(
      children: [
        _buildHeroImageWithPattern(context, activityType),
        const SizedBox(height: AppSpacing.lg),
        _buildScheduleInfo(context, scheduledDateTime, activityType),
      ],
    );
  }

  Widget _buildHeroImageWithPattern(BuildContext context, ActivityType activityType) {
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
          CustomPaint(
            size: const Size(double.infinity, 280),
            painter: GeometricPatternPainter(),
          ),
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
                  ActivityDetailHelpers.formatDateShort(scheduledDateTime),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xxl),
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
                  ActivityDetailHelpers.formatTime(scheduledDateTime),
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
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildMacroSummaryRow(context, state, section.foodItems, category, section),
          const SizedBox(height: AppSpacing.md),
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
    // Calculate totals
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

    // Get targets
    int targetCarbs = section.carbsTarget?.round() ?? totalCarbs;
    int targetProtein = section.proteinTarget?.round() ?? totalProtein;
    int targetSodium = section.sodiumTarget?.round() ?? totalSodium;
    int targetFluids = section.fluidsTarget?.round() ?? totalFluids.round();

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

  Widget _buildMacroSummaryItem({
    required BuildContext context,
    required int actual,
    required int target,
    required String unit,
    required String label,
  }) {
    final actualColor = ActivityDetailHelpers.getMacroDeviationColor(context, actual, target);
    final targetColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
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
            await _deleteFood(context, state, food.id, category);
          }
          return false;
        } else if (direction == DismissDirection.endToStart) {
          _swapFood(context, state, food.id, food.name, category);
          return false;
        }
        return false;
      },
      child: ExpandableFoodItemWidget(
        food: food,
        getFoodIcon: ActivityDetailHelpers.getFoodIcon,
        isUserImportedFood: ActivityDetailHelpers.isUserImportedFood,
        getFoodIconColor: ActivityDetailHelpers.getFoodIconColor,
        onSwap: () => _swapFood(context, state, food.id, food.name, category),
        onRemove: () => _deleteFood(context, state, food.id, category),
        showSwipeHint: showSwipeHint,
        onQuantityChange: (newQuantity) => _updateFoodQuantity(context, state, food.id, category, newQuantity),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ActivityDetailState state) {
    if (state.isCompleted) {
      return _buildCompletedState(context, state);
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
                  'Completed on ${ActivityDetailHelpers.formatDate(state.completion!.completedAt)}',
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

  // Action handlers
  void _saveWorkout(BuildContext context, ActivityDetailState state) async {
    final controller = ref.read(
      activityDetailControllerProvider(
        activityId: widget.activityId,
        isNewActivity: widget.isNewActivity,
      ).notifier,
    );

    await controller.saveActivity();

    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('workout_saved', properties: {
      'activity_id': state.activity?.id,
      'has_nutrition_plan': state.nutritionPlan != null,
      'is_new_activity': state.isNewActivity,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved successfully!'),
          backgroundColor: AppColors.electrolyte,
        ),
      );

      if (state.isNewActivity) {
        context.go('/main');
      }
    }
  }

  void _completeWorkout(BuildContext context, ActivityDetailState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => CompletionDialog(
        onComplete: (rating, notes) async {
          Navigator.of(dialogContext).pop();

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

          final analytics = ref.read(appExternalDepsProvider);
          analytics.analytics.track('workout_completed', properties: {
            'activity_id': state.activity?.id,
            'rating': rating,
            'has_notes': notes?.isNotEmpty ?? false,
          });

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
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('swap_food_tapped', properties: {
      'food_id': foodId,
      'food_name': foodName,
      'section': category,
    });

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
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('add_food_tapped', properties: {
      'section': category,
    });

    context.push('/swap-food', extra: {
      'foodToSwapId': null,
      'foodToSwapName': null,
      'category': category,
      'activityId': widget.activityId,
      'isNewActivity': widget.isNewActivity,
    });
  }
}
