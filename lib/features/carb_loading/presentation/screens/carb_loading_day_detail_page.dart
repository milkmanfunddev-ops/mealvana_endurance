import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../widgets/daily_progress_widget.dart';
import '../widgets/carb_loading_food_pills.dart';
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
  void initState() {
    super.initState();
    // Initialize controller with the carb loading day
    Future.microtask(() {
      ref
          .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
          .initialize(widget.carbLoadingDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id));

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Carb Loading Day ${widget.carbLoadingDay.dayNumber}'),
            Text(
              DateFormat('EEEE, MMM d').format(widget.carbLoadingDay.planDate),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset_progress',
                child: ListTile(
                  leading: Icon(Icons.refresh, size: 20),
                  title: Text('Reset Progress'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'mark_complete',
                child: ListTile(
                  leading: Icon(Icons.check_circle, size: 20, color: Colors.green),
                  title: Text('Mark Complete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: controllerState.when(
        data: (state) => CustomScrollView(
          slivers: [
            // Day Info Card
            SliverToBoxAdapter(
              child: _buildDayInfoCard(context, state),
            ),

            // Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),

            // Sticky progress widget
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyProgressDelegate(
                totalConsumed: state.totalConsumed,
                targetAmount: state.carbLoadingDay.carbTargetGrams,
                onEditTarget: () => _showEditTargetDialog(context),
              ),
            ),

            // Spacing after sticky header
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),

            // Meal sections
            SliverToBoxAdapter(
              child: _buildMealSections(context, state),
            ),

            // Bottom padding for FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading day: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                      .refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: controllerState.when(
        data: (state) => state.totalConsumed >= state.carbLoadingDay.carbTargetGrams
            ? FloatingActionButton.extended(
                onPressed: () => _markDayComplete(context),
                backgroundColor: Colors.green,
                icon: const Icon(Icons.check),
                label: const Text('Mark Complete'),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildDayInfoCard(BuildContext context, CarbLoadingDayDetailState state) {
    final theme = Theme.of(context);
    final carbDay = state.carbLoadingDay;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF9800),
            const Color(0xFFFF9800).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${carbDay.dayNumber}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE').format(carbDay.planDate),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'RACE PREP',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Target carbs with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${carbDay.carbProtocolGPerKg.toStringAsFixed(1)}g/kg bodyweight',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (state.totalConsumed > 0) ...[
              // const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text(
                  //   'Progress: ${state.totalConsumed}g / ${carbDay.carbTargetGrams}g',
                  //   style: theme.textTheme.bodyMedium?.copyWith(
                  //     color: Colors.white.withValues(alpha: 0.9),
                  //   ),
                  // ),
                  // const SizedBox(height: 8),
                  // ClipRRect(
                  //   borderRadius: BorderRadius.circular(4),
                  //   child: LinearProgressIndicator(
                  //     value: state.progress,
                  //     backgroundColor: Colors.white.withValues(alpha: 0.3),
                  //     valueColor: AlwaysStoppedAnimation<Color>(
                  //       state.progress >= 0.9 ? Colors.green : Colors.white,
                  //     ),
                  //     minHeight: 8,
                  //   ),
                  // ),
                ],
              ),
            ],
          ],
        ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with meal name and progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentCarbs/${targetCarbs}g',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              carbs,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
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
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppTheme.highlight100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          color: AppTheme.primary900,
          size: 24.sp,
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
    // TODO: Implement edit target dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit target coming soon')),
    );
  }

  void _showResetProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'This will clear all your food selections for this day. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(carbLoadingDayDetailControllerProvider(widget.carbLoadingDay.id).notifier)
                  .resetDay();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _markDayComplete(BuildContext context) {
    // TODO: Mark day as complete in database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Day marked as complete!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }
}

/// Custom delegate for sticky progress widget
class _StickyProgressDelegate extends SliverPersistentHeaderDelegate {
  final int totalConsumed;
  final int targetAmount;
  final VoidCallback onEditTarget;

  const _StickyProgressDelegate({
    required this.totalConsumed,
    required this.targetAmount,
    required this.onEditTarget,
  });

  @override
  double get minExtent => 120.0;

  @override
  double get maxExtent => 120.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.baseCream,
      child: DailyProgressWidget(
        totalConsumed: totalConsumed,
        targetAmount: targetAmount,
        onEditTarget: onEditTarget,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is! _StickyProgressDelegate) return true;
    return oldDelegate.totalConsumed != totalConsumed || oldDelegate.targetAmount != targetAmount;
  }
}
