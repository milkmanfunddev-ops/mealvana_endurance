import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../recipes/application/recipe_service.dart';
import '../../../recipes/domain/recipe.dart';
import '../../application/meal_ai_service.dart';
import '../../application/meal_logging_service.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/quick_assembly.dart';
import '../../domain/saved_meal.dart';
import '../providers/meal_log_providers.dart';
import 'log_sheet_helpers.dart';
import 'manual_log_form.dart';
import 'slot_chip_selector.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Opens the tabbed DraggableScrollableSheet for logging a meal.
///
/// Replaces the old [MealLogMethodSheet] five-button list. Titled by date,
/// defaulting to the **Yours** tab.
void showTabbedLogSheet(
  BuildContext context, {
  required String logDate,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TabbedLogSheet(logDate: logDate),
  );
}

// ---------------------------------------------------------------------------
// Sheet tab enum
// ---------------------------------------------------------------------------

enum _LogTab { recent, favorites, search, describe, manual }

extension _LogTabLabel on _LogTab {
  String get label {
    switch (this) {
      case _LogTab.recent:
        return 'Recent';
      case _LogTab.favorites:
        return 'Favorites';
      case _LogTab.search:
        return 'Search';
      case _LogTab.describe:
        return 'Describe';
      case _LogTab.manual:
        return 'Manual';
    }
  }
}

// ---------------------------------------------------------------------------
// TabbedLogSheet
// ---------------------------------------------------------------------------

/// The DraggableScrollableSheet for meal logging
/// (Recent · Favorites · Search · Describe · Manual).
class TabbedLogSheet extends ConsumerStatefulWidget {
  const TabbedLogSheet({super.key, required this.logDate});

  final String logDate;

  @override
  ConsumerState<TabbedLogSheet> createState() => _TabbedLogSheetState();
}

class _TabbedLogSheetState extends ConsumerState<TabbedLogSheet> {
  _LogTab _activeTab = _LogTab.recent;
  bool _recipesLoaded = false;

  void _selectTab(_LogTab tab) {
    setState(() => _activeTab = tab);
    if (tab == _LogTab.search && !_recipesLoaded) {
      setState(() => _recipesLoaded = true);
    }
  }

  // -- shared success handler used by all four tabs -------------------------

  void _onLogged(BuildContext ctx) {
    Navigator.of(ctx).pop(); // close sheet
    MealvanaSnackbar.showSuccess(ctx, 'Meal logged!');
  }

  void _onLogError(BuildContext ctx) {
    MealvanaSnackbar.showError(ctx, 'Failed to log meal. Please try again.');
  }

  // --------------------------------------------------------------------------

