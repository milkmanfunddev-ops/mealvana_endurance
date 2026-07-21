import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../recipes/application/recipe_service.dart';
import '../../../recipes/domain/recipe.dart';
import '../../application/meal_logging_service.dart';
import '../../domain/log_date_time.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/slot_chip_selector.dart';

/// Screen for selecting a recipe and logging it with a chosen number of servings.
///
/// Route: `/meal-log/recipe`
/// Extras: `{ 'logDate': String }`
class RecipePickerScreen extends ConsumerStatefulWidget {
  const RecipePickerScreen({super.key});

  @override
  ConsumerState<RecipePickerScreen> createState() => _RecipePickerScreenState();
}

class _RecipePickerScreenState extends ConsumerState<RecipePickerScreen> {
  List<Recipe> _recipes = [];
  List<Recipe> _filtered = [];
  RecipeType? _selectedType;
  bool _isLoading = true;
  String? _logDate;
  bool _initialized = false;

  /// Chip display order: All, Breakfast, Mains, Snacks, Workout Fuel, Recovery.
  static const List<RecipeType> _chipOrder = [
    RecipeType.breakfast,
    RecipeType.mains,
    RecipeType.snacks,
    RecipeType.workoutFuel,
    RecipeType.recovery,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      _logDate = extra?['logDate'] as String? ?? _todayDateString();
      _initialized = true;
      _loadRecipes();
    }
  }

  static String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadRecipes() async {
    try {
      final service = ref.read(recipeServiceProvider);
      final userId =
          ref.read(appExternalDepsProvider).supabaseClient.auth.currentUser?.id;
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

  void _applyTypeFilter(RecipeType? type) {
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
          final scaledCal =
              (recipe.nutrition.calories * servings).round();
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
                  Text(
                    recipe.name,
                    style: AppTextStyles.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$scaledCal kcal  ·  C ${scaledCarb}g  P ${scaledProt}g  F ${scaledFat}g',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Servings stepper
                  Text(
                    'Servings',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: servings > 0.5
                            ? () => setModalState(
                                () => servings = (servings - 0.5).clamp(0.5, 10.0))
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
                            ? () => setModalState(
                                () => servings = (servings + 0.5).clamp(0.5, 10.0))
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Slot selector
                  Text(
                    'Meal type',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
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

  Future<void> _logRecipe(
      Recipe recipe, double servings, MealSlot slot) async {
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
        .logRecipe(
          params: params,
          slot: slot,
          logDate: _logDate!,
          eatenAt: eatenAtForLogDate(_logDate!),
        );

    if (!mounted) return;
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      MealvanaSnackbar.showSuccess(context, 'Recipe logged!');
      context.go('/main');
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(context, 'Failed to log recipe.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: const Text('Choose a Recipe'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Type filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 6),
              children: [
                _TypeChip(
                  label: 'All',
                  selected: _selectedType == null,
                  onTap: () => _applyTypeFilter(null),
                ),
                const SizedBox(width: 8),
                ..._chipOrder.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TypeChip(
                      label: t.displayLabel,
                      selected: _selectedType == t,
                      onTap: () => _applyTypeFilter(t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No recipes found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final recipe = _filtered[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: _RecipePickerThumbnail(
                                imageUrl: recipe.imageUrl,
                                type: recipe.type,
                              ),
                              title: Text(recipe.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${recipe.nutrition.calories.round()} kcal/serving  ·  '
                                'C ${recipe.nutrition.carbohydratesGrams.toStringAsFixed(0)}g  '
                                'P ${recipe.nutrition.proteinGrams.toStringAsFixed(0)}g  '
                                'F ${recipe.nutrition.fatGrams.toStringAsFixed(0)}g',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showLogSheet(recipe),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

}

/// Small rounded thumbnail (~48 px) shown in recipe list tile leading slot.
///
/// Falls back to a category-coloured icon when the URL is null or fails to
/// load.  Uses plain [Image.network] — no extra dependency required.
class _RecipePickerThumbnail extends StatelessWidget {
  const _RecipePickerThumbnail({
    required this.imageUrl,
    required this.type,
  });

  final String? imageUrl;
  final RecipeType type;

  static const double _size = 48;

  Color _categoryColor(BuildContext context) {
    switch (type) {
      case RecipeType.breakfast:
        return AppColors.orange;
      case RecipeType.mains:
        return AppColors.electrolyteDark;
      case RecipeType.snacks:
        return AppColors.dragonfruit;
      case RecipeType.workoutFuel:
        return const Color(0xFF8E6FD8); // brand violet
      case RecipeType.recovery:
        return AppColors.electrolyte;
    }
  }

  IconData _categoryIcon() {
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
    final color = _categoryColor(context);

    final placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_categoryIcon(), color: color, size: 24),
    );

    if (imageUrl == null) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: _size,
            height: _size,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.electrolyte
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.blackberry
                : (isDark ? Colors.white : AppColors.blackberry),
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
