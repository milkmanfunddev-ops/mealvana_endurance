import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/common_ingredients.dart';
import '../../domain/meal_component.dart';
import '../../domain/quick_assembly.dart';
import '../providers/draft_meal_controller.dart';

/// "Common" tab body: curated quick-add combos ([kQuickAssemblies]) plus the
/// single-ingredient library ([kCommonIngredients]).
///
/// Every row adds directly to the build-a-meal draft (item 1) — no per-tap
/// slot/servings prompt. The user can adjust quantity afterwards via the
/// draft editor's [MealComponentEditor] (reused there for edit/swap/delete).
class CommonIngredientsSection extends ConsumerWidget {
  const CommonIngredientsSection({
    super.key,
    required this.logDate,
    required this.scrollController,
  });

  final String logDate;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    void addAssembly(QuickAssembly assembly) {
      ref
          .read(draftMealControllerProvider(logDate).notifier)
          .addComponents(assembly.components);
      MealvanaSnackbar.showSuccess(context, 'Added ${assembly.name}');
    }

    void addIngredient(MealComponent ingredient) {
      ref
          .read(draftMealControllerProvider(logDate).notifier)
          .addComponent(ingredient);
      MealvanaSnackbar.showSuccess(context, 'Added ${ingredient.name}');
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      children: [
        Text(
          'Quick add',
          style: AppTextStyles.sectionTitle.copyWith(
            color: textColor.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...kQuickAssemblies.map(
          (assembly) => Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    assembly.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              title: Text(
                assembly.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${assembly.totalCalories} kcal  ·  '
                'C ${assembly.totalCarbsG.toStringAsFixed(0)}g  '
                'P ${assembly.totalProteinG.toStringAsFixed(0)}g  '
                'F ${assembly.totalFatG.toStringAsFixed(0)}g',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.add_circle_outline, size: 20),
              onTap: () => addAssembly(assembly),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ingredients',
          style: AppTextStyles.sectionTitle.copyWith(
            color: textColor.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...kCommonIngredients.map(
          (ingredient) => Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              title: Text(
                ingredient.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${ingredient.portion} · ${ingredient.calories} kcal  '
                'C ${ingredient.carbG?.toStringAsFixed(0)}g  '
                'P ${ingredient.proteinG?.toStringAsFixed(0)}g  '
                'F ${ingredient.fatG?.toStringAsFixed(0)}g',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.add_circle_outline, size: 20),
              onTap: () => addIngredient(ingredient),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
