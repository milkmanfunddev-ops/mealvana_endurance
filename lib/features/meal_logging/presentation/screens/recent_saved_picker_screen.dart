import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import '../../domain/saved_meal.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/log_sheet_helpers.dart' show syntheticFromLog, showSlotPickerSheet;

/// Picker screen for re-logging a recent or saved meal.
///
/// Route: `/meal-log/recent-saved`
/// Extras: `{ 'logDate': String }`
///
/// The Saved tab supports a multi-select mode (toggled from the app bar) so
/// several favorites can be logged to the same slot in one batch — the
/// multi-log flow, and the way an imported meal plan gets logged.
class RecentSavedPickerScreen extends ConsumerStatefulWidget {
  const RecentSavedPickerScreen({super.key});

  @override
  ConsumerState<RecentSavedPickerScreen> createState() =>
      _RecentSavedPickerScreenState();
}

class _RecentSavedPickerScreenState
    extends ConsumerState<RecentSavedPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _logDate;
  bool _initialized = false;

  /// Multi-select (batch-log) mode, honored by the Saved tab only.
  bool _multiSelect = false;

  /// Selected favorites keyed by id (holds the objects so we can bulk-log
  /// without re-reading the provider).
  final Map<String, SavedMeal> _selected = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Multi-select only makes sense on the Saved tab — leaving it clears any
    // in-progress selection so the state can't linger invisibly.
    _tabController.addListener(() {
      if (_tabController.index != 0 && _multiSelect) {
        setState(() {
          _multiSelect = false;
          _selected.clear();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      _logDate = extra?['logDate'] as String? ?? _todayDateString();
      _initialized = true;
    }
  }

  static String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleMultiSelect() {
    setState(() {
      _multiSelect = !_multiSelect;
      if (!_multiSelect) _selected.clear();
    });
  }

  void _toggleSelected(SavedMeal meal) {
    setState(() {
      if (_selected.containsKey(meal.id)) {
        _selected.remove(meal.id);
      } else {
        _selected[meal.id] = meal;
      }
    });
  }

  Future<void> _logSavedMeal(SavedMeal meal, MealSlot slot) async {
    await ref.read(mealLogControllerProvider.notifier).logSavedMeal(
          savedMeal: meal,
          slot: slot,
          logDate: _logDate!,
        );
    if (!mounted) return;
    _checkSuccess();
  }

  Future<void> _logRecentMeal(MealLog log, MealSlot slot) async {
    final component = syntheticFromLog(log);
    await ref.read(mealLogControllerProvider.notifier).logFromComponents(
          name: log.name,
          slot: slot,
          logDate: _logDate!,
          source: MealLogSource.saved,
          components: [component],
        );
    if (!mounted) return;
    _checkSuccess();
  }

  Future<void> _logSelected(MealSlot slot) async {
    final meals = _selected.values.toList(growable: false);
    if (meals.isEmpty) return;
    await ref.read(mealLogControllerProvider.notifier).logSavedMeals(
          savedMeals: meals,
          slot: slot,
          logDate: _logDate!,
        );
    if (!mounted) return;
    _checkSuccess(count: meals.length);
  }

  void _checkSuccess({int count = 1}) {
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      MealvanaSnackbar.showSuccess(
        context,
        count == 1 ? 'Meal logged!' : 'Logged $count meals!',
      );
      context.go('/main');
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(
        context,
        count == 1 ? 'Failed to log meal.' : 'Failed to log meals.',
      );
    }
  }

  /// Delegates to the shared slot picker helper in [log_sheet_helpers.dart].
  void _showSlotPicker({required void Function(MealSlot) onSelected}) {
    showSlotPickerSheet(context, onSelected: onSelected);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: Text(_multiSelect ? '${_selected.length} selected' : 'Recent & Saved'),
        elevation: 0,
        actions: [
          // Import a meal plan (PDF/photo) into My Meals via AI.
          if (!_multiSelect)
            IconButton(
              tooltip: 'Import meal plan',
              icon: const Icon(Icons.upload_file),
              onPressed: () => context.push('/meal-log/import-plan'),
            ),
          // Multi-select toggle — only relevant on the Saved tab.
          IconButton(
            tooltip: _multiSelect ? 'Cancel selection' : 'Select multiple',
            icon: Icon(_multiSelect ? Icons.close : Icons.checklist_rounded),
            onPressed: _toggleMultiSelect,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Saved'),
            Tab(text: 'Recent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SavedTab(
            multiSelect: _multiSelect,
            selectedIds: _selected.keys.toSet(),
            onTap: (meal) => _multiSelect
                ? _toggleSelected(meal)
                : _showSlotPicker(
                    onSelected: (slot) => _logSavedMeal(meal, slot),
                  ),
            onDelete: (mealId) => ref
                .read(mealLogControllerProvider.notifier)
                .deleteSavedMeal(mealId),
          ),
          _RecentTab(
            onTap: (log) => _showSlotPicker(
              onSelected: (slot) => _logRecentMeal(log, slot),
            ),
          ),
        ],
      ),
      bottomNavigationBar: (_multiSelect && _selected.isNotEmpty)
          ? SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.electrolyte,
                  foregroundColor: AppColors.blackberry,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.add_task),
                label: Text(
                  _selected.length == 1
                      ? 'Log 1 meal'
                      : 'Log ${_selected.length} meals',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _showSlotPicker(onSelected: _logSelected),
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Saved meals tab
// ---------------------------------------------------------------------------

class _SavedTab extends ConsumerWidget {
  const _SavedTab({
    required this.onTap,
    required this.onDelete,
    required this.multiSelect,
    required this.selectedIds,
  });

  final ValueChanged<SavedMeal> onTap;
  final ValueChanged<String> onDelete;
  final bool multiSelect;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedMealsProvider);
    return savedAsync.when(
      data: (meals) {
        if (meals.isEmpty) {
          return const Center(child: Text('No saved meals yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.md),
          itemCount: meals.length,
          itemBuilder: (ctx, i) {
            final meal = meals[i];
            final selected = selectedIds.contains(meal.id);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                selected: selected,
                selectedTileColor:
                    AppColors.electrolyte.withValues(alpha: 0.12),
                leading: multiSelect
                    ? Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? AppColors.electrolyteDark
                            : null,
                      )
                    : const CircleAvatar(
                        child: Icon(Icons.bookmark_outlined, size: 18),
                      ),
                title: Text(meal.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _macroSubtitle(
                    ctx, meal.calories, meal.carbsG, meal.proteinG, meal.fatG),
                trailing: multiSelect
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: AppColors.dragonfruit),
                            onPressed: () => onDelete(meal.id),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                onTap: () => onTap(meal),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Could not load saved meals.')),
    );
  }

}

// ---------------------------------------------------------------------------
// Recent meals tab
// ---------------------------------------------------------------------------

class _RecentTab extends ConsumerWidget {
  const _RecentTab({required this.onTap});

  final ValueChanged<MealLog> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentMealsProvider);
    return recentAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('No recent meals.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.md),
          itemCount: logs.length,
          itemBuilder: (ctx, i) {
            final log = logs[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.history, size: 18),
                ),
                title: Text(log.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _macroSubtitle(
                    ctx, log.calories, log.carbsG, log.proteinG, log.fatG),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTap(log),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Could not load recent meals.')),
    );
  }

}

/// Compact "320 kcal  ·  C 40g  ·  P 20g  ·  F 9g" subtitle shared by both
/// tabs; null when the entry has no macro data so ListTile omits the line.
Widget? _macroSubtitle(
    BuildContext context, int? cal, double? carb, double? prot, double? fat) {
  final parts = [
    if (cal != null) '$cal kcal',
    if (carb != null) 'C ${carb.toStringAsFixed(0)}g',
    if (prot != null) 'P ${prot.toStringAsFixed(0)}g',
    if (fat != null) 'F ${fat.toStringAsFixed(0)}g',
  ];
  if (parts.isEmpty) return null;
  return Text(parts.join('  ·  '),
      style: Theme.of(context).textTheme.bodySmall);
}
