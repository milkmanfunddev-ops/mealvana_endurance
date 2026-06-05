import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';

import '../../../nutrition_plan/domain/food_item_data.dart';
import '../../application/formula_library_controller.dart';
import '../../application/personal_formula_controller.dart';
import '../../domain/formula_phase.dart';
import '../../domain/formula_view.dart';
import '../widgets/pin_toggle.dart';

/// Read-only detail view for a system formula (PR 1).
///
/// Re-uses `formulaLibraryControllerProvider` state to look up the formula
/// by `id` + `phase` — avoids spinning up a second fetch since the user
/// arrived here from the library list.
///
/// Edit / personalize / favorite affordances land in PR 2-5.
class FormulaDetailScreen extends ConsumerStatefulWidget {
  const FormulaDetailScreen({
    super.key,
    required this.id,
    required this.phase,
  });

  final String id;
  final FormulaPhase phase;

  @override
  ConsumerState<FormulaDetailScreen> createState() =>
      _FormulaDetailScreenState();
}

class _FormulaDetailScreenState extends ConsumerState<FormulaDetailScreen> {
  bool _trackedView = false;

  // ── PR 4 "Make this mine" edit state (Before phase only) ────────────────
  // UI-only in PR 4: Save fires analytics + a confirmation toast but does not
  // persist a personal formula (that lands in PR 5). Quantity tweaks recompute
  // macros live off [_draft]; Cancel discards.
  static const double _qtyStep = 0.5;
  static const double _qtyMin = 0.5;

  bool _editing = false;
  bool _saving = false;
  List<BeforeComponent>? _draft;
  int? _expandedIdx;
  DateTime? _editStartedAt;

  void _enterEdit(BeforeFormulaView formula) {
    setState(() {
      _editing = true;
      _draft = formula.components.map((c) => c.copyWith()).toList();
      _expandedIdx = null;
      _editStartedAt = DateTime.now();
    });
    ref
        .read(formulaLibraryControllerProvider.notifier)
        .trackMakeThisMineTapped(templateId: formula.id, phase: FormulaPhase.before);
  }

  void _cancelEdit() {
    ref
        .read(formulaLibraryControllerProvider.notifier)
        .trackPersonalFormulaEditCancelled(phase: FormulaPhase.before);
    setState(() {
      _editing = false;
      _draft = null;
      _expandedIdx = null;
      _editStartedAt = null;
    });
  }

