import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/content_area.dart';
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

  const CarbLoadingDayDetailPage({super.key, required this.carbLoadingDay});

  @override
  ConsumerState<CarbLoadingDayDetailPage> createState() =>
      _CarbLoadingDayDetailPageState();
}

class _CarbLoadingDayDetailPageState
    extends ConsumerState<CarbLoadingDayDetailPage> {
  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(
      carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(
          key: const ValueKey('carb_plan_day.back_button'),
        ),
        // ITEM 17 fix: the title Column was crowded by the back button, Done
        // button, and PopupMenu, and the top line used a wide display font
        // (AppTextStyles.subtitle / Compadre) with no overflow handling,
        // truncating to "...". FittedBox scales the whole title block down
        // to fit the remaining space instead of clipping it, and the top
        // line now has an explicit ellipsis/maxLines fallback as a safety net.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                key: const ValueKey('carb_plan_day.title'),
                'Carb Loading Day ${widget.carbLoadingDay.dayNumber}',
                // Switched from AppTextStyles.subtitle (Compadre, a wide
                // display font) to foodTitle (Apercu) — narrower per
                // character so it competes less with the crowded back
                // button / Done button / popup menu around it.
                style: AppTextStyles.foodTitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                key: const ValueKey('carb_plan_day.date_label'),
                DateFormat('EEEE, MMM d').format(widget.carbLoadingDay.planDate),
                style: AppTextStyles.smallLabel.copyWith(
                  color: isDark
                      ? AppColors.cream.withValues(alpha: 0.7)
                      : AppColors.blackberry.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
        actions: [
          TextButton(
            key: const ValueKey('carb_plan_day.done_button'),
            onPressed: () {
              // ITEM 19 fix: this page is always pushed imperatively
              // (Navigator.push / pushReplacement from coach portal, activities,
              // and events flows) — it is never on the GoRouter page stack.
              // Using context.go()/context.pop() here mixes declarative GoRouter
              // navigation with an imperatively-pushed page, which throws
              // GoError("There is nothing to pop"). A plain guarded Navigator
              // pop correctly returns to whichever screen pushed this page,
              // matching pushReplacement's "back goes to the previous screen"
              // intent for all three call sites.
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
            },
            child: Text(
              'Done',
              style: AppTextStyles.buttonTertiary.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('carb_plan_day.menu_button'),
            icon: Icon(
              Icons.more_vert,
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
            onSelected: (value) => _handleMenuAction(context, value),
            color: isDark ? AppColors.blackberryLight : AppColors.cream,
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const ValueKey('carb_plan_day.menu_reset_progress'),
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
                key: const ValueKey('carb_plan_day.menu_mark_complete'),
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
        data: (state) => ContentArea(
          child: RefreshIndicator(
            color: AppColors.electrolyte,
            onRefresh: () => ref
                .read(
                  carbLoadingDayDetailControllerProvider(
                    widget.carbLoadingDay.id,
                  ).notifier,
                )
                .forceRefresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
          ),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.dragonfruit),
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
                      .read(
                        carbLoadingDayDetailControllerProvider(
                          widget.carbLoadingDay.id,
                        ).notifier,
                      )
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
        data: (state) =>
            state.totalConsumed >= state.carbLoadingDay.carbTargetGrams
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
  Widget _buildProgressCard(
    BuildContext context,
    CarbLoadingDayDetailState state,
  ) {
    final carbDay = state.carbLoadingDay;
    final consumed = state.totalConsumed;
    final target = carbDay.carbTargetGrams;
    final isOverloaded = consumed > target;
    final overloadAmount = consumed - target;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return BaseCard(
      key: const ValueKey('carb_plan_day.daily_total_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Daily Progress',
                style: AppTextStyles.sectionTitle.copyWith(color: textColor),
              ),
              TextButton.icon(
                key: const ValueKey('carb_plan_day.edit_target_button'),
                onPressed: () => _showEditTargetDialog(context),
                icon: Icon(Icons.edit, size: 16, color: textColor),
                label: Text(
                  'Edit Target',
                  style: AppTextStyles.smallLabel.copyWith(color: textColor),
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
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
              Text(
                '${target}g',
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
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
                border: Border.all(color: AppColors.orange, width: 2),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppColors.orange, size: 20),
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

  Widget _buildMealSections(
    BuildContext context,
    CarbLoadingDayDetailState state,
  ) {
    final carbDay = state.carbLoadingDay;

    // Define meal types with proper display names
    final mealSections = [
      (MealType.breakfast, 'Breakfast', carbDay.breakfastPercent),
      (MealType.morningSnack, 'Morning Snack', carbDay.morningSnackPercent),
      (MealType.lunch, 'Lunch', carbDay.lunchPercent),
      (
        MealType.afternoonSnack,
        'Afternoon Snack',
        carbDay.afternoonSnackPercent,
      ),
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
        key: ValueKey('carb_plan_day.section_${mealType.name}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with meal name and progress badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: AppTextStyles.subtitle.copyWith(color: textColor),
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
                ...state.defaultFoods
                    .where((food) => food.isSuitableForMeal(mealType))
                    .map((food) {
                      // Check if this food is already added to this meal
                      final meal = meals.cast<CarbLoadingDayMeal?>().firstWhere(
                        (m) =>
                            m != null &&
                            m.carbLoadingFoodId == food.id &&
                            m.carbLoadingUserFoodId == null,
                        orElse: () => null,
                      );
                      final isSelected = meal != null;

                      if (isSelected) {
                        // Show as blue pill with +/- controls
                        return CarbLoadingFoodPill(
                          foodName: food.displayName,
                          quantity: meal.quantity,
                          carbsPerServing: food.carbsPerServing,
                          onIncrement: () {
                            ref
                                .read(
                                  carbLoadingDayDetailControllerProvider(
                                    widget.carbLoadingDay.id,
                                  ).notifier,
                                )
                                .incrementQuantity(meal.id);
                          },
                          onDecrement: () {
                            if (meal.quantity > 1) {
                              ref
                                  .read(
                                    carbLoadingDayDetailControllerProvider(
                                      widget.carbLoadingDay.id,
                                    ).notifier,
                                  )
                                  .decrementQuantity(meal.id);
                            } else {
                              ref
                                  .read(
                                    carbLoadingDayDetailControllerProvider(
                                      widget.carbLoadingDay.id,
                                    ).notifier,
                                  )
                                  .removeMeal(meal.id);
                            }
                          },
                        );
                      } else {
                        // Show as gray button
                        final slug = food.displayName.toLowerCase().replaceAll(
                          RegExp(r'[^a-z0-9]+'),
                          '_',
                        );
                        return _buildQuickAddFoodButton(
                          context,
                          food.displayName,
                          food.carbsDisplay,
                          () {
                            ref
                                .read(
                                  carbLoadingDayDetailControllerProvider(
                                    widget.carbLoadingDay.id,
                                  ).notifier,
                                )
                                .addDefaultFood(mealType, food);
                          },
                          chipKey: ValueKey('carb_plan_day.food_chip_$slug'),
                        );
                      }
                    }),
                // User foods
                ...state.userFoods
                    .where(
                      (food) =>
                          !food.isDeleted && food.isSuitableForMeal(mealType),
                    )
                    .map((food) {
                      // Check if this food is already added to this meal
                      final meal = meals.cast<CarbLoadingDayMeal?>().firstWhere(
                        (m) =>
                            m != null &&
                            m.carbLoadingUserFoodId == food.id &&
                            m.carbLoadingFoodId == null,
                        orElse: () => null,
                      );
                      final isSelected = meal != null;

                      if (isSelected) {
                        // Show as blue pill with +/- controls
                        return CarbLoadingFoodPill(
                          foodName: food.displayName,
                          quantity: meal.quantity,
                          carbsPerServing: food.carbsPerServing,
                          onIncrement: () {
                            ref
                                .read(
                                  carbLoadingDayDetailControllerProvider(
                                    widget.carbLoadingDay.id,
                                  ).notifier,
                                )
                                .incrementQuantity(meal.id);
                          },
                          onDecrement: () {
                            if (meal.quantity > 1) {
                              ref
                                  .read(
                                    carbLoadingDayDetailControllerProvider(
                                      widget.carbLoadingDay.id,
                                    ).notifier,
                                  )
                                  .decrementQuantity(meal.id);
                            } else {
                              ref
                                  .read(
                                    carbLoadingDayDetailControllerProvider(
                                      widget.carbLoadingDay.id,
                                    ).notifier,
                                  )
                                  .removeMeal(meal.id);
                            }
                          },
                        );
                      } else {
                        // Show as gray button
                        final slug = food.displayName.toLowerCase().replaceAll(
                          RegExp(r'[^a-z0-9]+'),
                          '_',
                        );
                        return _buildQuickAddFoodButton(
                          context,
                          food.displayName,
                          food.carbsDisplay,
                          () {
                            ref
                                .read(
                                  carbLoadingDayDetailControllerProvider(
                                    widget.carbLoadingDay.id,
                                  ).notifier,
                                )
                                .addUserFood(mealType, food);
                          },
                          chipKey: ValueKey('carb_plan_day.food_chip_$slug'),
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

  Widget _buildQuickAddFoodButton(
    BuildContext context,
    String name,
    String carbs,
    VoidCallback onTap, {
    Key? chipKey,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      key: chipKey,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // Semi-transparent purple background for unselected pills
          color: isDark
              ? AppColors.blackberryLight.withValues(alpha: 0.3)
              : AppColors.cream.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            // Teal border
            color: isDark
                ? AppColors.electrolyte.withValues(alpha: 0.6)
                : AppColors.blackberry.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              carbs,
              style: AppTextStyles.smallLabel.copyWith(
                color: isDark
                    ? AppColors.cream.withValues(alpha: 0.7)
                    : AppColors.blackberry.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFoodButton(BuildContext context, MealType mealType) {
    return InkWell(
      key: ValueKey('carb_plan_day.add_food_${mealType.name}'),
      onTap: () async {
        // Navigate to carb loading food selection screen
        await context.push(
          '/carb-loading-select-food',
          extra: {'dayId': widget.carbLoadingDay.id, 'mealType': mealType},
        );

        // Refresh the page when returning to show newly added foods
        if (mounted) {
          ref
              .read(
                carbLoadingDayDetailControllerProvider(
                  widget.carbLoadingDay.id,
                ).notifier,
              )
              .refresh();
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // Orange outlined button (matching branded design)
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.orange, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: AppColors.orange, size: 20),
            SizedBox(width: AppSpacing.xs),
            Text(
              'ADD FOOD',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
    final controllerState = ref.read(
      carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id),
    );

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
                .read(
                  carbLoadingDayDetailControllerProvider(
                    widget.carbLoadingDay.id,
                  ).notifier,
                )
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
                  .read(
                    carbLoadingDayDetailControllerProvider(
                      widget.carbLoadingDay.id,
                    ).notifier,
                  )
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
    // Guarded for the same reason as the Done button (ITEM 19): this page is
    // always pushed imperatively, never via GoRouter.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