  String _sheetTitle() {
    try {
      final date = DateTime.parse(widget.logDate);
      final today = DateTime.now();
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      return isToday ? 'Log a Meal' : 'Log — ${DateFormat('MMM d').format(date)}';
    } catch (_) {
      return 'Log a Meal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              // ── Static header (drag handle + title + tabs) ───────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _sheetTitle(),
                      style: AppTextStyles.pageTitle.copyWith(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TabBar(
                      activeTab: _activeTab,
                      onTabSelected: _selectTab,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
              // ── Scrollable tab body ──────────────────────────────────────
              Expanded(
                child: _buildTabBody(ctx, scrollController, isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBody(
    BuildContext ctx,
    ScrollController scrollController,
    bool isDark,
  ) {
    switch (_activeTab) {
      case _LogTab.recent:
        return _RecentTab(
          logDate: widget.logDate,
          scrollController: scrollController,
          onLogged: () => _onLogged(ctx),
          onLogError: () => _onLogError(ctx),
        );
      case _LogTab.favorites:
        return _FavoritesTab(
          logDate: widget.logDate,
          scrollController: scrollController,
          onLogged: () => _onLogged(ctx),
          onLogError: () => _onLogError(ctx),
        );
      case _LogTab.search:
        return _SearchTab(
          logDate: widget.logDate,
          scrollController: scrollController,
          shouldLoad: _recipesLoaded,
          onLogged: () => _onLogged(ctx),
          onLogError: () => _onLogError(ctx),
        );
      case _LogTab.describe:
        return _AiTab(
          logDate: widget.logDate,
          scrollController: scrollController,
          onNavigateAway: () => Navigator.of(ctx).pop(),
        );
      case _LogTab.manual:
        return _ManualTab(
          logDate: widget.logDate,
          scrollController: scrollController,
          onLogged: () => _onLogged(ctx),
          onLogError: () => _onLogError(ctx),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Tab bar
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.activeTab,
    required this.onTabSelected,
    required this.isDark,
  });

  final _LogTab activeTab;
  final ValueChanged<_LogTab> onTabSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: _LogTab.values.map((tab) {
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                  ? AppColors.blackberry
                                  : AppColors.cream)
                              : (isDark
                                  ? AppColors.cream.withValues(alpha: 0.7)
                                  : AppColors.blackberry
                                      .withValues(alpha: 0.6)),
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Recent tab — re-log a recently eaten meal
// ---------------------------------------------------------------------------

class _RecentTab extends ConsumerWidget {
  const _RecentTab({
    required this.logDate,
    required this.scrollController,
    required this.onLogged,
    required this.onLogError,
  });

  final String logDate;
  final ScrollController scrollController;
  final VoidCallback onLogged;
  final VoidCallback onLogError;

  void _logRecent(BuildContext context, WidgetRef ref, MealLog log) {
    showSlotPickerSheet(context, onSelected: (slot) async {
      final component = syntheticFromLog(log);
      await ref.read(mealLogControllerProvider.notifier).logFromComponents(
            name: log.name,
            slot: slot,
            logDate: logDate,
            source: MealLogSource.saved,
            components: [component],
          );
      if (!context.mounted) return;
      final s = ref.read(mealLogControllerProvider);
      s is AsyncData ? onLogged() : onLogError();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentMealsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return recentAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return _EmptyTabMessage(
            icon: Icons.history,
            message: 'No recent meals yet.\nMeals you log will show up here.',
            textColor: textColor,
          );
        }
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: logs
              .map((log) => _RecentMealRow(
                    log: log,
                    onTap: () => _logRecent(context, ref, log),
                    isDark: isDark,
                  ))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Favorites tab — re-log a meal saved as a favorite
// ---------------------------------------------------------------------------

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({
    required this.logDate,
    required this.scrollController,
    required this.onLogged,
    required this.onLogError,
  });

  final String logDate;
  final ScrollController scrollController;
  final VoidCallback onLogged;
  final VoidCallback onLogError;

  void _logFavorite(BuildContext context, WidgetRef ref, SavedMeal meal) {
    showSlotPickerSheet(context, onSelected: (slot) async {
      await ref.read(mealLogControllerProvider.notifier).logSavedMeal(
            savedMeal: meal,
            slot: slot,
            logDate: logDate,
          );
      if (!context.mounted) return;
      final s = ref.read(mealLogControllerProvider);
      s is AsyncData ? onLogged() : onLogError();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(savedMealsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return favoritesAsync.when(
      data: (meals) {
        if (meals.isEmpty) {
          return _EmptyTabMessage(
            icon: Icons.star_outline,
            message:
                'No favorites yet.\nTap the ☆ on a logged meal to save it here.',
            textColor: textColor,
          );
        }
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: meals
              .map((meal) => _SavedMealRow(
                    meal: meal,
                    onTap: () => _logFavorite(context, ref, meal),
                    onDelete: () => ref
                        .read(mealLogControllerProvider.notifier)
                        .deleteSavedMeal(meal.id),
                    isDark: isDark,
                  ))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Centered icon + message shown when a tab has no items to list.
class _EmptyTabMessage extends StatelessWidget {
  const _EmptyTabMessage({
    required this.icon,
    required this.message,
    required this.textColor,
  });

  final IconData icon;
  final String message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: textColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manual tab — inline manual macro entry form
// ---------------------------------------------------------------------------

class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.logDate,
    required this.scrollController,
    required this.onLogged,
    required this.onLogError,
  });

  final String logDate;
  final ScrollController scrollController;
  final VoidCallback onLogged;
  final VoidCallback onLogError;

  @override
  Widget build(BuildContext context) {
    return ManualLogForm(
      logDate: logDate,
      scrollController: scrollController,
      onLogged: onLogged,
      onLogError: onLogError,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.textColor});

  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.sectionTitle.copyWith(
        color: textColor.withValues(alpha: 0.75),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _SavedMealRow extends StatelessWidget {
  const _SavedMealRow({
    required this.meal,
    required this.onTap,
    required this.onDelete,
    required this.isDark,
  });

  final SavedMeal meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          child: const Icon(Icons.star_outline, size: 16),
        ),
        title: Text(
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _macroLine(context, meal.calories, meal.carbsG, meal.proteinG, meal.fatG),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RecentMealRow extends StatelessWidget {
  const _RecentMealRow({
    required this.log,
    required this.onTap,
    required this.isDark,
  });

  final MealLog log;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          child: const Icon(Icons.history, size: 16),
        ),
        title: Text(
          log.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _macroLine(context, log.calories, log.carbsG, log.proteinG, log.fatG),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}

/// Compact macro subtitle — null means ListTile omits the line.
Widget? _macroLine(
  BuildContext context,
  int? cal,
  double? carb,
  double? prot,
  double? fat,
) {
  final parts = [
    if (cal != null) '$cal kcal',
    if (carb != null) 'C ${carb.toStringAsFixed(0)}g',
    if (prot != null) 'P ${prot.toStringAsFixed(0)}g',
    if (fat != null) 'F ${fat.toStringAsFixed(0)}g',
  ];
  if (parts.isEmpty) return null;
  return Text(
    parts.join('  ·  '),
    style: Theme.of(context).textTheme.bodySmall,
    overflow: TextOverflow.ellipsis,
  );
}

// ---------------------------------------------------------------------------
// Recipes tab
// ---------------------------------------------------------------------------

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab({
    required this.logDate,
    required this.scrollController,
    required this.shouldLoad,
    required this.onLogged,
    required this.onLogError,
  });

  final String logDate;
  final ScrollController scrollController;
  final bool shouldLoad;
  final VoidCallback onLogged;
  final VoidCallback onLogError;

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  List<Recipe> _recipes = [];
  List<Recipe> _filtered = [];
  RecipeType? _selectedType;
  bool _isLoading = false;
  bool _loadStarted = false;

  static const List<RecipeType> _chipOrder = [
    RecipeType.breakfast,
    RecipeType.mains,
    RecipeType.snacks,
    RecipeType.workoutFuel,
    RecipeType.recovery,
  ];

  @override
  void didUpdateWidget(_SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldLoad && !_loadStarted) {
      _loadStarted = true;
      _loadRecipes();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoad) {
      _loadStarted = true;
      // defer to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecipes());
    }
  }

  Future<void> _loadRecipes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
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
        _filtered = all;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(RecipeType? type) {
    setState(() {
      _selectedType = type;
      _filtered = type == null
          ? _recipes
          : _recipes.where((r) => r.type == type).toList();
    });
  }

  void _showLogSheet(Recipe recipe) {
    double servings = 1.0;
    MealSlot slot = MealSlot.breakfast;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final scaledCal = (recipe.nutrition.calories * servings).round();
          final scaledCarb =
              (recipe.nutrition.carbohydratesGrams * servings).toStringAsFixed(0);
          final scaledProt =
              (recipe.nutrition.proteinGrams * servings).toStringAsFixed(0);
          final scaledFat =
              (recipe.nutrition.fatGrams * servings).toStringAsFixed(0);

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.blackberry : AppColors.cream,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Text(recipe.name,
                      style: AppTextStyles.subtitle, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$scaledCal kcal  ·  C ${scaledCarb}g  P ${scaledProt}g  F ${scaledFat}g',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Servings',
                      style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: servings > 0.5
                            ? () => setModalState(() =>
                                servings = (servings - 0.5).clamp(0.5, 10.0))
                            : null,
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          servings == servings.truncateToDouble()
                              ? servings.toInt().toString()
                              : servings.toStringAsFixed(1),
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: servings < 10
                            ? () => setModalState(() =>
                                servings = (servings + 0.5).clamp(0.5, 10.0))
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Meal type',
                      style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SlotChipSelector(
                    selectedSlot: slot,
                    onSlotSelected: (s) => setModalState(() => slot = s),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  KylePrimaryButton(
                    text: 'Log Recipe',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _logRecipe(recipe, servings, slot);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _logRecipe(Recipe recipe, double servings, MealSlot slot) async {
    final params = RecipeLogParams(
      recipeId: recipe.id,
      recipeName: recipe.name,
      servings: servings,
      caloriesPerServing: recipe.nutrition.calories,
      carbsGPerServing: recipe.nutrition.carbohydratesGrams,
      proteinGPerServing: recipe.nutrition.proteinGrams,
      fatGPerServing: recipe.nutrition.fatGrams,
      sodiumMgPerServing: recipe.nutrition.sodiumMilligrams,
    );
    await ref
        .read(mealLogControllerProvider.notifier)
        .logRecipe(params: params, slot: slot, logDate: widget.logDate);

    if (!mounted) return;
    final s = ref.read(mealLogControllerProvider);
    if (s is AsyncData) {
      widget.onLogged();
    } else {
      widget.onLogError();
    }
  }

  void _logAssembly(QuickAssembly assembly) {
    showSlotPickerSheet(context, onSelected: (slot) async {
      await ref.read(mealLogControllerProvider.notifier).logFromComponents(
            name: assembly.name,
            slot: slot,
            logDate: widget.logDate,
            source: MealLogSource.manual,
            components: assembly.components,
          );
      if (!mounted) return;
      final s = ref.read(mealLogControllerProvider);
      if (s is AsyncData) {
        widget.onLogged();
      } else {
        widget.onLogError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    if (!widget.shouldLoad || (_isLoading && _recipes.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 4),
            children: [
              _TypeChip(
                label: 'All',
                selected: _selectedType == null,
                onTap: () => _applyFilter(null),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              ..._chipOrder.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _TypeChip(
                    label: t.displayLabel,
                    selected: _selectedType == t,
                    onTap: () => _applyFilter(t),
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            children: [
              // Quick add — preset assemblies, only on the unfiltered view.
              if (_selectedType == null) ...[
                _SectionHeader(label: 'Quick add', textColor: textColor),
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
                          child: Text(assembly.emoji,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      title: Text(
                        assembly.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: _macroLine(
                        context,
                        assembly.totalCalories,
                        assembly.totalCarbsG,
                        assembly.totalProteinG,
                        assembly.totalFatG,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => _logAssembly(assembly),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionHeader(label: 'Recipes', textColor: textColor),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (_filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text('No recipes found.',
                        style: AppTextStyles.bodyMedium),
                  ),
                )
              else
                ..._filtered.map((recipe) {
                  final cal = recipe.nutrition.calories.round();
                  final carb =
                      recipe.nutrition.carbohydratesGrams.toStringAsFixed(0);
                  final prot = recipe.nutrition.proteinGrams.toStringAsFixed(0);
                  final fat = recipe.nutrition.fatGrams.toStringAsFixed(0);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading: _RecipeThumbnail(
                        imageUrl: recipe.imageUrl,
                        type: recipe.type,
                        size: 40,
                      ),
                      title: Text(
                        recipe.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$cal kcal  ·  C ${carb}g  P ${prot}g  F ${fat}g',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => _showLogSheet(recipe),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact recipe thumbnail (40 px) with category color fallback.
class _RecipeThumbnail extends StatelessWidget {
  const _RecipeThumbnail({
    required this.imageUrl,
    required this.type,
    this.size = 40,
  });

  final String? imageUrl;
  final RecipeType type;
  final double size;

  Color _color() {
    switch (type) {
      case RecipeType.breakfast:
        return Colors.orange.shade300;
      case RecipeType.mains:
        return Colors.teal.shade300;
      case RecipeType.snacks:
        return Colors.amber.shade300;
      case RecipeType.workoutFuel:
        return Colors.blue.shade300;
      case RecipeType.recovery:
        return Colors.purple.shade300;
    }
  }

  IconData _icon() {
    switch (type) {
      case RecipeType.breakfast:
        return Icons.free_breakfast;
      case RecipeType.mains:
        return Icons.restaurant;
      case RecipeType.snacks:
        return Icons.cookie;
      case RecipeType.workoutFuel:
        return Icons.directions_run;
      case RecipeType.recovery:
        return Icons.restore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_icon(), color: color, size: size * 0.5),
    );
    if (imageUrl == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, p) {
          if (p == null) return child;
          return Container(
            width: size,
            height: size,
            color: color.withValues(alpha: 0.15),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.electrolyte
              : (isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.blackberry
                : (isDark ? Colors.white : AppColors.blackberry),
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI tab
// ---------------------------------------------------------------------------

class _AiTab extends ConsumerStatefulWidget {
  const _AiTab({
    required this.logDate,
    required this.scrollController,
    required this.onNavigateAway,
  });

  final String logDate;
  final ScrollController scrollController;
  final VoidCallback onNavigateAway;

  @override
  ConsumerState<_AiTab> createState() => _AiTabState();
}

class _AiTabState extends ConsumerState<_AiTab> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isAnalyzing = true);
    try {
      final service = ref.read(mealAiServiceProvider);
      final result = await service.describeMeal(_ctrl.text.trim());
      if (!mounted) return;
      // Capture router before closing the sheet.
      final router = GoRouter.of(context);
      widget.onNavigateAway();
      router.push('/meal-log/review', extra: {
        'result': result,
        'source': 'describe',
        'logDate': widget.logDate,
        'photoPath': null,
      });
    } on MealAiException catch (e) {
      if (mounted) MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(
            context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 1200);
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Could not access the camera or gallery.');
      }
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _isAnalyzing = true);
    try {
      final service = ref.read(mealAiServiceProvider);
      MealPhotoAnalysis analysis;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final parts = file.name.split('.');
        final ext = (parts.length > 1 ? parts.last : 'jpg').toLowerCase();
        analysis = await service.analyzePhotoBytes(bytes, extension: ext);
      } else {
        analysis = await service.analyzePhoto(File(file.path));
      }
      if (!mounted) return;
      // Capture router before closing the sheet.
      final router = GoRouter.of(context);
      widget.onNavigateAway();
      router.push('/meal-log/review', extra: {
        'result': analysis.result,
        'source': 'photo',
        'logDate': widget.logDate,
        'photoPath': analysis.storagePath,
      });
    } on MealAiException catch (e) {
      if (mounted) MealvanaSnackbar.showError(context, e.userMessage);
    } catch (_) {
      if (mounted) {
        MealvanaSnackbar.showError(
            context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Stack(
      children: [
        ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          children: [
            Text(
              'Describe what you ate and Jade will estimate the macros.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _ctrl,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isAnalyzing,
                decoration: const InputDecoration(
                  labelText: 'What did you eat?',
                  hintText:
                      'e.g. Oatmeal with blueberries, a tablespoon of honey, large coffee with oat milk.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 5)
                        ? 'Please describe your meal'
                        : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            KylePrimaryButton(
              text: 'Analyze',
              isLoading: _isAnalyzing,
              onPressed: _isAnalyzing ? null : _analyze,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!kIsWeb)
              Row(
                children: [
                  Expanded(
                    child: _OutlineButton(
                      label: 'Camera',
                      emoji: '📷',
                      onTap: _isAnalyzing
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _OutlineButton(
                      label: 'Gallery',
                      emoji: '🖼',
                      onTap: _isAnalyzing
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      isDark: isDark,
                    ),
                  ),
                ],
              )
            else
              _OutlineButton(
                label: 'Choose Photo',
                emoji: '🖼',
                onTap:
                    _isAnalyzing ? null : () => _pickPhoto(ImageSource.gallery),
                isDark: isDark,
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
        if (_isAnalyzing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Jade is thinking...',
                    style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Side-by-side outline button for Camera / Gallery.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.emoji,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final String emoji;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

