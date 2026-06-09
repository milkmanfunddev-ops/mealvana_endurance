import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';

import '../../../nutrition_plan/domain/food.dart';
import '../../../nutrition_plan/presentation/providers/swap_food_controller.dart'
    show SwapFoodSelection;
import '../../../nutrition_plan/presentation/widgets/swap_food/selected_food_display_widget.dart';
import '../../application/formula_editor_controller.dart';
import '../../domain/after_filter_options.dart';
import '../../domain/before_sub_phase.dart';
import '../../domain/during_filter_options.dart';
import '../../domain/formula_macros.dart';
import '../../domain/formula_phase.dart';
import '../widgets/filter_chip_row.dart';

/// Create / edit screen for a personal formula. State-driven by
/// [FormulaEditorController]. `formulaId == null` → create-from-scratch (with
/// the supplied [phase]); otherwise edits the existing formula.
///
/// Reuses the activity-details `/swap-food` page (in `returnSelection` mode)
/// for both Add Food and per-component Swap, so the full search / barcode /
/// import experience is shared rather than duplicated.
class FormulaEditorScreen extends ConsumerStatefulWidget {
  const FormulaEditorScreen({
    super.key,
    required this.formulaId,
    required this.phase,
  });

  final String? formulaId;
  final FormulaPhase phase;

  @override
  ConsumerState<FormulaEditorScreen> createState() =>
      _FormulaEditorScreenState();
}

