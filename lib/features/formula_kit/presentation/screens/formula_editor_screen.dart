import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../../nutrition_plan/domain/food_item_data.dart';
import '../../../nutrition_plan/domain/solver_food.dart';
import '../../../nutrition_plan/presentation/providers/swap_food_controller.dart'
    show SwapFoodSelection;
import '../../../nutrition_plan/presentation/widgets/activity_detail/dismissible_food_item.dart';
import '../../application/athlete_conflict_profile_provider.dart';
import '../../application/formula_editor_controller.dart';
import '../../application/formula_pin_controller.dart';
import '../../domain/after_filter_options.dart';
import '../../domain/before_sub_phase.dart';
import '../../domain/coach_insight.dart';
import '../../domain/during_filter_options.dart';
import '../../domain/formula_macros.dart';
import '../../domain/formula_phase.dart';
import '../../domain/formula_profile_conflict.dart';
import '../widgets/coach_insight_panel.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/pin_conflict_warning.dart';
import '../widgets/pin_toggle.dart';
import '../widgets/save_conflict_disclosure.dart';

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

  // FP-4d/FP-4a: a conflicted pin tap from the AppBar toggle mounts the
  // inline warning in the page (same decision moment as the system detail
  // screen — personal formulas reach a plan only through the pin set).
  bool _showConflictWarning = false;
  bool _showDietNote = false;

  late final _provider = formulaEditorControllerProvider(
    widget.formulaId,
    widget.phase,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _categoryFor(FormulaPhase phase) => switch (phase) {
    FormulaPhase.before => 'before_run',
    FormulaPhase.during => 'during_run',
    FormulaPhase.after => 'after_run',
  };

  /// The phase currently in the draft (editable), falling back to the route's
  /// initial phase before the draft loads.
  FormulaPhase get _currentPhase =>
      ref.read(_provider).value?.phase ?? widget.phase;

  /// The draft's conflict with the current profile (component scan), or null.
  FormulaProfileConflict? _draftConflict(FormulaDraft draft) => ref
      .watch(athleteConflictProfileProvider)
      .maybeWhen(
        data: (profile) =>
            firstComponentConflict(draft.components, profile)?.conflict,
        orElse: () => null,
      );

  Future<void> _completeConflictedPin() async {
    setState(() => _showConflictWarning = false);
    try {
      await ref
          .read(formulaPinControllerProvider.notifier)
          .togglePersonalFormula(
            formulaId: widget.formulaId!,
            phase: _currentPhase,
            source: 'detail',
          );
    } catch (err) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Couldn\'t update pin: $err');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDraft = ref.watch(_provider);
    final scheme = Theme.of(context).colorScheme;
    final coachInsightsEnabled = ref.watch(
      appConfigProvider.select((config) => config.coachInsightsEnabled),
    );

    return AdaptivePageScaffold(
      key: ValueKey('formula_kit.editor_screen.${widget.formulaId ?? 'new'}'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      contentWidth: AdaptiveContentWidth.standard,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        // FittedBox scales the title down instead of ellipsizing (item 17,
        // 2026-07-04) — mirrors the pattern used by
        // fuel_timeline_day_header.dart. This title is currently a static
        // "New/Edit formula" label, but the smaller/narrower style keeps it
        // consistent with the detail screen's app bar.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.formulaId == null ? 'New formula' : 'Edit formula',
            softWrap: false,
            maxLines: 1,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 17,
              color: scheme.onSurface,
            ),
          ),
        ),
        actions: [
          // FP-4d: the personal detail (this editor) carries the same AppBar
          // pin glyph as the system detail (FP-7) — saved formulas only; an
          // unsaved draft has no id to pin.
          if (widget.formulaId != null && asyncDraft.value != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: PinTogglePersonalFormula(
                key: ValueKey('formula_kit.editor_pin_${widget.formulaId}'),
                formulaId: widget.formulaId!,
                phase: asyncDraft.value!.phase,
                source: 'detail',
                conflict: _draftConflict(asyncDraft.value!),
                onAllergyConflictPinAttempt: () =>
                    setState(() => _showConflictWarning = true),
                onDietConflictPinned: () =>
                    setState(() => _showDietNote = true),
              ),
            ),
        ],
      ),
      body: asyncDraft.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => Center(
          child: Text(
            'Couldn\'t open the editor.\n$e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (draft) {
          if (!_seeded) {
            _seeded = true;
            _nameController.text = draft.name;
            _notesController.text = draft.notes ?? '';
          }
          final notifier = ref.read(_provider.notifier);
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
                    // FP-8 conflict disclosure — AMENDED (Xuan on-device,
                    // 2026-09-03 evening): pinned at the TOP of the authoring
                    // screen, matching the template detail's warning placement
                    // (it previously floated above Save, where it overlapped
                    // scroll content and read as detached). Save is never
                    // disabled (§1a disclose-never-block).
                    // FP-4a warning / diet note for a conflicted pin attempt
                    // from the AppBar toggle — in the page, never a dialog.
                    ...(() {
                      final conflict = _draftConflict(draft);
                      if (conflict == null) return const <Widget>[];
                      return <Widget>[
                        if (_showConflictWarning &&
                            conflict.kind == FormulaConflictKind.allergy)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: PinConflictWarning.allergy(
                              allergenDisplay: conflict.allergenDisplay,
                              onChooseAnother: () =>
                                  setState(() => _showConflictWarning = false),
                              onPinAnyway: _completeConflictedPin,
                            ),
                          ),
                        if (_showDietNote &&
                            conflict.kind == FormulaConflictKind.diet)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: PinConflictWarning.diet(
                              dietDisplay: conflict.dietDisplay,
                            ),
                          ),
                      ];
                    })(),
                    ..._saveConflictDisclosure(draft, atTop: true),
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
                    // Editable phase (above the timing/scope chips).
                    _Label('Phase'),
                    const SizedBox(height: AppSpacing.xs),
                    FilterChipRow<FormulaPhase>(
                      options: FormulaPhase.values,
                      labelOf: (p) => p.displayLabel,
                      isSelected: (p) => draft.phase == p,
                      onToggled: notifier.setPhase,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ScopeSection(
                      phase: draft.phase,
                      draft: draft,
                      notifier: notifier,
                    ),
                    // Formula total macros (no targets/ranges — formulas have
                    // no per-plan targets).
                    _MacroTotals(totals: draft.totals),
                    const SizedBox(height: AppSpacing.md),
                    // Food rows reusing the activity-details widgets: swipe
                    // right → swap, swipe left → delete, tap → expand
                    // (Nutrition Facts + Remove). Quantity semantics are
                    // asymmetric by design: before/after formulas carry exact
                    // quantities (the +/- stepper is shown), while during
                    // formulas are quantity-less — the solver derives amounts.
                    if (draft.components.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          'No foods yet. Tap "Add Food" to build your formula.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < draft.components.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: DismissibleFoodItem(
                            key: ValueKey('formula_kit.editor_row_$i'),
                            food: _foodItemFromComponent(
                              draft.components[i],
                              i,
                            ),
                            category: _categoryFor(draft.phase),
                            showQuantity: draft.phase != FormulaPhase.during,
                            onSwap: () =>
                                _swapComponent(i, draft.components[i]),
                            onDelete: () => notifier.removeComponent(i),
                            onQuantityChange: (q) =>
                                notifier.updateComponentQuantity(i, q),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.sm),
                    KyleAddFoodButton(
                      key: const ValueKey('formula_kit.editor_add_food'),
                      onPressed: _addFood,
                    ),
                    // Coach insight — only meaningful once the formula has at
                    // least one component (the edge function requires it).
                    if (coachInsightsEnabled &&
                        draft.components.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      CoachInsightPanel(
                        insightContext: _insightContextFor(draft),
                        formulaId: widget.formulaId,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _Label('Notes (optional)'),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _notesController,
                      onChanged: (v) => notifier.setNotes(v.isEmpty ? null : v),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'When to use it, prep tips…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KylePrimaryButton(
                      key: const ValueKey('formula_kit.editor_save'),
                      text: 'Save formula',
                      isLoading: _saving,
                      onPressed: (draft.canSave && !_saving) ? _save : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// FP-8: the disclosure widget for the first component conflicting with
  /// the athlete's profile, or nothing. Detection is pure domain
  /// ([firstComponentConflict]); the profile read is the shared provider.
  List<Widget> _saveConflictDisclosure(
    FormulaDraft draft, {
    bool atTop = false,
  }) {
    final profile = ref
        .watch(athleteConflictProfileProvider)
        .maybeWhen(data: (p) => p, orElse: () => null);
    if (profile == null) return const [];
    final hit = firstComponentConflict(draft.components, profile);
    if (hit == null) return const [];
    return [
      SaveConflictDisclosure(foodName: hit.foodName, conflict: hit.conflict),
      if (atTop) const SizedBox(height: AppSpacing.md),
    ];
  }

  Future<void> _addFood() async {
    final result = await context.push<SwapFoodSelection>(
      '/swap-food',
      extra: {'category': _categoryFor(_currentPhase), 'returnSelection': true},
    );
    if (result == null || !mounted) return;
    ref
        .read(_provider.notifier)
        .addComponent(
          result.food,
          result.quantity,
          isUserFood: result.isUserFood,
        );
  }

  Future<void> _swapComponent(int index, Map<String, dynamic> component) async {
    final result = await context.push<SwapFoodSelection>(
      '/swap-food',
      extra: {
        'category': _categoryFor(_currentPhase),
        'returnSelection': true,
        'foodToSwapId': component[FormulaMacros.kFoodId],
        'foodToSwapName': FormulaMacros.nameOf(component),
      },
    );
    if (result == null || !mounted) return;
    ref
        .read(_provider.notifier)
        .replaceComponent(
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

  /// Build the live coach-insight context from the current [draft]. Only the
  /// scope fields meaningful to the draft's phase are populated.
  CoachInsightContext _insightContextFor(FormulaDraft draft) {
    return CoachInsightContext(
      phase: draft.phase,
      components: draft.components,
      name: draft.name,
      subPhase: draft.phase == FormulaPhase.before ? draft.subPhase : null,
      durations: draft.phase == FormulaPhase.during ? draft.durations : null,
      activities: draft.phase == FormulaPhase.before ? null : draft.activities,
    );
  }

  /// Map a stored component (at [index]) to the [FoodItemData] the reused
  /// [DismissibleFoodItem] renders. The id encodes [index] to keep each
  /// Dismissible key unique (handles duplicate foods).
  FoodItemData _foodItemFromComponent(Map<String, dynamic> c, int index) {
    double n(Object? v) => v is num ? v.toDouble() : 0.0;
    final qty = FormulaMacros.quantityOf(c);
    final name = FormulaMacros.nameOf(c);
    final unit = c[FormulaMacros.kServingUnit] as String?;
    final carbs = (n(c[FormulaMacros.kCarbsPerServing]) * qty).round();
    final protein = (n(c[FormulaMacros.kProteinPerServing]) * qty).round();
    final fat = (n(c[FormulaMacros.kFatPerServing]) * qty).round();
    final sodium = (n(c[FormulaMacros.kSodiumMg]) * qty).round();
    final fluids = n(c[FormulaMacros.kFluidMlPerServing]) * qty;
    final calRaw = c[FormulaMacros.kCaloriesPerServing];
    final calories = calRaw is num
        ? (calRaw.toDouble() * qty).round()
        : carbs * 4 + protein * 4 + fat * 9;

    return FoodItemData(
      id: 'idx:$index',
      name: name,
      quantity: FoodItemData.buildDisplayQuantity(
        rawQty: SolverFood.formatQuantity(qty),
        servingUnit: unit,
        displayName: name,
      ),
      nutritionalInfo: NutritionalInfo(
        calories: calories,
        carbs: carbs,
        protein: protein,
        fat: fat,
        sodium: sodium,
        fluids: fluids,
      ),
      displayName: name,
      servingSize: unit,
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

  void _toggleInList(
    List<String>? current,
    String value,
    void Function(List<String>?) set,
  ) {
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
                draft.activities,
                v.storageValue,
                notifier.setActivities,
              ),
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
                draft.durations,
                v.storageValue,
                notifier.setDurations,
              ),
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
                draft.activities,
                v.storageValue,
                notifier.setActivities,
              ),
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

/// Formula total macros — big numbers, no target ranges (formulas have no
/// per-plan targets). Mirrors the activity-details macro readout style.
class _MacroTotals extends StatelessWidget {
  const _MacroTotals({required this.totals});

  final FormulaTotals totals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String value, String label) => Column(
      children: [
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: AppColors.electrolyte,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          cell('${totals.carbsG}g', 'CARBS'),
          cell('${totals.proteinG}g', 'PROTEIN'),
          cell('${totals.fatG}g', 'FAT'),
          cell('${totals.sodiumMg}', 'SODIUM'),
        ],
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
