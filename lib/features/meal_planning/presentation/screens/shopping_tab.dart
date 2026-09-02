import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/shopping_list_controller.dart';
import '../widgets/shopping_list.dart';

/// The Shopping tab (05 §4): the confirmed plan's aisle-grouped list with
/// local-first toggles and a plain-text share sheet. "Order pickup" is
/// deliberately not v1.
class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final state = ref.watch(shoppingListControllerProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Stack(
      children: [
        if (state == null || state.isEmpty)
          Center(
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
        else
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              ShoppingList(
                state: state,
                onToggleChecked: (item, value) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setChecked(item.name, value),
                onToggleHave: (item, value) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setHave(item.name, value),
                onAddBack: (name) => ref
                    .read(shoppingListControllerProvider.notifier)
                    .setHave(name, false),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        if (state != null && !state.isEmpty)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('meal_planning.shopping_share'),
                onPressed: () {
                  final body = ref
                      .read(shoppingListControllerProvider.notifier)
                      .shareText();
                  if (body.isEmpty) return;
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${content.getValue(ContentKeys.mpShoppingShareTitle)}\n\n$body',
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.16),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: Text(
                  content.getValue(ContentKeys.mpShoppingShare),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
