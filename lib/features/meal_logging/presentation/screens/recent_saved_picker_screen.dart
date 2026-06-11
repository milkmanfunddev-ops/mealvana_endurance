import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_log_source.dart';
import '../../domain/meal_slot.dart';
import '../../domain/saved_meal.dart';
import '../providers/meal_log_providers.dart';
import '../widgets/slot_chip_selector.dart';

/// Picker screen for re-logging a recent or saved meal.
///
/// Route: `/meal-log/recent-saved`
/// Extras: `{ 'logDate': String }`
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final component = _syntheticFromLog(log);
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

  void _checkSuccess() {
    final state = ref.read(mealLogControllerProvider);
    if (state is AsyncData) {
      MealvanaSnackbar.showSuccess(context, 'Meal logged!');
      context.go('/main');
    } else if (state is AsyncError) {
      MealvanaSnackbar.showError(context, 'Failed to log meal.');
    }
  }

  MealComponent _syntheticFromLog(MealLog log) {
    return MealComponent(
      name: log.name,
      portion: '1 serving',
      calories: log.calories,
      carbG: log.carbsG,
      proteinG: log.proteinG,
      fatG: log.fatG,
      sodiumMg: log.sodiumMg,
    );
  }

  void _showSlotPicker({
    required void Function(MealSlot) onSelected,
  }) {
    MealSlot selected = MealSlot.breakfast;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
                  'Which meal?',
                  style: AppTextStyles.subtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                SlotChipSelector(
                  selectedSlot: selected,
                  onSlotSelected: (s) => setModalState(() => selected = s),
                ),
                const SizedBox(height: AppSpacing.lg),
                KylePrimaryButton(
                  text: 'Log',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onSelected(selected);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        title: const Text('Recent & Saved'),
        elevation: 0,
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
            onTap: (meal) => _showSlotPicker(
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
    );
  }
}

// ---------------------------------------------------------------------------
// Saved meals tab
// ---------------------------------------------------------------------------

class _SavedTab extends ConsumerWidget {
  const _SavedTab({required this.onTap, required this.onDelete});

  final ValueChanged<SavedMeal> onTap;
  final ValueChanged<String> onDelete;

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
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.bookmark_outlined, size: 18),
                ),
                title: Text(meal.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _macroSubtitle(
                    ctx, meal.calories, meal.carbsG, meal.proteinG, meal.fatG),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
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