  Future<void> _saveEdit(BeforeFormulaView source) async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);

    final durationSec = _editStartedAt == null
        ? 0
        : DateTime.now().difference(_editStartedAt!).inSeconds;

    // The `finally` is the load-bearing part: `_saving` is reset on every exit
    // path — success, null result, or an unexpected throw — so the Save pill
    // can never get stranded spinning.
    try {
      final saved = await ref
          .read(personalFormulaControllerProvider.notifier)
          .saveBeforeEdit(source: source, draft: draft);

      if (!mounted) return;

      if (saved == null) {
        MealvanaSnackbar.showError(
          context,
          "Couldn't save your formula. Please try again.",
        );
        return;
      }

      ref
          .read(formulaLibraryControllerProvider.notifier)
          .trackPersonalFormulaSaved(
            phase: FormulaPhase.before,
            componentCount: draft.length,
            editDurationSec: durationSec,
          );
      MealvanaSnackbar.showSuccess(context, 'Saved to your formulas');
      setState(() {
        _editing = false;
        _draft = null;
        _expandedIdx = null;
        _editStartedAt = null;
      });
    } catch (_) {
      // saveBeforeEdit guards its own failures, so this is a defensive net for
      // anything unexpected on the UI side. The controller logs the root cause.
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          "Couldn't save your formula. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setQuantity(int index, double quantity) {
    setState(() {
      _draft![index] = _draft![index].copyWith(quantity: quantity);
    });
  }

  void _removeComponent(int index) {
    if (_draft!.length <= 1) return;
    setState(() {
      _draft!.removeAt(index);
      _expandedIdx = null;
    });
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIdx = _expandedIdx == index ? null : index;
    });
  }

  /// Swap + Add Food open a "coming soon" placeholder in PR 4 — the real
  /// food-catalog swap/add flow ships in PR 5.
  void _showComingSoon(String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComingSoonSheet(title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(formulaLibraryControllerProvider);

    if (!_trackedView) {
      _trackedView = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(formulaLibraryControllerProvider.notifier).trackDetailViewed(
              templateId: widget.id,
              phase: widget.phase,
              isPersonal: false,
            );
      });
    }

    return AdaptivePageScaffold(
      key: ValueKey('formula_kit.detail_screen.${widget.phase.name}.${widget.id}'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, asyncState),
      contentWidth: AdaptiveContentWidth.standard,
      body: asyncState.when(
        loading: () => const Center(
          key: ValueKey('formula_kit.detail_loading'),
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (state) {
          switch (widget.phase) {
            case FormulaPhase.before:
              final formula = state.beforeFormulas
                  .cast<BeforeFormulaView?>()
                  .firstWhere(
                    (f) => f?.id == widget.id,
                    orElse: () => null,
                  );
              if (formula == null) return const _NotFoundView();
              if (_editing && _draft != null) {
                return _BeforeEditBody(
                  formula: formula,
                  draft: _draft!,
                  expandedIdx: _expandedIdx,
                  onToggle: _toggleExpanded,
                  onQuantityChanged: _setQuantity,
                  onRemove: _removeComponent,
                  onSwap: (_) => _showComingSoon('Swap food'),
                  onAddFood: () => _showComingSoon('Add food'),
                  qtyMin: _qtyMin,
                  qtyStep: _qtyStep,
                );
              }
              return _BeforeDetailBody(formula: formula);
            case FormulaPhase.during:
              final formula = state.duringFormulas
                  .cast<DuringFormulaView?>()
                  .firstWhere(
                    (f) => f?.id == widget.id,
                    orElse: () => null,
                  );
              if (formula == null) return const _NotFoundView();
              return _DuringDetailBody(formula: formula);
            case FormulaPhase.after:
              final formula = state.afterFormulas
                  .cast<AfterFormulaView?>()
                  .firstWhere(
                    (f) => f?.id == widget.id,
                    orElse: () => null,
                  );
              if (formula == null) return const _NotFoundView();
              return _AfterDetailBody(formula: formula);
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AsyncValue<FormulaLibraryState> asyncState,
  ) {
    // Edit state replaces the whole header: Cancel · "Edit" · Save.
    if (_editing) {
      final source = asyncState.asData?.value.beforeFormulas
          .cast<BeforeFormulaView?>()
          .firstWhere((f) => f?.id == widget.id, orElse: () => null);
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        leadingWidth: 88,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('formula_kit.edit_cancel'),
            onPressed: _cancelEdit,
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        title: Text(
          'Edit',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _SavePillButton(
              key: const ValueKey('formula_kit.edit_save'),
              saving: _saving,
              onPressed: source == null ? null : () => _saveEdit(source),
            ),
          ),
        ],
      );
    }

    String title = 'Formula';
    BeforeFormulaView? beforeFormula;
    DuringFormulaView? duringFormula;
    AfterFormulaView? afterFormula;
    asyncState.whenData((state) {
      switch (widget.phase) {
        case FormulaPhase.before:
          beforeFormula = state.beforeFormulas
              .cast<BeforeFormulaView?>()
              .firstWhere(
                (f) => f?.id == widget.id,
                orElse: () => null,
              );
          if (beforeFormula != null) title = beforeFormula!.name;
        case FormulaPhase.during:
          duringFormula = state.duringFormulas
              .cast<DuringFormulaView?>()
              .firstWhere(
                (f) => f?.id == widget.id,
                orElse: () => null,
              );
          if (duringFormula != null) title = duringFormula!.formula;
        case FormulaPhase.after:
          afterFormula = state.afterFormulas
              .cast<AfterFormulaView?>()
              .firstWhere(
                (f) => f?.id == widget.id,
                orElse: () => null,
              );
          if (afterFormula != null) title = afterFormula!.name;
      }
    });

    // V1: only food templates are pinnable. Before drink/electrolyte cards
    // hide the toggle; During and After templates are all food by design.
    Widget? pinAction;
    if (beforeFormula != null && beforeFormula!.isPinnable) {
      pinAction = PinToggleBefore(
        key: ValueKey('formula_kit.detail_pin_${beforeFormula!.id}'),
        formula: beforeFormula!,
        source: 'detail',
      );
    } else if (duringFormula != null) {
      pinAction = PinToggleDuring(
        key: ValueKey('formula_kit.detail_pin_${duringFormula!.id}'),
        formula: duringFormula!,
        source: 'detail',
      );
    } else if (afterFormula != null) {
      pinAction = PinToggleAfter(
        key: ValueKey('formula_kit.detail_pin_${afterFormula!.id}'),
        formula: afterFormula!,
        source: 'detail',
      );
    }

    // Before formulas get a "Make this mine" entry point alongside the pin.
    final actions = <Widget>[];
    if (pinAction != null) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: pinAction,
        ),
      );
    }
    if (beforeFormula != null) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: _MakeMineButton(
            key: const ValueKey('formula_kit.make_this_mine'),
            onPressed: () => _enterEdit(beforeFormula!),
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CustomAppBarBackButton(),
      title: Text(
        title,
        key: const ValueKey('formula_kit.detail_title'),
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions.isEmpty ? null : actions,
    );
  }
}

