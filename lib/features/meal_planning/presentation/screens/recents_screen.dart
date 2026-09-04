import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_catalog_controller.dart';
import '../../domain/meal_ref.dart';
import '../widgets/meal_card.dart';
import '../widgets/vana_round_button.dart';

/// `/food/meals/recents` — the full Recents list (the rail's "See all").
/// Local logs ∪ plan meals by recency; server-resolved when online.
class RecentsScreen extends ConsumerWidget {
  const RecentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final catalog = ref.watch(mealCatalogControllerProvider).value;
    final recents = catalog?.recents ?? const <RecentMeal>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The header lives in the body, as in the prototype: a round back
            // button beside the screen name.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  VanaRoundButton.back(
                    context: context,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    content.getValue(ContentKeys.mpRailRecents),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: textColor,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: recents.isEmpty
          ? Center(
              child: Text(
                content.getValue(ContentKeys.mpRecentsEmpty),
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: recents.length,
              itemBuilder: (context, i) {
                final meal = recents[i].meal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MealCard(
                    key: ValueKey('meal_planning.recents_${meal.id}'),
                    meal: meal,
                    onTap: () => context.push('/food/meals/${meal.id}'),
                  ),
                );
              },
            ),
            ),
          ],
        ),
      ),
    );
  }
}
