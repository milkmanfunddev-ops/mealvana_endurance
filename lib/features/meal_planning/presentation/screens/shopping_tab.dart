import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/shopping_list_controller.dart';
import '../widgets/shopping_list.dart';
import '../../../kroger/application/kroger_availability.dart';

/// The Shopping tab (05 §4): the confirmed plan's aisle-grouped list with
/// local-first toggles. Sharing lives in the Food screen's header (beside
/// the settings gear) via [ShoppingShareButton]. Kroger's reviewed cart
/// handoff is separately release-gated; checkout stays in Kroger.
class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final state = ref.watch(shoppingListControllerProvider).value;
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.imperial;

    return state == null || state.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  content.getValue(ContentKeys.mpShoppingEmptyTitle),
                  key: const ValueKey('meal_planning.shopping_empty'),
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Text(
                    content.getValue(ContentKeys.mpShoppingEmptyBody),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (state.planId != null &&
                  ref.watch(krogerEntryVisibleProvider)) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: KyleSecondaryButtonSmall(
                    key: const ValueKey('meal_planning.kroger'),
                    icon: Icons.shopping_cart_outlined,
                    text: content.getValue(ContentKeys.krogerTitle),
                    // Into the Food tree, not onto a bare Navigator route:
                    // the screen keeps the app's chrome and the Pro gate.
                    onPressed: () =>
                        context.push('/food/kroger/${state.planId}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              ShoppingList(
                state: state,
                onToggleChecked: (item, value) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setChecked(item.name, value),
                onAddBack: (name) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setHave(name, false),
                units: units,
                onOpenMeal: (meal) => context.push(
                  '/food/meals/${meal.libraryMealId ?? meal.savedMealId ?? meal.id}',
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
  }
}
