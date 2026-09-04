import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/shopping_list_controller.dart';
import '../widgets/shopping_list.dart';

/// The Shopping tab (05 §4): the confirmed plan's aisle-grouped list with
/// local-first toggles. Sharing lives in the Food screen's header (beside
/// the settings gear) via [ShoppingShareButton]. "Order pickup" is
/// deliberately not v1.
class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final state = ref.watch(shoppingListControllerProvider).value;

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
              ShoppingList(
                state: state,
                onToggleChecked: (item, value) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setChecked(item.name, value),
                onAddBack: (name) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setHave(name, false),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
  }
}
