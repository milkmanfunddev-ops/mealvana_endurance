import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/meal_catalog_controller.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_source.dart';
import '../../domain/meal_type.dart';
import 'meal_add_button.dart';
import 'meal_card.dart';
import 'meal_rail.dart';

/// The catalog browser shared by the Food → Meals tab and the Vana chat's
/// "Browse meals" screen (05 §4): the search / filter tool buttons, the
/// Recents / My Foods / Assemblies / Recipes rails (flat results while
/// filtering), all read off [MealCatalogController].
///
/// Search is collapsed behind its tool button and expands into a search bar
/// beneath the tools, as in the prototype — the rails, not a text field, are
/// what the browser opens on.
///
/// With [onAddMeal] every card carries a [MealAddButton] (the browse
/// screen's Add ribbon — Xuan's v5 prototype); ids in [addedIds] render
/// ticked. Without it the cards are plain (the Meals tab).
class MealCatalogBrowser extends ConsumerStatefulWidget {
  const MealCatalogBrowser({
    super.key,
    required this.onOpenMeal,
    this.onSeeAllRecents,
    this.onAddMeal,
    this.addedIds = const {},
  });

  /// Tap on a card body — opens the meal's detail.
  final ValueChanged<MealRef> onOpenMeal;

  /// Recents "See all"; the rail's action hides when null.
  final VoidCallback? onSeeAllRecents;

  /// Add-to-plan affordance on every card when set.
  final ValueChanged<MealRef>? onAddMeal;

  /// Meal ids already added this session — their Add button shows ticked.
  final Set<String> addedIds;

  @override
  ConsumerState<MealCatalogBrowser> createState() => _MealCatalogBrowserState();
}

