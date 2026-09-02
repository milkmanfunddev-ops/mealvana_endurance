import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_plan_controller.dart';
import '../../data/meal_library_remote_data_source.dart';
import '../../data/vana_exceptions.dart';
import '../../domain/meal_ref.dart';
import '../../domain/plan_meal.dart';
import '../widgets/meal_card.dart';

/// `/food/swap/:planMealId` (05 §4): the "Replacing X" header card plus the
/// same-type catalog (excluding what is already planned). Picking runs the
/// remote-ack `swap_meal` (+ `set_servings` via the detail-style stepper
/// flow), then pops back to the Plan tab.
class SwapMealScreen extends ConsumerStatefulWidget {
  const SwapMealScreen({super.key, required this.planMealId});

  final String planMealId;

  @override
  ConsumerState<SwapMealScreen> createState() => _SwapMealScreenState();
}

class _SwapMealScreenState extends ConsumerState<SwapMealScreen> {
  Future<List<MealRef>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _future != null) return;
      final plan = ref.read(mealPlanControllerProvider).value;
      final meal = plan?.meals
          .where((m) => m.id == widget.planMealId)
          .firstOrNull;
      if (meal == null) return;
      final exclude = {
        for (final m in plan!.meals) m.libraryMealId ?? m.savedMealId ?? m.name,
      };
      setState(() {
        _future = ref
            .read(mealLibraryRemoteDataSourceProvider)
            .searchMeals(
              mealType: meal.mealType,
              excludeIds: exclude.where((id) => !id.contains(' ')).toSet(),
              limit: 20,
            );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final plan = ref.watch(mealPlanControllerProvider).value;
    final PlanMeal? current = plan?.meals
        .where((m) => m.id == widget.planMealId)
        .firstOrNull;

    return Scaffold(
      key: ValueKey('meal_planning.swap_${widget.planMealId}'),
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(
          content.getValue(ContentKeys.mpSwapTitle),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
      ),
      body: current == null
          ? Center(
              child: Text(
                content.getValue(ContentKeys.mpSearchEmpty),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    ContentKeys.format(
                      content.getValue(ContentKeys.mpSwapReplacing),
                      {'name': current.name},
                    ),
                    key: const ValueKey('meal_planning.swap_replacing'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: _future == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.electrolyte,
                          ),
                        )
                      : FutureBuilder<List<MealRef>>(
                          future: _future,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.electrolyte,
                                ),
                              );
                            }
                            final meals = snapshot.data ?? const <MealRef>[];
                            return ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: meals.length,
                              itemBuilder: (context, i) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: MealCard(
                                  meal: meals[i],
                                  onTap: () =>
                                      _swap(context, meals[i], current),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _swap(
    BuildContext context,
    MealRef replacement,
    PlanMeal current,
  ) async {
    final content = ref.read(contentServiceProvider);
    final controller = ref.read(mealPlanControllerProvider.notifier);
    try {
      await controller.swapMeal(
        current.id,
        source: replacement.source,
        id: replacement.id,
      );
      if (context.mounted) context.pop();
    } on NeedsConnectionException {
      if (context.mounted) {
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.mpNeedsConnection),
        );
      }
    } on Exception {
      if (context.mounted) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.mpServerError),
        );
      }
    }
  }
}
