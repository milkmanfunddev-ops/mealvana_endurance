import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_catalog_controller.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import '../../domain/meal_type.dart';
import '../widgets/meal_card.dart';
import '../widgets/meal_rail.dart';

/// The Meals tab (05 §4): search + filter popover, the Recents / My Foods /
/// Assemblies / Recipes rails (flat results while filtering), and the Vana
/// CTA row. Tapping any meal opens `/food/meals/:id`.
class MealsTab extends ConsumerStatefulWidget {
  const MealsTab({super.key});

  @override
  ConsumerState<MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends ConsumerState<MealsTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final catalog =
        ref.watch(mealCatalogControllerProvider).value ??
        const MealCatalogState();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    void openMeal(MealRef meal) => context.push('/food/meals/${meal.id}');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('meal_planning.search_field'),
                  controller: _searchController,
                  onChanged: ref
                      .read(mealCatalogControllerProvider.notifier)
                      .setQuery,
                  style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                  decoration: InputDecoration(
                    hintText: content.getValue(ContentKeys.mpMealsSearchHint),
                    hintStyle: AppTextStyles.bodySmall.copyWith(
                      color: secondary,
                    ),
                    prefixIcon: Icon(Icons.search, color: secondary, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.blackberryLight
                        : AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: const ValueKey('meal_planning.filter_button'),
                onPressed: () => _openFilterSheet(context),
                icon: FaIcon(
                  FontAwesomeIcons.sliders,
                  color:
                      catalog.mealType != null || catalog.kind != null
                      ? accent
                      : secondary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalog.isFiltering
              ? catalog.isSearching
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.electrolyte,
                        ),
                      )
                    : catalog.results.isEmpty
                    ? Center(
                        child: Text(
                          content.getValue(ContentKeys.mpSearchEmpty),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: secondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: catalog.results.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xs,
                          ),
                          child: MealCard(
                            meal: catalog.results[i],
                            onTap: () => openMeal(catalog.results[i]),
                          ),
                        ),
                      )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    MealRail(
                      title: content.getValue(ContentKeys.mpRailRecents),
                      meals: [
                        for (final r in catalog.recents) r.meal,
                      ],
                      onTapMeal: openMeal,
                      seeAllLabel: content.getValue(ContentKeys.mpSeeAll),
                      onSeeAll: () => context.push('/food/meals/recents'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MealRail(
                      title: content.getValue(ContentKeys.mpRailMyFoods),
                      meals: catalog.myFoods,
                      onTapMeal: openMeal,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MealRail(
                      title: content.getValue(ContentKeys.mpRailAssemblies),
                      meals: catalog.assemblies,
                      onTapMeal: openMeal,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MealRail(
                      title: content.getValue(ContentKeys.mpRailRecipes),
                      meals: catalog.recipes,
                      onTapMeal: openMeal,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _VanaCtaRow(onTap: () => context.push('/vana?c=new&mode=meal_planning')),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _openFilterSheet(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final controller = ref.read(mealCatalogControllerProvider.notifier);
    final state = ref.read(mealCatalogControllerProvider).value;

    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.cream : AppColors.blackberry;
        final secondary = textColor.withValues(alpha: 0.65);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.getValue(ContentKeys.mpFilterTitle),
                  style: AppTextStyles.sectionTitle.copyWith(color: textColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  content.getValue(ContentKeys.mpFilterAnyType),
                  style: AppTextStyles.smallLabel.copyWith(color: secondary),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final type in MealType.values)
                      FilterChip(
                        label: Text(type.wire),
                        selected: state?.mealType == type,
                        onSelected: (on) =>
                            controller.setMealType(on ? type : null),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  content.getValue(ContentKeys.mpFilterAssemblies),
                  style: AppTextStyles.smallLabel.copyWith(color: secondary),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    FilterChip(
                      label: Text(content.getValue(
                        ContentKeys.mpFilterAssemblies,
                      )),
                      selected: state?.kind == MealKind.assembly,
                      onSelected: (on) =>
                          controller.setKind(on ? MealKind.assembly : null),
                    ),
                    FilterChip(
                      label: Text(content.getValue(
                        ContentKeys.mpFilterRecipes,
                      )),
                      selected: state?.kind == MealKind.recipe,
                      onSelected: (on) =>
                          controller.setKind(on ? MealKind.recipe : null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.clearFilters();
                        _searchController.clear();
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        content.getValue(ContentKeys.mpFilterClear),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: secondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(
                        content.getValue(ContentKeys.mpCookDone),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VanaCtaRow extends ConsumerWidget {
  const _VanaCtaRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Center(
      child: GestureDetector(
        key: const ValueKey('meal_planning.vana_cta'),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.wandMagicSparkles, color: accent, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Text(
              content.getValue(ContentKeys.mpVanaCta),
              style: AppTextStyles.bodySmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
