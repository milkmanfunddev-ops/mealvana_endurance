import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../auth/data/user_repository.dart';
import '../../nutrition_plan/data/template_foods_repository.dart';
import '../../nutrition_plan/domain/food.dart';
import '../data/personal_formulas_repository.dart';
import '../domain/formula_macros.dart';
import '../domain/formula_phase.dart';
import '../domain/personal_formula.dart';
import 'coach_insight_controller.dart';
import 'personal_formulas_controller.dart';

part 'formula_editor_controller.g.dart';

/// The in-progress draft of a personal formula being created or edited.
///
/// Held in the editor controller's state and mutated optimistically. Totals
/// are derived on demand from [components] via [FormulaMacros.totalsFor] — the
/// draft never stores stale totals.
class FormulaDraft {
  const FormulaDraft({
    required this.name,
    required this.phase,
    required this.components,
    this.notes,
    this.subPhase,
    this.digestSpeed,
    this.activities,
    this.durations,
    this.gutTraining,
    this.travelFriendliness,
    this.original,
  });

  final String name;
  final FormulaPhase phase;
  final List<Map<String, dynamic>> components;
  final String? notes;

  // Phase-specific scope metadata (only the relevant phase's fields are used).
  final String? subPhase;
  final String? digestSpeed;
  final List<String>? activities;
  final List<String>? durations;
  final String? gutTraining;
  final String? travelFriendliness;

  /// The persisted formula being edited, or `null` for create-from-scratch.
  final PersonalFormula? original;

  bool get isEditing => original != null;

  /// Live totals across all components.
  FormulaTotals get totals => FormulaMacros.totalsFor(components);

  /// A formula needs a name and at least one component before it can be saved.
  /// Before formulas additionally require a timing ([subPhase]): plan
  /// generation honors a before pin per sub-phase slot (meal / snack / top_up),
  /// so an untagged before formula can never be returned.
  bool get canSave =>
      name.trim().isNotEmpty &&
      components.isNotEmpty &&
      (phase != FormulaPhase.before || subPhase != null);

  FormulaDraft copyWith({
    String? name,
    FormulaPhase? phase,
    List<Map<String, dynamic>>? components,
    String? notes,
    String? subPhase,
    String? digestSpeed,
    List<String>? activities,
    List<String>? durations,
    String? gutTraining,
    String? travelFriendliness,
  }) {
    return FormulaDraft(
      name: name ?? this.name,
      phase: phase ?? this.phase,
      components: components ?? this.components,
      notes: notes ?? this.notes,
      subPhase: subPhase ?? this.subPhase,
      digestSpeed: digestSpeed ?? this.digestSpeed,
      activities: activities ?? this.activities,
      durations: durations ?? this.durations,
      gutTraining: gutTraining ?? this.gutTraining,
      travelFriendliness: travelFriendliness ?? this.travelFriendliness,
      original: original,
    );
  }
}

/// Drives the create/edit screen for a single personal formula.
///
/// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
/// for create; ignored when editing since the loaded formula carries it).
/// On save, delegates to [PersonalFormulasController] so the analytics +
/// list-invalidation happen in one place.
@riverpod
class FormulaEditorController extends _$FormulaEditorController {
  String? _userId;

  /// How many quantity-stepper edits this editing session made. Attached to
  /// the save event rather than fired per tick — a +/- stepper would spam
  /// one event per tap.
  int _quantityEditCount = 0;

  @override
  FutureOr<FormulaDraft> build(String? formulaId, FormulaPhase phase) async {
    final userRepo = await ref.read(userRepositoryProvider.future);
    _userId = (await userRepo.getCurrentUser())?.id;

    if (formulaId != null) {
      final repo = ref.read(personalFormulasRepositoryProvider);
      final existing = await repo.getById(formulaId);
      if (existing != null) {
        return FormulaDraft(
          name: existing.name,
          phase: existing.phase,
          // Backfill kAllergens/kExcludedDiets for components persisted
          // before forks carried them (FP-8: without the metadata the
          // save-time conflict disclosure can never fire on an edit).
          components: await _hydrateConflictMetadata(
            _cloneComponents(existing.components),
          ),
          notes: existing.notes,
          subPhase: existing.subPhase,
          digestSpeed: existing.digestSpeed,
          activities: existing.activities,
          durations: existing.durations,
          gutTraining: existing.gutTraining,
          travelFriendliness: existing.travelFriendliness,
          original: existing,
        );
      }
    }

    return FormulaDraft(name: '', phase: phase, components: const []);
  }

  // ── Field mutations ──────────────────────────────────────────────────────

  void setName(String name) => _patch((d) => d.copyWith(name: name));

  /// Change the formula's phase (before / during / after). Scope fields for
  /// other phases stay in state but are simply not read by the active phase's
  /// scope chips (and not honored cross-phase), so no clearing is needed.
  void setPhase(FormulaPhase phase) => _patch((d) => d.copyWith(phase: phase));

  void setNotes(String? notes) => _patch((d) => d.copyWith(notes: notes));

  void setSubPhase(String? value) => _patch((d) => d.copyWith(subPhase: value));

  void setDigestSpeed(String? value) =>
      _patch((d) => d.copyWith(digestSpeed: value));

  void setActivities(List<String>? value) =>
      _patch((d) => d.copyWith(activities: value));

  void setDurations(List<String>? value) =>
      _patch((d) => d.copyWith(durations: value));

  void setGutTraining(String? value) =>
      _patch((d) => d.copyWith(gutTraining: value));

  void setTravelFriendliness(String? value) =>
      _patch((d) => d.copyWith(travelFriendliness: value));

  // ── Component mutations ──────────────────────────────────────────────────

