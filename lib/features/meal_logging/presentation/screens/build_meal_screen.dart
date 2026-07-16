import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/food_selection/food_search_bar.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../barcode_scanning/application/food_mapping_service.dart';
import '../../../barcode_scanning/application/product_detail_service.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/presentation/widgets/new_activity/shared/activity_name_field.dart';
import '../../../recipes/application/recipe_service.dart';
import '../../../recipes/domain/recipe.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/recipe_ingredient_split.dart';
import '../../domain/saved_meal.dart';
import '../providers/draft_meal_controller.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/common_ingredients_section.dart';
import '../widgets/log_sheet_helpers.dart' show syntheticFromLog;
import '../widgets/manual_component_form.dart';
import '../widgets/meal_component_editor.dart';
import '../widgets/slot_chip_selector.dart';
import '../widgets/unified_meal_search_results.dart';

final DateFormat _timeFmt = DateFormat('h:mm a');

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Opens the dedicated meal-builder surface.
///
/// This is Surface 2 of the meal-logging split (product decision, 2026-07):
/// `LogMealScreen` is quick-log only (one tap = one terminal `meal_logs` row);
/// this screen is where the build-a-meal draft ([draftMealControllerProvider])
/// lives — add multiple foods/ingredients/recipes, edit quantities, and commit
/// the whole thing as a single log entry.
///
/// When [startFrom] is provided (a past log or saved meal reached via
/// "make another meal like this"), the draft is seeded with a **copy** of its
/// components so editing it never mutates the original and never nests one
/// logged meal inside another.
void openBuildMealScreen(
  BuildContext context, {
  required String logDate,
  MealLog? startFrom,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BuildMealScreen(logDate: logDate, startFrom: startFrom),
    ),
  );
}

// ---------------------------------------------------------------------------
// BuildMealScreen
// ---------------------------------------------------------------------------

class BuildMealScreen extends ConsumerStatefulWidget {
  const BuildMealScreen({super.key, required this.logDate, this.startFrom});

  final String logDate;
  final MealLog? startFrom;

  @override
  ConsumerState<BuildMealScreen> createState() => _BuildMealScreenState();
}

class _BuildMealScreenState extends ConsumerState<BuildMealScreen> {
  late final TextEditingController _notesCtrl;
  bool _seededFromStart = false;
  bool _alsoSaveAsFavorite = false;
  bool _showNotes = false;
  bool _isSaving = false;

