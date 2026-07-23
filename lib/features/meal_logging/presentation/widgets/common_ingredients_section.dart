import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/common_ingredients.dart';
import '../../domain/meal_component.dart';
import '../../domain/quick_assembly.dart';

/// "Common" tab body: curated quick-add combos ([kQuickAssemblies]) plus the
/// single-ingredient library ([kCommonIngredients]).
///
/// Purely presentational — [onTapAssembly]/[onTapIngredient] decide what a tap
/// means. `LogMealScreen`'s Common tab quick-logs a terminal `meal_logs` row
/// per tap; `BuildMealScreen`'s "+ Add food" Common tab adds the tapped item
/// to the in-progress draft instead. Neither behavior lives here.
class CommonIngredientsSection extends StatelessWidget {
  const CommonIngredientsSection({
    super.key,
    required this.scrollController,
    required this.onTapAssembly,
    required this.onTapIngredient,
  });

  final ScrollController scrollController;
  final ValueChanged<QuickAssembly> onTapAssembly;
  final ValueChanged<MealComponent> onTapIngredient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return ListView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.add_circle_outline, size: 20),
              onTap: () => onTapAssembly(assembly),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              onTap: () => onTapIngredient(ingredient),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