class _MealCatalogBrowserState extends ConsumerState<MealCatalogBrowser> {
  final _searchController = TextEditingController();
  final _filterButtonKey = GlobalKey();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchController.clear();
      ref.read(mealCatalogControllerProvider.notifier).setQuery('');
    }
  }

  /// The Add button for [meal], or null when this browser has no add flow.
  Widget? _addButton(ContentService content, MealRef meal) {
    final onAdd = widget.onAddMeal;
    if (onAdd == null) return null;
    final added = widget.addedIds.contains(meal.id);
    return MealAddButton(
      key: ValueKey('meal_planning.browse_add_${meal.id}'),
      added: added,
      tooltip: content.getValue(
        added ? ContentKeys.mpBrowseAdded : ContentKeys.mpBrowseAdd,
      ),
      onTap: added ? null : () => onAdd(meal),
    );
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

    final filterActive = catalog.mealType != null || catalog.kind != null;

    MealRail rail(
      String title,
      List<MealRef> meals, {
      String? seeAllLabel,
      VoidCallback? onSeeAll,
    }) => MealRail(
      title: title,
      meals: meals,
      onTapMeal: widget.onOpenMeal,
      seeAllLabel: seeAllLabel,
      onSeeAll: onSeeAll,
      actionBuilder: widget.onAddMeal == null
          ? null
          : (meal) => _addButton(content, meal),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ToolButton(
                    key: const ValueKey('meal_planning.search_button'),
                    icon: Icons.search,
                    isOn: _searchOpen || catalog.query.isNotEmpty,
                    onTap: _toggleSearch,
                    tooltip: content.getValue(ContentKeys.mpMealsSearchHint),
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    key: const ValueKey('meal_planning.filter_button'),
                    buttonKey: _filterButtonKey,
                    icon: Icons.filter_list,
                    isOn: filterActive,
                    onTap: () => _openFilterMenu(context),
                    tooltip: content.getValue(ContentKeys.mpFilterTitle),
                  ),
                ],
              ),
              if (_searchOpen) ...[
                const SizedBox(height: AppSpacing.sm),
                _SearchBar(
                  controller: _searchController,
                  hint: content.getValue(ContentKeys.mpMealsSearchHint),
                  onChanged: ref
                      .read(mealCatalogControllerProvider.notifier)
                      .setQuery,
                ),
              ],
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
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MealCard(
                            meal: catalog.results[i],
                            onTap: () => widget.onOpenMeal(catalog.results[i]),
                            trailing: _addButton(content, catalog.results[i]),
                          ),
                        ),
                      )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    rail(
                      content.getValue(ContentKeys.mpRailRecents),
                      [for (final r in catalog.recents) r.meal],
                      seeAllLabel: widget.onSeeAllRecents == null
                          ? null
                          : content.getValue(ContentKeys.mpSeeAll),
                      onSeeAll: widget.onSeeAllRecents,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    rail(
                      content.getValue(ContentKeys.mpRailMyFoods),
                      catalog.myFoods,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    rail(
                      content.getValue(ContentKeys.mpRailAssemblies),
                      catalog.assemblies,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    rail(
                      content.getValue(ContentKeys.mpRailRecipes),
                      catalog.recipes,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
        ),
      ],
    );
  }

  /// The filter popover: All · the four meal types · No recipe · Recipes,
  /// anchored under the filter tool button (prototype `.v-filter-pop`).
  Future<void> _openFilterMenu(BuildContext context) async {
    final content = ref.read(contentServiceProvider);
    final controller = ref.read(mealCatalogControllerProvider.notifier);
    final state =
        ref.read(mealCatalogControllerProvider).value ??
        const MealCatalogState();

    final box =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 6,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.blackberry
          : AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.cream
                      : AppColors.blackberry)
                  .withValues(alpha: 0.18),
        ),
      ),
      items: [
        _filterItem(
          context,
          'all',
          content.getValue(ContentKeys.mpFilterAnyType),
          state.mealType == null && state.kind == null,
        ),
        for (final type in MealType.values)
          _filterItem(
            context,
            'type:${type.wire}',
            SlotLabels.of(content, type),
            state.mealType == type,
          ),
        const PopupMenuDivider(),
        _filterItem(
          context,
          'kind:assembly',
          content.getValue(ContentKeys.mpFilterNoRecipe),
          state.kind == MealKind.assembly,
        ),
        _filterItem(
          context,
          'kind:recipe',
          content.getValue(ContentKeys.mpFilterRecipes),
          state.kind == MealKind.recipe,
        ),
      ],
    );

    if (selected == null) return;
    if (selected == 'all') {
      controller.clearFilters();
      return;
    }
    if (selected.startsWith('type:')) {
      final type = MealType.values.firstWhere(
        (t) => t.wire == selected.substring(5),
      );
      controller.setMealType(state.mealType == type ? null : type);
      return;
    }
    final kind = selected == 'kind:assembly'
        ? MealKind.assembly
        : MealKind.recipe;
    controller.setKind(state.kind == kind ? null : kind);
  }

  PopupMenuItem<String> _filterItem(
    BuildContext context,
    String value,
    String label,
    bool selected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: selected
              ? (isDark ? AppColors.electrolyte : AppColors.electrolyteDark)
              : textColor,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Meal-type labels, resolved from content. Kept here so the filter popover
/// and the slot chips read from the same keys.
abstract final class SlotLabels {
  static String of(ContentService content, MealType type) => switch (type) {
    MealType.breakfast => content.getValue(ContentKeys.mpMealTypeBreakfast),
    MealType.lunch => content.getValue(ContentKeys.mpMealTypeLunch),
    MealType.dinner => content.getValue(ContentKeys.mpMealTypeDinner),
    MealType.snack => content.getValue(ContentKeys.mpMealTypeSnack),
  };
}

/// A 40pt circular tool button; filled electrolyte when its tool is active
/// (prototype `.v-toolbtn`).
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.isOn,
    required this.onTap,
    required this.tooltip,
    this.buttonKey,
  });

  final IconData icon;
  final bool isOn;
  final VoidCallback onTap;
  final String tooltip;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return Tooltip(
      message: tooltip,
      child: Material(
        key: buttonKey,
        color: isOn ? AppColors.electrolyte : surface,
        shape: CircleBorder(
          side: isOn
              ? BorderSide.none
              : BorderSide(color: textColor.withValues(alpha: 0.2), width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 18,
              color: isOn ? AppColors.blackberry : textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// The expanded search field (prototype `.v-searchbar`).
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: textColor.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('meal_planning.search_field'),
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: textColor.withValues(alpha: 0.4),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