class _FormulaEditorScreenState extends ConsumerState<FormulaEditorScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  late final _provider =
      formulaEditorControllerProvider(widget.formulaId, widget.phase);

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _category => switch (widget.phase) {
        FormulaPhase.before => 'before_run',
        FormulaPhase.during => 'during_run',
        FormulaPhase.after => 'after_run',
      };

  @override
  Widget build(BuildContext context) {
    final asyncDraft = ref.watch(_provider);
    final scheme = Theme.of(context).colorScheme;

    return AdaptivePageScaffold(
      key: ValueKey('formula_kit.editor_screen.${widget.formulaId ?? 'new'}'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      contentWidth: AdaptiveContentWidth.standard,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        title: Text(
          widget.formulaId == null ? 'New formula' : 'Edit formula',
          style: AppTextStyles.sectionTitle.copyWith(color: scheme.onSurface),
        ),
      ),
      body: asyncDraft.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => Center(
          child: Text('Couldn\'t open the editor.\n$e',
              textAlign: TextAlign.center),
        ),
        data: (draft) {
          if (!_seeded) {
            _seeded = true;
            _nameController.text = draft.name;
            _notesController.text = draft.notes ?? '';
          }
          final notifier = ref.read(_provider.notifier);
          final totals = draft.totals;
          return Stack(
            children: [
              AdaptiveScrollableBody(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Name'),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      key: const ValueKey('formula_kit.editor_name'),
                      controller: _nameController,
                      onChanged: notifier.setName,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Pre-long-run oatmeal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ScopeSection(
                      phase: widget.phase,
                      draft: draft,
                      notifier: notifier,
                    ),
                    _Label('Components'),
                    const SizedBox(height: AppSpacing.xs),
                    if (draft.components.isEmpty)
                      Text(
                        'No foods yet — add one to start building.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: scheme.onSurfaceVariant),
                      )
                    else
                      for (var i = 0; i < draft.components.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        _ComponentEditRow(
                          food: _foodFromComponent(draft.components[i]),
                          quantity:
                              FormulaMacros.quantityOf(draft.components[i]),
                          onQuantityChanged: (q) =>
                              notifier.updateComponentQuantity(i, q),
                          onRemove: () => notifier.removeComponent(i),
                          onSwap: () => _swapComponent(i, draft.components[i]),
                        ),
                      ],
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const ValueKey('formula_kit.editor_add_food'),
                      onPressed: _addFood,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Food'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Label('Notes (optional)'),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _notesController,
                      onChanged: (v) =>
                          notifier.setNotes(v.isEmpty ? null : v),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'When to use it, prep tips…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TotalsBar(
                      carbs: totals.carbsG,
                      protein: totals.proteinG,
                      fat: totals.fatG,
                      sodium: totals.sodiumMg,
                      calories: totals.calories,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: KylePrimaryButton(
                  key: const ValueKey('formula_kit.editor_save'),
                  text: 'Save formula',
                  isLoading: _saving,
                  onPressed: (draft.canSave && !_saving) ? _save : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addFood() async {
    final result = await context.push<SwapFoodSelection>(
      '/swap-food',
      extra: {'category': _category, 'returnSelection': true},
    );
    if (result == null || !mounted) return;
    ref.read(_provider.notifier).addComponent(
          result.food,
          result.quantity,
          isUserFood: result.isUserFood,
        );
  }

  Future<void> _swapComponent(int index, Map<String, dynamic> component) async {
    final result = await context.push<SwapFoodSelection>(
      '/swap-food',
      extra: {
        'category': _category,
        'returnSelection': true,
        'foodToSwapId': component[FormulaMacros.kFoodId],
        'foodToSwapName': FormulaMacros.nameOf(component),
      },
    );
    if (result == null || !mounted) return;
    ref.read(_provider.notifier).replaceComponent(
          index,
          result.food,
          result.quantity,
          isUserFood: result.isUserFood,
        );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await ref.read(_provider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      MealvanaSnackbar.showError(context, 'Add a name and at least one food.');
      return;
    }
    MealvanaSnackbar.showSuccess(context, 'Formula saved');
    context.pop();
  }

  /// Reconstruct a [Food] from a stored component so the shared
  /// [SelectedFoodDisplayWidget] can render it (it only reads name + per-serving
  /// macros + serving unit).
  Food _foodFromComponent(Map<String, dynamic> c) {
    double? d(Object? v) => v is num ? v.toDouble() : null;
    int? i(Object? v) => v is num ? v.round() : null;
    return Food(
      id: (c[FormulaMacros.kFoodId] as String?) ?? '',
      name: FormulaMacros.nameOf(c),
      displayName: c[FormulaMacros.kFoodName] as String?,
      servingUnit: c[FormulaMacros.kServingUnit] as String?,
      carbsPerServing: d(c[FormulaMacros.kCarbsPerServing]),
      proteinPerServing: d(c[FormulaMacros.kProteinPerServing]),
      fatPerServing: d(c[FormulaMacros.kFatPerServing]),
      sodiumMg: i(c[FormulaMacros.kSodiumMg]),
      fluidMlPerServing: d(c[FormulaMacros.kFluidMlPerServing]),
      caloriesPerServing: i(c[FormulaMacros.kCaloriesPerServing]),
    );
  }
}

class _ComponentEditRow extends StatelessWidget {
  const _ComponentEditRow({
    required this.food,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onSwap,
  });

  final Food food;
  final double quantity;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectedFoodDisplayWidget(
          food: food,
          quantity: quantity,
          onQuantityChanged: onQuantityChanged,
          onClear: onRemove,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onSwap,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Swap'),
          ),
        ),
      ],
    );
  }
}

/// Phase-specific scope chips. Optional metadata that lets the plan-generation
/// algorithm match a pinned personal formula to a workout.
class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.phase,
    required this.draft,
    required this.notifier,
  });

  final FormulaPhase phase;
  final FormulaDraft draft;
  final FormulaEditorController notifier;

  void _toggleInList(List<String>? current, String value,
      void Function(List<String>?) set) {
    final next = [...?current];
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    set(next.isEmpty ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case FormulaPhase.before:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('Timing (required)'),
            const SizedBox(height: AppSpacing.xs),
            // Mandatory single choice — plan generation honors a before pin per
            // sub-phase slot (meal / snack / top_up), so an untagged before
            // formula could never be returned. The chip is non-deselectable;
            // Save stays disabled until one is picked (see FormulaDraft.canSave).
            FilterChipRow<BeforeSubPhase>(
              options: BeforeSubPhase.values,
              labelOf: (v) => v.displayLabel,
              isSelected: (v) => draft.subPhase == v.storageValue,
              onToggled: (v) => notifier.setSubPhase(v.storageValue),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      case FormulaPhase.during:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('Activities'),
            const SizedBox(height: AppSpacing.xs),
            FilterChipRow<DuringActivity>(
              options: DuringActivity.values,
              labelOf: (v) => v.displayLabel,
              isSelected: (v) =>
                  draft.activities?.contains(v.storageValue) ?? false,
              onToggled: (v) => _toggleInList(
                  draft.activities, v.storageValue, notifier.setActivities),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Label('Duration'),
            const SizedBox(height: AppSpacing.xs),
            FilterChipRow<DuringDuration>(
              options: DuringDuration.values,
              labelOf: (v) => v.displayLabel,
              isSelected: (v) =>
                  draft.durations?.contains(v.storageValue) ?? false,
              onToggled: (v) => _toggleInList(
                  draft.durations, v.storageValue, notifier.setDurations),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      case FormulaPhase.after:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('Activities'),
            const SizedBox(height: AppSpacing.xs),
            FilterChipRow<DuringActivity>(
              options: DuringActivity.values,
              labelOf: (v) => v.displayLabel,
              isSelected: (v) =>
                  draft.activities?.contains(v.storageValue) ?? false,
              onToggled: (v) => _toggleInList(
                  draft.activities, v.storageValue, notifier.setActivities),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Label('Travel'),
            const SizedBox(height: AppSpacing.xs),
            FilterChipRow<TravelFriendliness>(
              options: TravelFriendliness.values,
              labelOf: (v) => v.displayLabel,
              isSelected: (v) => draft.travelFriendliness == v.storageValue,
              onToggled: (v) => notifier.setTravelFriendliness(
                draft.travelFriendliness == v.storageValue
                    ? null
                    : v.storageValue,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
    }
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.sodium,
    required this.calories,
  });

  final int carbs;
  final int protein;
  final int fat;
  final int sodium;
  final int calories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, String value) => Column(
          children: [
            Text(
              value,
              style: AppTextStyles.dataNumber.copyWith(
                color: AppColors.electrolyte,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        );
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            cell('Cal', '$calories'),
            cell('Carbs', '${carbs}g'),
            cell('Protein', '${protein}g'),
            cell('Fat', '${fat}g'),
            cell('Na', '$sodium'),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.sectionTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
      ),
    );
  }
}
