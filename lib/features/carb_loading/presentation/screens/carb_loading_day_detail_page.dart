import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../widgets/carb_loading_food_pills.dart';
import '../widgets/edit_carb_target_dialog.dart';
import '../providers/carb_loading_day_detail_controller.dart';
import '../../domain/meal_type.dart';
import '../../domain/carb_loading_day_meal.dart';

/// Detail page for a single carb loading day
/// Shows progress, meals, and food selection for one specific day
class CarbLoadingDayDetailPage extends ConsumerStatefulWidget {
  final db.CarbLoadingDay carbLoadingDay;

  const CarbLoadingDayDetailPage({
    super.key,
    required this.carbLoadingDay,
  });

  @override
  ConsumerState<CarbLoadingDayDetailPage> createState() => _CarbLoadingDayDetailPageState();
}

class _CarbLoadingDayDetailPageState extends ConsumerState<CarbLoadingDayDetailPage> {
  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Carb Loading Day ${widget.carbLoadingDay.dayNumber}',
              style: AppTextStyles.subtitle.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(widget.carbLoadingDay.planDate),
              style: AppTextStyles.smallLabel.copyWith(
                color: isDark ? AppColors.cream.withValues(alpha: 0.7) : AppColors.blackberry.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
            onSelected: (value) => _handleMenuAction(context, value),
            color: isDark ? AppColors.blackberryLight : AppColors.cream,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset_progress',
                child: ListTile(
                  leading: Icon(
                    Icons.refresh,
                    size: 20,
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                  ),
                  title: Text(
                    'Reset Progress',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'mark_complete',
                child: ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.electrolyte,
                  ),
                  title: Text(
                    'Mark Complete',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: controllerState.when(
        data: (state) => SingleChildScrollView(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.lg),

              // Progress Card (Kyle's Design)
              _buildProgressCard(context, state),

              SizedBox(height: AppSpacing.lg),

              // Meal sections
              _buildMealSections(context, state),

              // Bottom padding
              SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppColors.electrolyte,
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.dragonfruit,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'Error loading day: $error',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.cream
                      : AppColors.blackberry,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                      .refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.blackberry,
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.buttonPrimary.copyWith(
                    color: AppColors.blackberry,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: controllerState.when(
        data: (state) => state.totalConsumed >= state.carbLoadingDay.carbTargetGrams
            ? FloatingActionButton.extended(
                onPressed: () => _markDayComplete(context),
                backgroundColor: AppColors.electrolyte,
                foregroundColor: AppColors.blackberry,
                icon: const Icon(Icons.check),
                label: Text(
                  'Mark Complete',
                  style: AppTextStyles.buttonPrimary.copyWith(
                    color: AppColors.blackberry,
                  ),
                ),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  /// Build progress card matching Kyle's design
  Widget _buildProgressCard(BuildContext context, CarbLoadingDayDetailState state) {
    final carbDay = state.carbLoadingDay;
    final consumed = state.totalConsumed;
    final target = carbDay.carbTargetGrams;
    final isOverloaded = consumed > target;
    final overloadAmount = consumed - target;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Daily Progress',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: textColor,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditTargetDialog(context),
                icon: Icon(
                  Icons.edit,
                  size: 16,
                  color: textColor,
                ),
                label: Text(
                  'Edit Target',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: textColor,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.md),

          // Progress display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${consumed}g',
                style: AppTextStyles.dataNumberLarge.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / ',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                ),
              ),
              Text(
                '${target}g',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                ),
              ),
            ],
          ),

          // Warning banner if overloaded
          if (isOverloaded) ...[
            SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.orange,
                  width: 2,
                ),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: AppColors.orange,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'OVERLOADED BY ${overloadAmount}G',
                      style: AppTextStyles.smallLabel.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealSections(BuildContext context, CarbLoadingDayDetailState state) {
    final carbDay = state.carbLoadingDay;

    // Define meal types with proper display names
    final mealSections = [
      (MealType.breakfast, 'Breakfast', carbDay.breakfastPercent),
      (MealType.morningSnack, 'Morning Snack', carbDay.morningSnackPercent),
      (MealType.lunch, 'Lunch', carbDay.lunchPercent),
      (MealType.afternoonSnack, 'Afternoon Snack', carbDay.afternoonSnackPercent),
      (MealType.dinner, 'Dinner', carbDay.dinnerPercent),
      (MealType.eveningSnack, 'Evening Snack', carbDay.eveningSnackPercent),
    ];

    return Column(
      children: mealSections.map((section) {
        final mealType = section.$1;
        final displayName = section.$2;
        final percent = section.$3;
        final targetCarbs = (carbDay.carbTargetGrams * percent).round();
        final meals = state.mealsForType(mealType);
        final currentCarbs = state.carbsForMealType(mealType);

        return _buildMealSection(
          context,
          state,
          mealType,
          displayName,
          targetCarbs,
          currentCarbs,
          meals,
        );
      }).toList(),
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    CarbLoadingDayDetailState state,
    MealType mealType,
    String displayName,
    int targetCarbs,
    int currentCarbs,
    meals,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: BaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with meal name and progress badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: AppTextStyles.subtitle.copyWith(
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Progress badge (blue circle)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentCarbs/${targetCarbs}g',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: AppColors.blackberry,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: AppSpacing.md),

            // Food pills - inline pattern: show blue pills for selected, gray buttons for available
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Default foods
                ...state.defaultFoods.where((food) => food.isSuitableForMeal(mealType)).map((food) {
                  // Check if this food is already added to this meal
                  final meal = meals.cast<CarbLoadingDayMeal?>().firstWhere(
                    (m) => m != null && m.carbLoadingFoodId == food.id && m.carbLoadingUserFoodId == null,
                    orElse: () => null,
                  );
                  final isSelected = meal != null;

                  if (isSelected) {
                    // Show as blue pill with +/- controls
                    return CarbLoadingFoodPill(
                      foodName: food.displayName,
                      quantity: meal.quantity,
                      onIncrement: () {
                        ref
                            .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                            .incrementQuantity(meal.id);
                      },
                      onDecrement: () {
                        if (meal.quantity > 1) {
                          ref
                              .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                              .decrementQuantity(meal.id);
                        } else {
                          ref
                              .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                              .removeMeal(meal.id);
                        }
                      },
                    );
                  } else {
                    // Show as gray button
                    return _buildQuickAddFoodButton(
                      context,
                      food.displayName,
                      food.carbsDisplay,
                      () {
                        ref
                            .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                            .addDefaultFood(mealType, food);
                      },
                    );
                  }
                }),
                // User foods
                ...state.userFoods.where((food) => !food.isDeleted && food.isSuitableForMeal(mealType)).map((food) {
                  // Check if this food is already added to this meal
                  final meal = meals.cast<CarbLoadingDayMeal?>().firstWhere(
                    (m) => m != null && m.carbLoadingUserFoodId == food.id && m.carbLoadingFoodId == null,
                    orElse: () => null,
                  );
                  final isSelected = meal != null;

                  if (isSelected) {
                    // Show as blue pill with +/- controls
                    return CarbLoadingFoodPill(
                      foodName: food.displayName,
                      quantity: meal.quantity,
                      onIncrement: () {
                        ref
                            .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                            .incrementQuantity(meal.id);
                      },
                      onDecrement: () {
                        if (meal.quantity > 1) {
                          ref
                              .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                              .decrementQuantity(meal.id);
                        } else {
                          ref
                              .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                              .removeMeal(meal.id);
                        }
                      },
                    );
                  } else {
                    // Show as gray button
                    return _buildQuickAddFoodButton(
                      context,
                      food.displayName,
                      food.carbsDisplay,
                      () {
                        ref
                            .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                            .addUserFood(mealType, food);
                      },
                    );
                  }
                }),
              ],
            ),

            const SizedBox(height: 12),

            // Add food button (bottom left, styled like activity detail screen)
            Align(
              alignment: Alignment.centerLeft,
              child: _buildAddFoodButton(context, mealType),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddFoodButton(BuildContext context, String name, String carbs, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.blackberryLight.withValues(alpha: 0.5)
              : AppColors.cream.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.cream.withValues(alpha: 0.3)
                : AppColors.blackberry.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.cream.withValues(alpha: 0.7)
                    : AppColors.blackberry.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              carbs,
              style: AppTextStyles.smallLabel.copyWith(
                color: isDark
                    ? AppColors.cream.withValues(alpha: 0.5)
                    : AppColors.blackberry.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFoodButton(BuildContext context, MealType mealType) {
    return InkWell(
      onTap: () async {
        // Navigate to carb loading food selection screen
        await context.push('/carb-loading-select-food', extra: {
          'dayId': widget.carbLoadingDay.id,
          'mealType': mealType,
        });

        // Refresh the page when returning to show newly added foods
        if (mounted) {
          ref
              .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
              .refresh();
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFE8B4BC), // Light pink/rose from Kyle's design
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          color: AppColors.blackberry,
          size: 24,
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'reset_progress':
        _showResetProgressDialog(context);
        break;
      case 'mark_complete':
        _markDayComplete(context);
        break;
    }
  }

  void _showEditTargetDialog(BuildContext context) {
    final controllerState = ref.read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id));

    controllerState.whenData((state) {
      final carbDay = state.carbLoadingDay;

      // Calculate body weight from target and protocol
      final carbProtocol = carbDay.carbProtocolGPerKg;
      final bodyWeightKg = carbProtocol > 0
          ? carbDay.carbTargetGrams / carbProtocol
          : 70.0; // Fallback to 70kg if protocol is 0

      showDialog(
        context: context,
        builder: (dialogContext) => EditCarbTargetDialog(
          currentCarbsPerKg: carbProtocol,
          currentDailyTargetG: carbDay.carbTargetGrams,
          bodyWeightKg: bodyWeightKg,
          onSave: (carbsPerKg, dailyTargetG) {
            ref
                .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                .updateCarbTarget(
                  carbsPerKg: carbsPerKg,
                  dailyTargetG: dailyTargetG,
                );
          },
        ),
      );
    });
  }

  void _showResetProgressDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.blackberryLight : AppColors.cream,
        title: Text(
          'Reset Progress',
          style: AppTextStyles.subtitle.copyWith(
            color: isDark ? AppColors.cream : AppColors.blackberry,
          ),
        ),
        content: Text(
          'This will clear all your food selections for this day. Are you sure?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.cream : AppColors.blackberry,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.buttonTertiary.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                  .resetDay();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.blackberry,
            ),
            child: Text(
              'Reset',
              style: AppTextStyles.buttonPrimary.copyWith(
                color: AppColors.blackberry,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _markDayComplete(BuildContext context) {
    // TODO: Mark day as complete in database
    MealvanaSnackbar.showSuccess(context, 'Day marked as complete!');
    Navigator.of(context).pop();
  }
}