  DraftMealController get _draft =>
      ref.read(draftMealControllerProvider(widget.logDate).notifier);

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSeedFromStart());
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Seeds the draft with a **copy** of [MealLog.components] from
  /// [BuildMealScreen.startFrom] — "make another meal like this" without
  /// nesting one logged meal inside another. Only the components are copied;
  /// the name is left to auto-derive fresh and the slot/time default as usual.
  void _maybeSeedFromStart() {
    if (_seededFromStart) return;
    _seededFromStart = true;
    final startFrom = widget.startFrom;
    if (startFrom == null) return;
    final components = startFrom.components.isNotEmpty
        ? startFrom.components
        : [syntheticFromLog(startFrom)];
    _draft.addComponents(components);
  }

  void _unfocus() {
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _pickTime(DateTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Time eaten',
    );
    if (picked == null) return;
    _draft.setEatenAt(
      DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _openAddFood() async {
    _unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AddFoodScreen(logDate: widget.logDate),
      ),
    );
    _unfocus();
  }

  Future<void> _openStartFromPicker() async {
    _unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StartFromPickerSheet(
        onPickSaved: (meal) {
          _draft.addComponents(meal.components);
          if (mounted) {
            MealvanaSnackbar.showSuccess(context, 'Started from ${meal.name}');
          }
        },
        onPickRecent: (log) {
          final components = log.components.isNotEmpty
              ? log.components
              : [syntheticFromLog(log)];
          _draft.addComponents(components);
          if (mounted) {
            MealvanaSnackbar.showSuccess(context, 'Started from ${log.name}');
          }
        },
      ),
    );
  }

  Future<void> _logMeal() async {
    _unfocus();
    setState(() => _isSaving = true);
    final ok = await _draft.save(alsoSaveAsFavorite: _alsoSaveAsFavorite);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      MealvanaSnackbar.showSuccess(context, 'Meal logged!');
      Navigator.of(context).pop();
    } else {
      MealvanaSnackbar.showError(
        context,
        'Failed to log meal. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final draft = ref.watch(draftMealControllerProvider(widget.logDate));

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(
          key: ValueKey('build_meal.back_button'),
        ),
        title: Text(
          'Build a Meal',
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
      ),
      body: draft.isEmpty
          ? _buildEmptyState(context, textColor)
          : _buildContent(context, draft, textColor),
      bottomNavigationBar: draft.isEmpty
          ? null
          : SafeArea(top: false, child: _buildBottomBar(context, draft)),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 48,
              color: textColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Start building your meal',
              style: AppTextStyles.subtitle.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add foods one at a time, or start from a saved meal or '
              'recent log.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            KylePrimaryButton(text: '+ Add food', onPressed: _openAddFood),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _openStartFromPicker,
              child: const Text('Start from a saved meal / recent'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DraftMealState draft,
    Color textColor,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        // Auto-generated meal name — editable. Recomputes from the
        // component list until the user types their own (nameManuallySet).
        ActivityNameField(
          key: const ValueKey('build_meal.name_field'),
          value: draft.name ?? '',
          onChanged: _draft.setName,
          label: 'Meal name',
          hint: 'e.g. Lunch',
        ),
        const SizedBox(height: AppSpacing.md),

        Text('Time eaten', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickTime(draft.eatenAt),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                Text(
                  _timeFmt.format(draft.eatenAt),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                Text(
                  'Change',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text('Meal type', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        OptionalSlotChipSelector(
          selectedSlot: draft.slot,
          onSlotSelected: _draft.setSlot,
        ),
        const SizedBox(height: AppSpacing.md),

        // Component list — add/swap/edit/delete. Recipes are added already
        // exploded into per-ingredient lines (see [_AddFoodScreen]), so every
        // line here is independently editable — no nested "recipe" blob.
        MealComponentEditor(
          key: ValueKey(draft.components.length),
          initialComponents: draft.components,
          onComponentsChanged: _draft.updateComponents,
        ),
        const SizedBox(height: AppSpacing.md),

        OutlinedButton.icon(
          onPressed: _openAddFood,
          icon: const Icon(Icons.add),
          label: const Text('Add food'),
        ),
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: () => setState(() => _showNotes = !_showNotes),
          child: Row(
            children: [
              Icon(
                _showNotes
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                _showNotes ? 'Hide notes' : 'Add a note',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (_showNotes) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _draft.setNotes,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, DraftMealState draft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final totals = draft.totals;

    return Material(
      color: bg,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.08,
              ),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${totals.calories} kcal  ·  '
              'C ${totals.carbsG.toStringAsFixed(0)}g  '
              'P ${totals.proteinG.toStringAsFixed(0)}g  '
              'F ${totals.fatG.toStringAsFixed(0)}g',
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.center,
            ),
            CheckboxListTile(
              value: _alsoSaveAsFavorite,
              onChanged: (v) => setState(() => _alsoSaveAsFavorite = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text('Also save as a favorite'),
            ),
            KylePrimaryButton(
              text: 'Log meal',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _logMeal,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Start from a saved meal / recent" picker sheet
// ---------------------------------------------------------------------------

class _StartFromPickerSheet extends ConsumerWidget {
  const _StartFromPickerSheet({
    required this.onPickSaved,
    required this.onPickRecent,
  });

  final ValueChanged<SavedMeal> onPickSaved;
  final ValueChanged<MealLog> onPickRecent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final savedAsync = ref.watch(savedMealsProvider);
    final recentAsync = ref.watch(recentMealsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.blackberry : AppColors.cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Start from...',
                style: AppTextStyles.subtitle.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      'Saved meals',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: textColor.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ..._buildSavedMealTiles(context, savedAsync.asData?.value),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Recent',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: textColor.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ..._buildRecentLogTiles(context, recentAsync.asData?.value),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSavedMealTiles(
    BuildContext context,
    List<SavedMeal>? meals,
  ) {
    if (meals == null || meals.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text('No saved meals yet.', style: AppTextStyles.bodySmall),
        ),
      ];
    }
    return meals
        .map(
          (m) => ListTile(
            dense: true,
            leading: const Icon(Icons.star_outline),
            title: Text(m.name),
            onTap: () {
              Navigator.of(context).pop();
              onPickSaved(m);
            },
          ),
        )
        .toList();
  }

  List<Widget> _buildRecentLogTiles(
    BuildContext context,
    List<MealLog>? logs,
  ) {
    if (logs == null || logs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text('No recent meals.', style: AppTextStyles.bodySmall),
        ),
      ];
    }
    return logs
        .map(
          (l) => ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text(l.name),
            onTap: () {
              Navigator.of(context).pop();
              onPickRecent(l);
            },
          ),
        )
        .toList();
  }
}

// ---------------------------------------------------------------------------
// "+ Add food" screen — ingredients + recipes only, never saved meals.
// ---------------------------------------------------------------------------

enum _AddFoodTab { recipes, common, manual }

/// Search + browse surface pushed by "+ Add food". Every selection adds
/// directly to the draft (no per-item confirm sheet — quantities stay
/// editable afterward in [MealComponentEditor]) and the screen stays open so
/// several items can be added in a row; the user backs out when done.
///
/// Deliberately excludes saved meals/recents — those are start-from only
/// (see [_StartFromPickerSheet]), never nested as a component.
class _AddFoodScreen extends ConsumerStatefulWidget {
  const _AddFoodScreen({required this.logDate});

  final String logDate;

  @override
  ConsumerState<_AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<_AddFoodScreen> {
  _AddFoodTab _activeTab = _AddFoodTab.recipes;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final String _searchControllerKey;

  List<Recipe> _recipes = [];
  bool _recipesLoading = false;

  DraftMealController get _draft =>
      ref.read(draftMealControllerProvider(widget.logDate).notifier);

  @override
  void initState() {
    super.initState();
    _searchControllerKey = 'build_meal_add_food_${widget.logDate}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
      _seedFoodPool();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _unfocus() {
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _loadRecipes() async {
    if (!mounted || _recipesLoading) return;
    setState(() => _recipesLoading = true);
    try {
      final service = ref.read(recipeServiceProvider);
      final userId = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentUser
          ?.id;
      if (userId != null) {
        await service.ensureSynced(userId);
      }
      final all = await service.getAllRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = all;
        _recipesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _recipesLoading = false);
    }
  }

  Future<void> _seedFoodPool() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.userDao.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';

      final results = await Future.wait([
        foodRepository.getPrimaryFoodsForPreferences(),
        foodRepository.getAdditionalFoodsForPreferences(),
        database.foodsDao.getUserFoods(deviceId),
      ]);

      final primary = (results[0] as List<FoodItem>).map(_foodItemToFood);
      final additional = (results[1] as List<FoodItem>).map(_foodItemToFood);
      final userFoods = (results[2] as List<dynamic>)
          .map((uf) => database.foodsDao.convertUserFoodToFoodItem(uf))
          .map(_foodItemToFood)
          .toList();

      if (!mounted) return;
      final searchNotifier = ref.read(
        foodSearchControllerProvider(_searchControllerKey).notifier,
      );
      searchNotifier.setFilter(FoodSearchFilter.generalFirst);
      searchNotifier.updateFoodPool(
        allFoods: [...primary, ...additional, ...userFoods],
        userFoods: userFoods,
      );
    } catch (_) {
      // Non-fatal — search bar still works via catalog + OpenFoodFacts.
    }
  }

  Food _foodItemToFood(FoodItem item) {
    return Food(
      id: item.id,
      name: item.name,
      imageAddress: item.imageAddress,
      description: item.description,
      displayName: item.displayName,
      displayNamePlural: item.displayNamePlural,
      servingSize: item.servingSize,
      servingAmount: item.servingAmount,
      servingUnit: item.servingUnit,
      servingQualifier: item.servingQualifier,
      carbsPerServing: item.carbsPerServing,
      proteinPerServing: item.proteinPerServing,
      fatPerServing: item.fatPerServing,
      sodiumMg: item.sodiumMg,
      caloriesPerServing: item.caloriesPerServing,
      fluidMlPerServing: item.fluidMlPerServing,
      productTypeId: item.productTypeId,
      caffeineMg: item.caffeineMg,
      potassiumMg: item.potassiumMg,
      categories: item.categories.map((c) {
        switch (c) {
          case FoodCategory.beforeRun:
            return 'before_run';
          case FoodCategory.duringRun:
            return 'during_run';
          case FoodCategory.afterRun:
            return 'after_run';
        }
      }).toList(),
    );
  }

  Food _catalogResultToFood(CatalogSearchResult result) {
    return Food(
      id: result.id,
      name: result.title,
      displayName: result.displayName,
      imageAddress: result.imageUrl,
      servingSize: result.servingSize,
      caloriesPerServing: result.caloriesPerServing,
      carbsPerServing: result.carbsG,
      proteinPerServing: result.proteinG,
      fatPerServing: result.fatG,
      sodiumMg: result.sodiumMg,
      productTypeId: result.productTypeId,
    );
  }

  void _onSearchChanged(String query) {
    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .updateSearch(query);
  }

  Future<void> _onBarcodeScan() async {
    _unfocus();
    final result = await context.pushNamed<dynamic>(
      'barcode-scanner',
      extra: {'category': 'add_food', 'context': 'build_meal_add_food'},
    );
    if (result == null || !mounted) return;
    final food = result as Food;
    _addFood(food, food.displayName ?? food.name);
  }

  Future<void> _handleOpenFoodFactsResultTap(dynamic result) async {
    if (!(result.hasValidId as bool)) {
      MealvanaSnackbar.showError(context, 'Cannot load details for this product');
      return;
    }
    _unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        openFoodFactsId: result.id as String,
      );
      if (mounted) Navigator.of(context).pop();
      if (apiProduct == null) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Unable to load product details');
        }
        return;
      }
      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);
      if (!mounted) return;
      _addFood(food, food.displayName ?? food.name);
    } catch (_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to load product details');
      }
    }
  }

  MealComponent _foodComponent(Food food, double servings) {
    final name = food.displayName ?? food.name;
    return MealComponent(
      name: name,
      portion: servings == servings.truncateToDouble()
          ? '${servings.toInt()} ${servings == 1 ? 'serving' : 'servings'}'
          : '${servings.toStringAsFixed(1)} servings',
      calories: food.caloriesPerServing != null
          ? (food.caloriesPerServing! * servings).round()
          : null,
      carbG: food.carbsPerServing != null ? food.carbsPerServing! * servings : null,
      proteinG:
          food.proteinPerServing != null ? food.proteinPerServing! * servings : null,
      fatG: food.fatPerServing != null ? food.fatPerServing! * servings : null,
      sodiumMg: food.sodiumMg != null ? food.sodiumMg! * servings : null,
    );
  }

  void _addFood(Food food, String label) {
    _unfocus();
    _draft.addComponent(_foodComponent(food, 1.0));
    if (mounted) MealvanaSnackbar.showSuccess(context, 'Added $label');
  }

  void _onCatalogTap(CatalogSearchResult result) =>
      _addFood(_catalogResultToFood(result), result.displayName);

  void _onRecipeTap(Recipe recipe) {
    _unfocus();
    final components = explodeRecipeComponents(recipe, 1.0);
    _draft.addComponents(components);
    if (mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'Added ${recipe.name} (${components.length} ingredients)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final searchState = ref.watch(
      foodSearchControllerProvider(_searchControllerKey),
    );
    final isSearching = searchState.searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(
          key: ValueKey('add_food.back_button'),
        ),
        title: Text(
          'Add food',
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              children: [
                FoodSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search foods to add...',
                  onChanged: _onSearchChanged,
                  // No manual-search action — USDA/OFF auto-fire on the
                  // catalog debounce already; the keyboard checkmark just
                  // dismisses the keyboard instead of re-triggering a search.
                  onSearch: (_) => _unfocus(),
                  onBarcodeScan: _onBarcodeScan,
                  onTapOutside: (_) => _unfocus(),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!isSearching)
                  _AddFoodTabBar(
                    activeTab: _activeTab,
                    onTabSelected: (tab) {
                      _unfocus();
                      setState(() => _activeTab = tab);
                    },
                    isDark: isDark,
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          Expanded(
            child: isSearching
                ? UnifiedMealSearchResults(
                    query: searchState.searchQuery,
                    recipes: _recipes,
                    controllerKey: _searchControllerKey,
                    scrollController: _scrollController,
                    // Favorites/recents omitted (null) — start-from only,
                    // never a nested component in the builder.
                    onAddRecipe: _onRecipeTap,
                    onAddIngredient: (ingredient) {
                      _unfocus();
                      _draft.addComponent(ingredient);
                      if (mounted) {
                        MealvanaSnackbar.showSuccess(
                          context,
                          'Added ${ingredient.name}',
                        );
                      }
                    },
                    onFoodTap: (food) => _addFood(food, food.displayName ?? food.name),
                    onCatalogTap: _onCatalogTap,
                    onOpenFoodFactsResultTap: _handleOpenFoodFactsResultTap,
                    onSearchOpenFoodFacts: () {},
                    showOpenFoodFactsButton: false,
                  )
                : _buildTabBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context) {
    switch (_activeTab) {
      case _AddFoodTab.recipes:
        return _AddFoodRecipesList(
          scrollController: _scrollController,
          recipes: _recipes,
          isLoading: _recipesLoading,
          onRecipeTap: _onRecipeTap,
        );
      case _AddFoodTab.common:
        return CommonIngredientsSection(
          scrollController: _scrollController,
          onTapAssembly: (assembly) {
            _unfocus();
            _draft.addComponents(assembly.components);
            if (mounted) {
              MealvanaSnackbar.showSuccess(context, 'Added ${assembly.name}');
            }
          },
          onTapIngredient: (ingredient) {
            _unfocus();
            _draft.addComponent(ingredient);
            if (mounted) {
              MealvanaSnackbar.showSuccess(context, 'Added ${ingredient.name}');
            }
          },
        );
      case _AddFoodTab.manual:
        return ManualComponentForm(
          logDate: widget.logDate,
          scrollController: _scrollController,
        );
    }
  }
}

class _AddFoodTabBar extends StatelessWidget {
  const _AddFoodTabBar({
    required this.activeTab,
    required this.onTabSelected,
    required this.isDark,
  });

  final _AddFoodTab activeTab;
  final ValueChanged<_AddFoodTab> onTabSelected;
  final bool isDark;

  String _label(_AddFoodTab tab) {
    switch (tab) {
      case _AddFoodTab.recipes:
        return 'Recipes';
      case _AddFoodTab.common:
        return 'Common';
      case _AddFoodTab.manual:
        return 'Manual';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: _AddFoodTab.values.map((tab) {
          final isSelected = tab == activeTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.cream : AppColors.blackberry)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    _label(tab),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? AppColors.blackberry : AppColors.cream)
                          : (isDark
                              ? AppColors.cream.withValues(alpha: 0.7)
                              : AppColors.blackberry.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AddFoodRecipesList extends StatelessWidget {
  const _AddFoodRecipesList({
    required this.scrollController,
    required this.recipes,
    required this.isLoading,
    required this.onRecipeTap,
  });

  final ScrollController scrollController;
  final List<Recipe> recipes;
  final bool isLoading;
  final ValueChanged<Recipe> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recipes.isEmpty) {
      return Center(
        child: Text('No recipes found.', style: AppTextStyles.bodyMedium),
      );
    }
    return ListView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      children: recipes.map((recipe) {
        final cal = recipe.nutrition.calories.round();
        final carb = recipe.nutrition.carbohydratesGrams.toStringAsFixed(0);
        final prot = recipe.nutrition.proteinGrams.toStringAsFixed(0);
        final fat = recipe.nutrition.fatGrams.toStringAsFixed(0);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            title: Text(
              recipe.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$cal kcal  ·  C ${carb}g  P ${prot}g  F ${fat}g  ·  '
              '${recipe.ingredients.length} ingredients',
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.add_circle_outline, size: 18),
            onTap: () => onRecipeTap(recipe),
          ),
        );
      }).toList(),
    );
  }
}