// ─── Before body ──────────────────────────────────────────────────────────

class _BeforeDetailBody extends StatelessWidget {
  const _BeforeDetailBody({required this.formula});

  final BeforeFormulaView formula;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveScrollableBody(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _InfoPill(label: formula.timingWindow, color: AppColors.orange),
              if (formula.digestionSpeed.isNotEmpty)
                _InfoPill(
                  label: '${formula.digestionSpeed} digest',
                  color: AppColors.electrolyte,
                ),
              if (formula.subPhase != null)
                _InfoPill(
                  label: formula.subPhase!.displayLabel,
                  color: AppColors.electrolyte,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MacrosCard(
            calories: formula.totalCalories,
            carbs: formula.totalCarbsG,
            protein: formula.totalProteinG,
            fat: formula.totalFatG,
            sodium: formula.totalSodiumMg,
            fluid: formula.totalFluidMl,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          if (formula.componentDisplayStrings.isEmpty)
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No components listed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < formula.componentDisplayStrings.length;
                i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _ComponentRow(label: formula.componentDisplayStrings[i]),
            ],
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionLabel(text: 'Notes'),
            const SizedBox(height: AppSpacing.xs),
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  formula.notes!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (formula.allergens.isNotEmpty ||
              formula.excludedDiets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DietTags(
              allergens: formula.allergens,
              excludedDiets: formula.excludedDiets,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Before edit state (PR 4 "Make this mine") ──────────────────────────────

/// Edit-state body for a Before formula. UI-only in PR 4: quantity tweaks
/// recompute the macros card live off [draft]; Save/Cancel are handled by the
/// parent (Save = analytics + toast, no persistence yet). Swap and Add Food
/// open a "coming soon" placeholder — the real catalog flow lands in PR 5.
class _BeforeEditBody extends StatelessWidget {
  const _BeforeEditBody({
    required this.formula,
    required this.draft,
    required this.expandedIdx,
    required this.onToggle,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onSwap,
    required this.onAddFood,
    required this.qtyMin,
    required this.qtyStep,
  });

  final BeforeFormulaView formula;
  final List<BeforeComponent> draft;
  final int? expandedIdx;
  final void Function(int index) onToggle;
  final void Function(int index, double quantity) onQuantityChanged;
  final void Function(int index) onRemove;
  final void Function(int index) onSwap;
  final VoidCallback onAddFood;
  final double qtyMin;
  final double qtyStep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Live macro totals: sum of each component's per-serving macros × its
    // current servings count. Mirrors the controller's read-mode totals.
    var carbs = 0.0, protein = 0.0, fat = 0.0, sodium = 0.0, fluid = 0.0;
    for (final c in draft) {
      carbs += c.carbsPerServing * c.quantity;
      protein += c.proteinPerServing * c.quantity;
      fat += c.fatPerServing * c.quantity;
      sodium += c.sodiumMgPerServing * c.quantity;
      fluid += c.fluidMlPerServing * c.quantity;
    }
    final calories = ((carbs * 4) + (protein * 4) + (fat * 9)).round();

    return AdaptiveScrollableBody(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _InfoPill(label: formula.timingWindow, color: AppColors.orange),
              if (formula.digestionSpeed.isNotEmpty)
                _InfoPill(
                  label: '${formula.digestionSpeed} digest',
                  color: AppColors.electrolyte,
                ),
              if (formula.subPhase != null)
                _InfoPill(
                  label: formula.subPhase!.displayLabel,
                  color: AppColors.electrolyte,
                ),
              _InfoPill(label: 'Editing', color: AppColors.orange),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MacrosCard(
            calories: calories,
            carbs: carbs,
            protein: protein,
            fat: fat,
            sodium: sodium,
            fluid: fluid,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Updates as you adjust components',
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < draft.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            _EditComponentRow(
              component: draft[i],
              expanded: expandedIdx == i,
              canRemove: draft.length > 1,
              qtyMin: qtyMin,
              qtyStep: qtyStep,
              showSwipeHint: i == 0,
              onToggle: () => onToggle(i),
              onQuantityChanged: (v) => onQuantityChanged(i, v),
              onSwap: () => onSwap(i),
              onRemove: () => onRemove(i),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(child: KyleAddFoodButton(onPressed: onAddFood)),
        ],
      ),
    );
  }
}

/// Expandable component row used only in the Before edit state. Collapsed it
/// shows the food chip + live label + chevron, and supports swipe-right to
/// Delete / swipe-left to Swap (mirroring the workout fuel-plan edit pattern).
/// Expanded it reveals the orange quantity stepper, a live Nutrition Facts
/// panel, and (when more than one component remains) a "Remove food item" link.
///
/// When [showSwipeHint] is true, the row plays a one-time nudge on first build
/// (left to flash Swap, right to flash Delete, then settle) so the otherwise
/// hidden swipe gestures are discoverable. The parent enables it for the first
/// row only.
class _EditComponentRow extends StatefulWidget {
  const _EditComponentRow({
    required this.component,
    required this.expanded,
    required this.canRemove,
    required this.qtyMin,
    required this.qtyStep,
    required this.onToggle,
    required this.onQuantityChanged,
    required this.onSwap,
    required this.onRemove,
    this.showSwipeHint = false,
  });

  final BeforeComponent component;
  final bool expanded;
  final bool canRemove;
  final double qtyMin;
  final double qtyStep;
  final VoidCallback onToggle;
  final void Function(double quantity) onQuantityChanged;
  final VoidCallback onSwap;
  final VoidCallback onRemove;
  final bool showSwipeHint;

  @override
  State<_EditComponentRow> createState() => _EditComponentRowState();
}

class _EditComponentRowState extends State<_EditComponentRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hintController;
  late final Animation<double> _hintOffset;
  bool _hasPlayedHint = false;

  @override
  void initState() {
    super.initState();
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _hintOffset = TweenSequence<double>([
      // Slide left to flash the Swap action.
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -72.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(tween: ConstantTween(-72.0), weight: 14),
      // Slide right to flash the Delete action.
      TweenSequenceItem(
        tween: Tween(begin: -72.0, end: 72.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 26,
      ),
      TweenSequenceItem(tween: ConstantTween(72.0), weight: 14),
      // Settle back to rest.
      TweenSequenceItem(
        tween: Tween(begin: 72.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_hintController);

    if (widget.showSwipeHint) _playHint();
  }

  void _playHint() {
    if (_hasPlayedHint) return;
    _hasPlayedHint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hintController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  Widget _buildCard(BuildContext context, ColorScheme scheme) {
    return BaseCard(
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const FaIcon(
                      FontAwesomeIcons.utensils,
                      size: 14,
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _componentLabel(widget.component),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: FaIcon(
                      FontAwesomeIcons.chevronDown,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: AppSpacing.md, color: scheme.outlineVariant),
                  // Quantity: label on the left, compact orange stepper pill
                  // on the right (matches the fuel-plan edit control).
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      _QtyStepper(
                        value: widget.component.quantity,
                        min: widget.qtyMin,
                        step: widget.qtyStep,
                        onChanged: widget.onQuantityChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Nutrition Facts',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ComponentNutritionFacts(component: widget.component),
                  if (widget.canRemove) ...[
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: InkWell(
                        onTap: widget.onRemove,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.trash,
                              size: 14,
                              color: AppColors.dragonfruit,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Remove food item',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.dragonfruit,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = _buildCard(context, scheme);

    // Swipe-right reveals Delete (dragonfruit); swipe-left reveals Swap
    // (electrolyte). confirmDismiss never lets the tile actually dismiss —
    // the parent owns draft state and rebuilds, matching the fuel-plan flow.
    return Dismissible(
      key: ValueKey('edit_${widget.component.foodKey}'),
      background: const _SwipeAction(
        color: AppColors.dragonfruit,
        alignment: Alignment.centerLeft,
        icon: FontAwesomeIcons.trash,
        label: 'Delete',
        iconLeading: true,
      ),
      secondaryBackground: const _SwipeAction(
        color: AppColors.electrolyte,
        alignment: Alignment.centerRight,
        icon: FontAwesomeIcons.arrowRightArrowLeft,
        label: 'Swap',
        iconLeading: false,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (widget.canRemove) widget.onRemove();
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          widget.onSwap();
          return false;
        }
        return false;
      },
      child: _hasPlayedHint ? _buildHinted(card) : card,
    );
  }

  /// Wraps [card] so the one-time hint can flash the swipe backgrounds behind
  /// it as it nudges left then right. Only built once the hint has started.
  Widget _buildHinted(Widget card) {
    return AnimatedBuilder(
      animation: _hintOffset,
      builder: (context, child) {
        final offset = _hintOffset.value;
        return ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: Stack(
            children: [
              // Swap flashes on the right as the card slides left.
              if (offset < 0)
                const Positioned.fill(
                  child: _SwipeAction(
                    color: AppColors.electrolyte,
                    alignment: Alignment.centerRight,
                    icon: FontAwesomeIcons.arrowRightArrowLeft,
                    label: 'Swap',
                    iconLeading: false,
                  ),
                ),
              // Delete flashes on the left as the card slides right.
              if (offset > 0)
                const Positioned.fill(
                  child: _SwipeAction(
                    color: AppColors.dragonfruit,
                    alignment: Alignment.centerLeft,
                    icon: FontAwesomeIcons.trash,
                    label: 'Delete',
                    iconLeading: true,
                  ),
                ),
              Transform.translate(offset: Offset(offset, 0), child: child),
            ],
          ),
        );
      },
      child: card,
    );
  }
}

/// Build a component's display label at its current quantity, matching the
/// read-mode formatting (e.g. `1 cup Oatmeal`, `0.5 Bagels`).
String _componentLabel(BeforeComponent c) {
  final qtyStr = _formatQuantity(c.quantity);
  if (c.displayName == null) {
    final human = c.foodKey
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
    return '$qtyStr $human';
  }
  return FoodItemData.buildDisplayQuantity(
    rawQty: qtyStr,
    servingUnit: c.servingUnit,
    displayName: c.displayName,
    displayNamePlural: c.displayNamePlural,
  );
}

/// Mirror of the controller's quantity formatter: `1` (not `1.0`), `0.5`, `1.5`.
String _formatQuantity(double qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  return qty.toStringAsFixed(qty.toStringAsFixed(2).endsWith('0') ? 1 : 2);
}

/// Cream pill "+ Make this mine" — read-state entry into the edit flow.
class _MakeMineButton extends StatelessWidget {
  const _MakeMineButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      borderRadius: AppRadius.circularRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.circularRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                FontAwesomeIcons.plus,
                size: 11,
                color: AppColors.blackberry,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Make this mine',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackberry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Orange Save pill shown in the edit-state app bar.
class _SavePillButton extends StatelessWidget {
  const _SavePillButton({
    super.key,
    required this.onPressed,
    this.saving = false,
  });

  final VoidCallback? onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: AppColors.orange,
        borderRadius: AppRadius.circularRadius,
        child: InkWell(
          onTap: saving ? null : onPressed,
          borderRadius: AppRadius.circularRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blackberry,
                    ),
                  )
                : Text(
                    'Save',
                    style: AppTextStyles.buttonPrimary.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blackberry,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Electrolyte "Swap" button inside an expanded component row.
/// Compact orange-bordered quantity stepper pill (minus / value / plus),
/// mirroring the workout fuel-plan edit control. Decrement is guarded at [min].
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.min,
    required this.step,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double step;
  final void Function(double quantity) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDecrement = value - step >= min - 1e-9;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.orange, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const FaIcon(
              FontAwesomeIcons.minus,
              size: 14,
              color: AppColors.orange,
            ),
            onPressed: canDecrement ? () => onChanged(value - step) : null,
          ),
          Text(
            _formatQuantity(value),
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const FaIcon(
              FontAwesomeIcons.plus,
              size: 14,
              color: AppColors.orange,
            ),
            onPressed: () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

/// Live per-component Nutrition Facts panel shown in the expanded edit row.
/// Recomputes from the component's per-serving macros × current quantity.
class _ComponentNutritionFacts extends StatelessWidget {
  const _ComponentNutritionFacts({required this.component});

  final BeforeComponent component;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = component.quantity;
    final carbs = component.carbsPerServing * q;
    final protein = component.proteinPerServing * q;
    final fat = component.fatPerServing * q;
    final calories = ((carbs * 4) + (protein * 4) + (fat * 9)).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NutritionStat(value: '$calories', label: 'CALORIES'),
          _NutritionStat(value: '${carbs.round()}g', label: 'CARBS'),
          _NutritionStat(value: '${protein.round()}g', label: 'PROTEIN'),
          _NutritionStat(value: '${fat.round()}g', label: 'FAT'),
        ],
      ),
    );
  }
}

class _NutritionStat extends StatelessWidget {
  const _NutritionStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: scheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

/// Full-bleed swipe-action background (Delete / Swap) revealed behind an
/// edit component row as it is dragged.
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.color,
    required this.alignment,
    required this.icon,
    required this.label,
    required this.iconLeading,
  });

  final Color color;
  final Alignment alignment;
  final FaIconData icon;
  final String label;
  final bool iconLeading;

  @override
  Widget build(BuildContext context) {
    final iconWidget = FaIcon(icon, color: Colors.white, size: 18);
    final text = Text(
      label,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: iconLeading
            ? [iconWidget, const SizedBox(width: AppSpacing.sm), text]
            : [text, const SizedBox(width: AppSpacing.sm), iconWidget],
      ),
    );
  }
}

/// Minimal "coming soon" sheet used by the PR 4 Swap / Add Food placeholders.
class _ComingSoonSheet extends StatelessWidget {
  const _ComingSoonSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Swapping and adding foods is coming in a future update. For '
              'now you can adjust quantities to personalize this formula.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── During body ──────────────────────────────────────────────────────────

class _DuringDetailBody extends StatelessWidget {
  const _DuringDetailBody({required this.formula});

  final DuringFormulaView formula;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveScrollableBody(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (formula.foodForm.isNotEmpty)
                _InfoPill(
                  label: formula.foodForm,
                  color: AppColors.electrolyte,
                ),
              if (formula.primaryToSecondaryRatio != null)
                _InfoPill(
                  label: 'Ratio ${formula.primaryToSecondaryRatio}',
                  color: AppColors.orange,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (formula.activityTypes.isNotEmpty) ...[
            _SectionLabel(text: 'Activities'),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final a in formula.activityTypes)
                  _Tag(label: _humanActivity(a)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formula.durationBrackets.isNotEmpty)
                Expanded(
                  child: _LabeledList(
                    label: 'Duration',
                    items: formula.durationBrackets,
                  ),
                ),
              if (formula.gutTrainingLevels.isNotEmpty)
                Expanded(
                  child: _LabeledList(
                    label: 'Gut training',
                    items: formula.gutTrainingLevels
                        .map((g) =>
                            '${g[0].toUpperCase()}${g.substring(1)}')
                        .toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          BaseCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formula.componentFoodNames.isEmpty
                        ? formula.formula
                        : formula.componentFoodNames.join(', '),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.boltLightning,
                          size: 12,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Macros scale to your hourly carb target',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionLabel(text: 'Notes'),
            const SizedBox(height: AppSpacing.xs),
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  formula.notes!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (formula.allergens.isNotEmpty ||
              formula.excludedDiets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DietTags(
              allergens: formula.allergens,
              excludedDiets: formula.excludedDiets,
            ),
          ],
        ],
      ),
    );
  }

  String _humanActivity(String raw) {
    return switch (raw) {
      'triathlon_bike' => 'Tri — Bike',
      'triathlon_run' => 'Tri — Run',
      'triathlon_transition' => 'Tri — Transition',
      _ => raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}',
    };
  }
}

// ─── After body ───────────────────────────────────────────────────────────

/// Read-only detail body for an After-phase formula. Unlike Before/During,
/// the After phase has no body-size scaling target — a template represents
/// a single canonical portion. We surface the portion description, Notion
/// taxonomy chips (travel / prep / flavor / protein anchor / carb:protein
/// ratio), the formula's component foods, and dietary tags. No macros card
/// (post_workout_templates does not store macros directly in V1) and no
/// quantity stepper.
class _AfterDetailBody extends StatelessWidget {
  const _AfterDetailBody({required this.formula});

  final AfterFormulaView formula;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveScrollableBody(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (formula.travelFriendliness != null &&
                  formula.travelFriendliness!.isNotEmpty)
                _InfoPill(
                  label: _humanize(formula.travelFriendliness!),
                  color: AppColors.electrolyte,
                ),
              if (formula.prepEffort != null &&
                  formula.prepEffort!.isNotEmpty)
                _InfoPill(
                  label: _humanize(formula.prepEffort!),
                  color: AppColors.electrolyte,
                ),
              if (formula.flavorProfile != null &&
                  formula.flavorProfile!.isNotEmpty)
                _InfoPill(
                  label: _humanize(formula.flavorProfile!),
                  color: AppColors.electrolyte,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MacrosCard(
            calories: formula.totalCalories,
            carbs: formula.totalCarbsG,
            protein: formula.totalProteinG,
            fat: formula.totalFatG,
            sodium: formula.totalSodiumMg,
            fluid: formula.totalFluidMl,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          if (formula.componentDisplayStrings.isEmpty)
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  formula.formula.isEmpty
                      ? 'No components listed.'
                      : formula.formula,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < formula.componentDisplayStrings.length;
                i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _ComponentRow(label: formula.componentDisplayStrings[i]),
            ],
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionLabel(text: 'Notes'),
            const SizedBox(height: AppSpacing.xs),
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  formula.notes!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (formula.allergens.isNotEmpty ||
              formula.excludedDiets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DietTags(
              allergens: formula.allergens,
              excludedDiets: formula.excludedDiets,
            ),
          ],
        ],
      ),
    );
  }

  String _humanize(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

// ─── Shared bits ──────────────────────────────────────────────────────────

/// A single component row used in the Before-formula detail "Components"
/// section. Renders as its own card with an orange utensil-icon badge on the
/// left and the pre-formatted display string (e.g. `"1 cup Blueberries"`).
class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const FaIcon(
                FontAwesomeIcons.utensils,
                size: 14,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.bodyMedium.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _LabeledList extends StatelessWidget {
  const _LabeledList({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: label),
        const SizedBox(height: AppSpacing.xs),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              i,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.sodium,
    required this.fluid,
  });

  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final double sodium;
  final double fluid;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _Macro(label: 'Cal', value: '$calories')),
                Expanded(
                    child: _Macro(label: 'Carbs', value: '${carbs.round()}g')),
                Expanded(
                    child:
                        _Macro(label: 'Protein', value: '${protein.round()}g')),
                Expanded(child: _Macro(label: 'Fat', value: '${fat.round()}g')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                    child: _Macro(
                        label: 'Sodium', value: '${sodium.round()}mg')),
                Expanded(
                    child:
                        _Macro(label: 'Fluid', value: '${fluid.round()}mL')),
                const Spacer(),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DietTags extends StatelessWidget {
  const _DietTags({required this.allergens, required this.excludedDiets});

  final List<String> allergens;
  final List<String> excludedDiets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Dietary'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final a in allergens)
              _Tag(label: 'Contains $a'),
            for (final d in excludedDiets)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dragonfruit.withValues(alpha: 0.12),
                  borderRadius: AppRadius.circularRadius,
                ),
                child: Text(
                  'Not $d',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dragonfruit,
                  ),
                ),
              ),
          ],
        ),
        if (allergens.isEmpty && excludedDiets.isEmpty)
          Text(
            'No restrictions noted.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('formula_kit.detail_not_found'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.circleQuestion,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Formula not found.',
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('formula_kit.detail_error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.circleExclamation,
              color: AppColors.dragonfruit,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load formula',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.dragonfruit,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