  /// Append a component built from a selected [food] + [quantity].
  void addComponent(Food food, double quantity, {required bool isUserFood}) {
    _patch((d) {
      final next = [
        ..._cloneComponents(d.components),
        FormulaMacros.componentFromFood(food, quantity, isUserFood: isUserFood),
      ];
      return d.copyWith(components: next);
    });
    _trackComponentEvent(
      'formula_editor_component_added',
      extra: {'is_user_food': isUserFood},
    );
  }

  /// Replace the component at [index] with a different food (swap).
  void replaceComponent(
    int index,
    Food food,
    double quantity, {
    required bool isUserFood,
  }) {
    if (!_validIndex(index)) return;
    _patch((d) {
      final next = _cloneComponents(d.components);
      next[index] = FormulaMacros.componentFromFood(
        food,
        quantity,
        isUserFood: isUserFood,
      );
      return d.copyWith(components: next);
    });
    _trackComponentEvent(
      'formula_editor_component_swapped',
      extra: {'is_user_food': isUserFood},
    );
  }

  void updateComponentQuantity(int index, double quantity) {
    if (!_validIndex(index)) return;
    _quantityEditCount++;
    _patch((d) {
      final next = _cloneComponents(d.components);
      next[index] = {...next[index], FormulaMacros.kQuantity: quantity};
      return d.copyWith(components: next);
    });
  }

  void removeComponent(int index) {
    if (!_validIndex(index)) return;
    _patch((d) {
      final next = _cloneComponents(d.components)..removeAt(index);
      return d.copyWith(components: next);
    });
    _trackComponentEvent('formula_editor_component_removed');
  }

  bool _validIndex(int index) {
    final components = state.value?.components;
    return components != null && index >= 0 && index < components.length;
  }

  /// Fire a component-mutation event with the post-mutation draft shape.
  void _trackComponentEvent(String event, {Map<String, dynamic>? extra}) {
    final draft = state.value;
    if (draft == null) return;
    final analytics = ref.read(appExternalDepsProvider).analytics;
    unawaited(
      analytics.track(
        event,
        properties: {
          'phase': draft.phase.analyticsValue,
          'is_new_formula': draft.original == null,
          'component_count': draft.components.length,
          ...?extra,
        },
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  /// Persist the draft. Returns the saved formula, or `null` if not saveable /
  /// no authenticated user.
  Future<PersonalFormula?> save() async {
    final draft = state.value;
    if (draft == null || !draft.canSave) return null;
    final userId = _userId;
    if (userId == null) return null;

    final totals = draft.totals;
    final now = DateTime.now();
    final original = draft.original;

    final currentInsight = ref
        .read(coachInsightControllerProvider(formulaId))
        .value;

    final formula = PersonalFormula(
      id: original?.id ?? '',
      userId: userId,
      name: draft.name.trim(),
      provenance: original?.provenance ?? FormulaProvenance.fromScratchFormula,
      phase: draft.phase,
      sourceTemplateId: original?.sourceTemplateId,
      sourceTemplateKind: original?.sourceTemplateKind,
      subPhase: draft.subPhase,
      digestSpeed: draft.digestSpeed,
      activities: draft.activities,
      durations: draft.durations,
      gutTraining: draft.gutTraining,
      travelFriendliness: draft.travelFriendliness,
      components: draft.components,
      notes: draft.notes,
      coachInsightText: currentInsight?.insight ?? original?.coachInsightText,
      coachInsightMarker:
          currentInsight?.staleMarker ?? original?.coachInsightMarker,
      totalCarbsG: totals.carbsG,
      totalProteinG: totals.proteinG,
      totalFatG: totals.fatG,
      totalSodiumMg: totals.sodiumMg,
      totalFluidsMl: totals.fluidsMl,
      totalCalories: totals.calories,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );

    final listController = ref.read(
      personalFormulasControllerProvider.notifier,
    );
    final saved = original != null
        ? await listController.updateFormula(
            formula,
            quantityEditCount: _quantityEditCount,
          )
        : await listController.createFormula(
            formula,
            quantityEditCount: _quantityEditCount,
          );
    if (saved != null) _quantityEditCount = 0;
    return saved;
  }

  void _patch(FormulaDraft Function(FormulaDraft) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }

  static List<Map<String, dynamic>> _cloneComponents(
    List<Map<String, dynamic>> components,
  ) {
    return components
        .map((c) => Map<String, dynamic>.from(c))
        .toList(growable: true);
  }

  /// Backfill [FormulaMacros.kAllergens]/[FormulaMacros.kExcludedDiets] on
  /// components persisted without them (pre-2026-09-03 saves and old forks),
  /// looked up from `template_foods` by food id. Components with the keys —
  /// or with no matching catalog row (user foods) — pass through untouched.
  Future<List<Map<String, dynamic>>> _hydrateConflictMetadata(
    List<Map<String, dynamic>> components,
  ) async {
    final missing = components.any(
      (c) => !c.containsKey(FormulaMacros.kAllergens),
    );
    if (!missing) return components;

    final templateFoods = await ref
        .read(templateFoodsRepositoryProvider)
        .getAllTemplateFoods();
    final byId = {for (final tf in templateFoods) tf.id: tf};

    List<String> decode(String raw) {
      try {
        final v = jsonDecode(raw);
        return v is List
            ? v.map((e) => e.toString()).toList(growable: false)
            : const [];
      } catch (_) {
        return const [];
      }
    }

    for (final c in components) {
      if (c.containsKey(FormulaMacros.kAllergens)) continue;
      final tf = byId[c[FormulaMacros.kFoodId]];
      if (tf == null) continue;
      c[FormulaMacros.kAllergens] = decode(tf.allergens);
      c[FormulaMacros.kExcludedDiets] = decode(tf.excludedDiets);
    }
    return components;
  }
}
