import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../food_preferences/data/food_preferences_repository.dart';
import '../../../formula_kit/data/formula_pins_repository.dart';
import '../../../formula_kit/data/personal_formulas_repository.dart';
import '../../../formula_kit/domain/formula_macros.dart';
import '../../../formula_kit/domain/formula_phase.dart';
import '../../../formula_kit/domain/formula_pin.dart';
import '../../../formula_kit/domain/personal_formula.dart';
import '../../data/templates_repository.dart';
import '../../domain/food_item_data.dart';
import '../../domain/macro_targets.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';
import '../../domain/sport_config.dart';
import 'client_during_phase_solver.dart';
import 'client_food_pool_service.dart';
import 'client_greedy_solver.dart';
import 'electrolyte_water_pairing.dart';

/// Orchestrates client-side nutrition plan generation.
///
/// For each phase (before/during/after), assembles a food pool and runs
/// the greedy solver to select real foods that approximate the macro targets.
/// Falls back gracefully if any phase fails (returns empty food list for
/// that phase, so the caller can use the existing generic fallback).
class ClientPlanService {
  ClientPlanService(this._ref);
  final Ref _ref;

  static const _solver = ClientGreedySolver();
  static const _duringSolver = ClientDuringPhaseSolver();

  ClientFoodPoolService get _foodPool =>
      _ref.read(clientFoodPoolServiceProvider);
  TemplatesRepository get _templatesRepo =>
      _ref.read(templatesRepositoryProvider);
  FormulaPinsRepository get _pinsRepo =>
      _ref.read(formulaPinsRepositoryProvider);
  PersonalFormulasRepository get _personalFormulasRepo =>
      _ref.read(personalFormulasRepositoryProvider);
  AppLogger get _logger => _ref.read(appExternalDepsProvider).logger;

  /// Generate a complete nutrition plan with real food selections.
  ///
  /// Throws if the food pool is completely empty (no template or user foods
  /// available), signalling the caller to fall back to the generic plan.
  ///
  /// [durationMinutes] and [gutTrainingLevel] are forwarded to the during-phase
  /// solver to improve parity with the server algorithm.
  Future<NutritionPlan> generatePlan({
    required String userId,
    required MacroTargets macroTargets,
    String? activityId,
    required double timeBeforeRunHours,
    required ActivityType activityType,
    int? durationMinutes,
    String? gutTrainingLevel,
  }) async {
    final uuid = const Uuid();
    final now = DateTime.now();

    _logger.info(
      'Client solver: generating plan for ${activityType.displayName}',
      context: 'CLIENT_PLAN_SERVICE',
    );

    // Each phase runs its solver, then the electrolyte<->water pairing
    // invariant: an electrolyte item never ships without water alongside it
    // (see electrolyte_water_pairing.dart — mirrors the edge function pass).

    // Before phase
    final beforeItems = await _pairElectrolyteWithWater(
      await _solveBefore(
        userId: userId,
        macroTargets: macroTargets,
        activityType: activityType,
        timeBeforeRunHours: timeBeforeRunHours,
      ),
      phase: 'before',
      userId: userId,
      activityType: activityType,
      fluidCeilingMl: macroTargets.preRun.fluidsHighMl,
    );

    // During phase
    final duringItems = await _pairElectrolyteWithWater(
      await _solveDuring(
        userId: userId,
        macroTargets: macroTargets,
        activityType: activityType,
        durationMinutes: durationMinutes,
        gutTrainingLevel: gutTrainingLevel,
      ),
      phase: 'during',
      userId: userId,
      activityType: activityType,
      fluidCeilingMl: macroTargets.duringRun.fluidsHighMl,
    );

    // After phase
    final afterItems = await _pairElectrolyteWithWater(
      await _solveAfter(
        userId: userId,
        macroTargets: macroTargets,
        activityType: activityType,
      ),
      phase: 'after',
      userId: userId,
      activityType: activityType,
      fluidCeilingMl: macroTargets.postRun.fluidsHighMl,
    );

    // If ALL phases produced zero foods, throw so caller uses generic fallback
    if (beforeItems.isEmpty && duringItems.isEmpty && afterItems.isEmpty) {
      throw Exception('Client solver: all phases empty — no foods available');
    }

    final pre = macroTargets.preRun;
    final during = macroTargets.duringRun;
    final post = macroTargets.postRun;

    final preSection = PlanSection(
      id: 'before_run',
      title: activityType.getSectionTitle('before'),
      subtitle: '${timeBeforeRunHours.toStringAsFixed(1)} hours before',
      timing: 'Finish eating ~60-90 min before',
      foodItems: beforeItems,
      carbsTarget: pre.carbsG,
      proteinTarget: pre.proteinG,
      fatTarget: pre.fatCapG,
      sodiumTarget: pre.sodiumMg,
      fluidsTarget: pre.fluidsMl,
    );

    final duringSection = PlanSection(
      id: 'during_run',
      title: activityType.getSectionTitle('during'),
      subtitle: 'Every 20-30 min',
      timing:
          'Spread across the activity to hit ${during.carbRateGPerH.round()}g carbs/hr',
      foodItems: duringItems,
      carbsTarget: during.carbTotalG,
      carbsLowTarget: during.carbsLowG,
      carbsHighTarget: during.carbsHighG,
      sodiumTarget: during.sodiumTotalMg,
      sodiumLowTarget: during.sodiumLowMg,
      sodiumHighTarget: during.sodiumHighMg,
      fluidsTarget: during.fluidTotalMl,
      fluidsLowTarget: during.fluidsLowMl,
      fluidsHighTarget: during.fluidsHighMl,
    );

    final postSection = PlanSection(
      id: 'after_run',
      title: activityType.getSectionTitle('after'),
      subtitle: 'Within 30 minutes',
      timing: 'Refuel quickly, then eat a full meal later',
      foodItems: afterItems,
      carbsTarget: post.carbsG,
      proteinTarget: post.proteinG,
      sodiumTarget: post.sodiumMg,
      fluidsTarget: post.fluidsMl,
    );

    // Build macro summary
    final totalCarbs = _sumNutrient(
      beforeItems,
      duringItems,
      afterItems,
      (n) => n.carbs ?? 0,
    );
    final totalProtein = _sumNutrient(
      beforeItems,
      duringItems,
      afterItems,
      (n) => n.protein ?? 0,
    );
    final totalFat = _sumNutrient(
      beforeItems,
      duringItems,
      afterItems,
      (n) => n.fat ?? 0,
    );
    final totalSodium = _sumNutrient(
      beforeItems,
      duringItems,
      afterItems,
      (n) => n.sodium ?? 0,
    );
    final totalFluids = _sumNutrientDouble(
      beforeItems,
      duringItems,
      afterItems,
      (n) => n.fluids ?? 0,
    );

    final macroSummary = PlanMacroSummary(
      calories: totalCarbs * 4 + totalProtein * 4 + totalFat * 9,
      carbs: totalCarbs,
      protein: totalProtein,
      fat: totalFat,
      sodium: totalSodium,
      fluids: (totalFluids * 0.033814).round(), // ml to oz
      carbsRange:
          'Pre ${pre.carbsG.round()}g | During ${during.carbTotalG.round()}g | Post ${post.carbsG.round()}g',
      proteinRange:
          'Pre ${pre.proteinG.round()}g | Post ${post.proteinG.round()}g',
      fatRange: 'Pre ${pre.fatCapG.round()}g',
    );

    return NutritionPlan(
      id: 'client-plan-${uuid.v4()}',
      name: 'Nutrition Plan',
      sections: [preSection, duringSection, postSection],
      macroTargets: macroSummary,
      notes:
          'Generated offline with your food preferences. Will refresh when online.',
      activityId: activityId,
      createdAt: now,
      updatedAt: now,
      clientUpdatedAt: now,
      lastModifiedBy: userId,
      version: 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Invariants
  // ---------------------------------------------------------------------------

  /// Enforce "an electrolyte item always goes with water" over one phase.
  ///
  /// The food pool is only fetched when the invariant is actually violated, so
  /// the common case costs one list scan and zero DB reads. A pool-load
  /// failure degrades to the uncorrected list rather than failing the plan —
  /// this whole service is already the offline fallback path.
  Future<List<FoodItemData>> _pairElectrolyteWithWater(
    List<FoodItemData> items, {
    required String phase,
    required String userId,
    required ActivityType activityType,
    double? fluidCeilingMl,
  }) async {
    if (!needsWaterPairing(items)) return items;

    try {
      final pool = await _foodPool.getFoodsForPhase(
        phase: phase,
        userId: userId,
        activityType: activityType,
      );
      final result = ensureElectrolyteWaterPairing(
        items,
        pool,
        fluidCeilingMl: fluidCeilingMl,
      );
      if (result.conflict != null) {
        _logger.warning(
          '$phase phase: electrolyte selected with no water alongside it and '
          'the pairing could not be enforced (${result.conflict!.name})',
          context: 'CLIENT_PLAN_SERVICE',
        );
      } else if (result.changed) {
        _logger.info(
          '$phase phase: added water alongside a dry electrolyte item',
          context: 'CLIENT_PLAN_SERVICE',
        );
      }
      return result.items;
    } catch (e) {
      _logger.warning(
        '$phase phase: electrolyte/water pairing pass failed',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
      return items;
    }
  }

  // ---------------------------------------------------------------------------
  // Phase solvers
  // ---------------------------------------------------------------------------

  /// Before phase: honor a pinned personal formula, else try template-based
  /// selection, else greedy.
  Future<List<FoodItemData>> _solveBefore({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
    required double timeBeforeRunHours,
  }) async {
    final pinned = await _tryPinnedPersonalFormula(
      userId: userId,
      phase: FormulaPhase.before,
      activityType: activityType,
      // All phases scale to their carb target (mirrors the edge honoring).
      scaleToCarbsG: macroTargets.preRun.carbsG,
      waterMlTarget: macroTargets.preRun.fluidsMl,
      sodiumMgTarget: macroTargets.preRun.sodiumMg,
    );
    if (pinned != null && pinned.isNotEmpty) return pinned;

    try {
      // Try template-based first
      final templateResult = await _tryTemplateBasedBefore(
        userId: userId,
        macroTargets: macroTargets,
        activityType: activityType,
        hoursBefore: timeBeforeRunHours,
      );
      if (templateResult != null && templateResult.isNotEmpty) {
        _logger.info(
          'Before phase: using template-based selection (${templateResult.length} foods)',
          context: 'CLIENT_PLAN_SERVICE',
        );
        return templateResult;
      }
    } catch (e) {
      _logger.warning(
        'Template-based before failed, using greedy',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
    }

    // Fall back to greedy solver
    return _solvePhase(
      userId: userId,
      phase: 'before',
      targets: SolverTargets(
        carbsG: macroTargets.preRun.carbsG,
        proteinG: macroTargets.preRun.proteinG,
        fatG: macroTargets.preRun.fatCapG,
        // Sodium v3: no pre-workout sodium target, so the greedy solver gets
        // none. Leaving `sodiumMg` at its 0 default disables sodium seeking
        // entirely (`sodiumDeficit` is gated on `> 0`) — which is the point:
        // a salted pre-workout item is doing its job, not a defect.
        // Hydration v6 gate: no fluid target stated → nothing for the
        // solver to seek (0 disables fluid seeking), not a 0-ml target.
        fluidMl: macroTargets.preRun.fluidsMl ?? 0,
      ),
      activityType: activityType,
    );
  }

  /// During phase: honor a pinned personal formula, else the server-parity
  /// rule-based during solver, else generic greedy solver.
  Future<List<FoodItemData>> _solveDuring({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
    int? durationMinutes,
    String? gutTrainingLevel,
  }) async {
    final pinned = await _tryPinnedPersonalFormula(
      userId: userId,
      phase: FormulaPhase.during,
      activityType: activityType,
      // All phases scale to their carb target (mirrors the edge honoring).
      scaleToCarbsG: macroTargets.duringRun.carbTotalG,
      waterMlTarget: macroTargets.duringRun.fluidTotalMl,
      sodiumMgTarget: macroTargets.duringRun.sodiumTotalMg,
    );
    if (pinned != null && pinned.isNotEmpty) return pinned;

    // Rule-based during solver (server-parity path)
    return _solvePhaseWithRules(
      userId: userId,
      macroTargets: macroTargets,
      activityType: activityType,
      durationMinutes: durationMinutes,
      gutTrainingLevel: gutTrainingLevel,
    );
  }

  /// Run the server-parity rule-based solver for the during phase.
  ///
  /// Falls back to the generic greedy solver if the rule solver produces no
  /// results (empty pool or error).
  Future<List<FoodItemData>> _solvePhaseWithRules({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
    int? durationMinutes,
    String? gutTrainingLevel,
  }) async {
    try {
      final foods = await _foodPool.getFoodsForPhase(
        phase: 'during',
        userId: userId,
        activityType: activityType,
      );

      if (foods.isEmpty) {
        _logger.warning(
          'No foods available for during phase (rule solver)',
          context: 'CLIENT_PLAN_SERVICE',
        );
        return [];
      }

      final targets = SolverTargets(
        carbsG: macroTargets.duringRun.carbTotalG,
        sodiumMg: macroTargets.duringRun.sodiumTotalMg,
        fluidMl: macroTargets.duringRun.fluidTotalMl,
        sodiumLowMg: macroTargets.duringRun.sodiumLowMg,
        sodiumHighMg: macroTargets.duringRun.sodiumHighMg,
        carbsLowG: macroTargets.duringRun.carbsLowG,
        carbsHighG: macroTargets.duringRun.carbsHighG,
        fluidLowMl: macroTargets.duringRun.fluidsLowMl,
        fluidHighMl: macroTargets.duringRun.fluidsHighMl,
      );

      final selections = _duringSolver.solve(
        foods: foods,
        targets: targets,
        activityType: activityType,
        gutTrainingLevel: gutTrainingLevel,
        durationMinutes: durationMinutes,
      );

      if (selections.isEmpty) {
        // Rule solver produced nothing — fall back to generic greedy
        _logger.info(
          'During rule solver produced no selections; falling back to greedy',
          context: 'CLIENT_PLAN_SERVICE',
        );
        return _solvePhase(
          userId: userId,
          phase: 'during',
          targets: targets,
          activityType: activityType,
        );
      }

      _logger.info(
        'During phase (rule solver): ${selections.length} foods selected',
        context: 'CLIENT_PLAN_SERVICE',
      );

      return selections.map((s) {
        final solverFood = foods.firstWhere((f) => f.id == s.foodId);
        return solverFood.toFoodItemData(s.quantity);
      }).toList();
    } catch (e) {
      _logger.warning(
        'During rule solver failed; falling back to greedy',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
      return _solvePhase(
        userId: userId,
        phase: 'during',
        targets: SolverTargets(
          carbsG: macroTargets.duringRun.carbTotalG,
          sodiumMg: macroTargets.duringRun.sodiumTotalMg,
          fluidMl: macroTargets.duringRun.fluidTotalMl,
        ),
        activityType: activityType,
      );
    }
  }

  /// After phase: honor a pinned personal formula, else greedy solver with
  /// protein priority.
  Future<List<FoodItemData>> _solveAfter({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
  }) async {
    final pinned = await _tryPinnedPersonalFormula(
      userId: userId,
      phase: FormulaPhase.after,
      activityType: activityType,
      // All phases scale to their carb target (mirrors the edge honoring).
      scaleToCarbsG: macroTargets.postRun.carbsG,
      waterMlTarget: macroTargets.postRun.fluidsMl,
      sodiumMgTarget: macroTargets.postRun.sodiumMg,
    );
    if (pinned != null && pinned.isNotEmpty) return pinned;

    return _solvePhase(
      userId: userId,
      phase: 'after',
      targets: SolverTargets(
        carbsG: macroTargets.postRun.carbsG,
        proteinG: macroTargets.postRun.proteinG,
        sodiumMg: macroTargets.postRun.sodiumMg,
        fluidMl: macroTargets.postRun.fluidsMl,
      ),
      activityType: activityType,
    );
  }

  /// If the user has a pinned personal formula in scope for [phase], return its
  /// components as the section's foods (honored unconditionally per the pin
  /// policy — bypasses the greedy/template path). Returns null when there's no
  /// matching pin so the caller falls through to normal selection.
  ///
  /// Scope: before pins have no activity scope. During/after pins match on
  /// activity (formula `activities` null/empty = any; multi-sport activities
  /// match leniently). Duration-bracket matching is intentionally NOT applied
  /// on the client fallback — the workout duration isn't plumbed here and this
  /// path runs only when the edge function is unavailable (~1% of generations).
  Future<List<FoodItemData>?> _tryPinnedPersonalFormula({
    required String userId,
    required FormulaPhase phase,
    required ActivityType activityType,
    double? scaleToCarbsG,
    double? waterMlTarget,
    double? sodiumMgTarget,
  }) async {
    try {
      final pins = await _pinsRepo.getActivePinsForUser(
        userId,
        kind: TemplateKind.personalFormula,
      );
      if (pins.isEmpty) return null;
      final pinnedIds = {for (final p in pins) p.templateId};

      // Newest-first; pick the first pinned formula in scope.
      final candidates = await _personalFormulasRepo.getFormulasForUser(
        userId,
        phase: phase,
      );
      PersonalFormula? match;
      for (final f in candidates) {
        if (!pinnedIds.contains(f.id)) continue;
        if (!_personalFormulaInScope(f, phase, activityType)) continue;
        match = f;
        break;
      }
      if (match == null) return null;

      final scaled = _scaleComponents(match, scaleToCarbsG: scaleToCarbsG);
      if (scaled.isEmpty) return null;

      // Failsafe (mirrors edge pin-backfill.ts): a formula scaled to its carb
      // target can still sit under the phase's fluid/sodium targets because
      // the pin path bypasses the solver's water/electrolyte fill steps.
      final extras = await _backfillPinnedFluidsAndSodium(
        scaled,
        userId: userId,
        phase: phase,
        activityType: activityType,
        waterMlTarget: waterMlTarget ?? 0,
        sodiumMgTarget: sodiumMgTarget ?? 0,
      );

      final items = [
        for (final s in scaled) _componentToFoodItem(match, s),
        ...extras,
      ];
      if (items.isEmpty) return null;
      _logger.info(
        'Client solver: honoring pinned personal formula "${match.name}" '
        'for ${phase.wireValue} (${items.length} foods)',
        context: 'CLIENT_PLAN_SERVICE',
      );
      return items;
    } catch (e) {
      _logger.warning(
        'Pinned personal formula lookup failed; falling through',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
      return null;
    }
  }

  bool _personalFormulaInScope(
    PersonalFormula formula,
    FormulaPhase phase,
    ActivityType activityType,
  ) {
    if (phase == FormulaPhase.before) {
      // Before formulas have no activity scope, but timing is required: an
      // untagged before formula never fires (mirrors the edge before-phase
      // overlay, which skips pins without a sub-phase). This client path is the
      // failure-only fallback and has no sub-phase structure, so a tagged
      // formula is honored as the whole before section.
      return formula.subPhase != null;
    }
    final activities = formula.activities;
    if (activities == null || activities.isEmpty) return true; // any
    if (activities.contains(activityType.dbValue)) return true;
    // Multi-sport workouts encompass their sub-activities; match leniently.
    return activityType.isMultiSport;
  }

  /// Scale a personal formula's components to [scaleToCarbsG], returning
  /// mutable (component, quantity) pairs so the fluid/sodium backfill can
  /// adjust quantities before items are rendered.
  ///
  /// All phases scale (decided 2026-06-12): authored quantities define the
  /// formula's composition ratio. Null/zero target or a carb-free formula
  /// keeps authored quantities verbatim.
  List<_ScaledComponent> _scaleComponents(
    PersonalFormula formula, {
    double? scaleToCarbsG,
  }) {
    final k = scaleToCarbsG == null
        ? 1.0
        : FormulaMacros.carbScaleFactor(formula.components, scaleToCarbsG);
    final scaled = <_ScaledComponent>[];
    for (final c in formula.components) {
      final authoredQty = FormulaMacros.quantityOf(c);
      if (authoredQty <= 0) continue;
      final qty = k == 1.0
          ? authoredQty
          : FormulaMacros.scaledQuantity(authoredQty, k);
      scaled.add(_ScaledComponent(c, qty));
    }
    return scaled;
  }

  /// Render one scaled component into a section food item, using the
  /// per-serving macros snapshotted on the component (no food lookup needed).
  FoodItemData _componentToFoodItem(
    PersonalFormula formula,
    _ScaledComponent s,
  ) {
    double n(Object? v) => v is num ? v.toDouble() : 0.0;
    final c = s.component;
    final qty = s.quantity;
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

    final rawQty = SolverFood.formatQuantity(qty);
    return FoodItemData(
      id: (c[FormulaMacros.kFoodId] as String?) ?? name,
      name: name,
      quantity: FoodItemData.buildDisplayQuantity(
        rawQty: rawQty,
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
      templateId: formula.id,
    );
  }

  /// Backfill a pinned formula's foods up to the phase fluid/sodium targets —
  /// failsafe mirroring the edge `pin-backfill.ts` (keep in sync).
  ///
  /// Sodium first (its fluid counts toward the fluid target), then fluid.
  /// Each prefers bumping one of the formula's own carb-free components in
  /// [scaled] (mutated in place); otherwise appends an essential food
  /// (water/salt) from the local pool. Water rounds UP in 0.5-serving steps —
  /// the plan must never come in under the fluid target. Sodium additions cap
  /// at 110% of target. Carbs are never touched.
  Future<List<FoodItemData>> _backfillPinnedFluidsAndSodium(
    List<_ScaledComponent> scaled, {
    required String userId,
    required FormulaPhase phase,
    required ActivityType activityType,
    required double waterMlTarget,
    required double sodiumMgTarget,
  }) async {
    const fluidEpsilonMl = 25.0;
    const sodiumEpsilonMg = 20.0;
    const sodiumCapRatio = 1.1;
    double n(Object? v) => v is num ? v.toDouble() : 0.0;
    double perServingOf(_ScaledComponent s, String key) => n(s.component[key]);
    double totalOf(String key) =>
        scaled.fold(0.0, (sum, s) => sum + perServingOf(s, key) * s.quantity);
    double ceilHalf(double v) => (v * 2).ceilToDouble() / 2;

    var sodiumTotal = totalOf(FormulaMacros.kSodiumMg);
    var fluidTotal = totalOf(FormulaMacros.kFluidMlPerServing);
    final sodiumDeficit = sodiumMgTarget > 0
        ? max(0.0, sodiumMgTarget - sodiumTotal)
        : 0.0;
    final fluidShort =
        waterMlTarget > 0 && waterMlTarget - fluidTotal > fluidEpsilonMl;
    if (sodiumDeficit <= sodiumEpsilonMg && !fluidShort) return const [];

    final extras = <FoodItemData>[];

    // Essential foods (water/salt) — fetched only when something is short.
    List<SolverFood> essentials = const [];
    try {
      final pool = await _foodPool.getFoodsForPhase(
        phase: phase.wireValue,
        userId: userId,
        activityType: activityType,
      );
      essentials = pool.where((f) => f.isEssential).toList();
    } catch (e) {
      _logger.warning(
        'Pin backfill: essential foods unavailable',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
    }

    // ---- 1. Sodium ----
    if (sodiumDeficit > sodiumEpsilonMg) {
      final sodiumCap = sodiumMgTarget * sodiumCapRatio;
      // Prefer the formula's own carb-free sodium component.
      _ScaledComponent? best;
      for (final s in scaled) {
        if (perServingOf(s, FormulaMacros.kCarbsPerServing) > 0) continue;
        final sodiumPer = perServingOf(s, FormulaMacros.kSodiumMg);
        if (sodiumPer <= 0) continue;
        if (best == null ||
            sodiumPer > perServingOf(best, FormulaMacros.kSodiumMg)) {
          best = s;
        }
      }
      if (best != null) {
        final sodiumPer = perServingOf(best, FormulaMacros.kSodiumMg);
        final wanted = (sodiumDeficit / sodiumPer).ceilToDouble();
        final maxForCap = ((sodiumCap - sodiumTotal) / sodiumPer)
            .floorToDouble();
        final additional = min(wanted, max(0.0, maxForCap));
        if (additional > 0) best.quantity += additional;
      } else {
        final salt =
            essentials.where((f) => f.sodiumMg > 0 && f.carbsG <= 0).toList()
              ..sort(
                (a, b) => (b.sodiumMg / max(1.0, b.fluidMl)).compareTo(
                  a.sodiumMg / max(1.0, a.fluidMl),
                ),
              );
        if (salt.isNotEmpty) {
          final f = salt.first;
          final wanted = (sodiumDeficit / f.sodiumMg).ceilToDouble();
          final maxForCap = ((sodiumCap - sodiumTotal) / f.sodiumMg)
              .floorToDouble();
          final servings = min(
            min(wanted, max(0.0, maxForCap)),
            f.maxServings.toDouble(),
          );
          if (servings > 0) extras.add(f.toFoodItemData(servings));
        }
      }
    }

    // ---- 2. Fluid (after sodium, so fluid carried by step 1 counts) ----
    sodiumTotal = totalOf(FormulaMacros.kSodiumMg);
    fluidTotal =
        totalOf(FormulaMacros.kFluidMlPerServing) +
        extras.fold(0.0, (sum, e) => sum + (e.nutritionalInfo?.fluids ?? 0));
    final fluidDeficit = waterMlTarget > 0
        ? max(0.0, waterMlTarget - fluidTotal)
        : 0.0;
    if (fluidDeficit > fluidEpsilonMl) {
      // Prefer the formula's own plain-water component.
      _ScaledComponent? water;
      for (final s in scaled) {
        if (perServingOf(s, FormulaMacros.kCarbsPerServing) > 0) continue;
        if (perServingOf(s, FormulaMacros.kSodiumMg) > 0) continue;
        final fluidPer = perServingOf(s, FormulaMacros.kFluidMlPerServing);
        if (fluidPer <= 0) continue;
        if (water == null ||
            fluidPer > perServingOf(water, FormulaMacros.kFluidMlPerServing)) {
          water = s;
        }
      }
      if (water != null) {
        // Round UP — never leave the plan under the fluid target because a
        // quantity rounded down (e.g. 4 cups where 5 are needed).
        water.quantity += ceilHalf(
          fluidDeficit / perServingOf(water, FormulaMacros.kFluidMlPerServing),
        );
      } else {
        final poolWater =
            essentials
                .where((f) => f.fluidMl > 0 && f.carbsG <= 0 && f.sodiumMg <= 0)
                .toList()
              ..sort((a, b) => b.fluidMl.compareTo(a.fluidMl));
        if (poolWater.isNotEmpty) {
          final f = poolWater.first;
          final servings = min(
            ceilHalf(fluidDeficit / f.fluidMl),
            f.maxServings.toDouble(),
          );
          extras.add(f.toFoodItemData(servings));
        } else {
          _logger.warning(
            'Pin backfill: ${fluidDeficit.round()}ml fluid short but no '
            'water source available',
            context: 'CLIENT_PLAN_SERVICE',
          );
        }
      }
    }

    return extras;
  }

  /// Run the greedy solver for a single phase.
  Future<List<FoodItemData>> _solvePhase({
    required String userId,
    required String phase,
    required SolverTargets targets,
    required ActivityType activityType,
  }) async {
    try {
      final foods = await _foodPool.getFoodsForPhase(
        phase: phase,
        userId: userId,
        activityType: activityType,
      );

      if (foods.isEmpty) {
        _logger.warning(
          'No foods available for $phase phase',
          context: 'CLIENT_PLAN_SERVICE',
        );
        return [];
      }

      final config = SportPhaseConfig.forPhase(phase, activityType);
      final selections = _solver.solve(
        foods: foods,
        targets: targets,
        phase: phase,
        config: config,
      );

      _logger.info(
        '$phase phase: ${selections.length} foods selected',
        context: 'CLIENT_PLAN_SERVICE',
      );

      return selections.map((s) {
        // Find the original SolverFood to use its toFoodItemData method
        final solverFood = foods.firstWhere((f) => f.id == s.foodId);
        return solverFood.toFoodItemData(s.quantity);
      }).toList();
    } catch (e) {
      _logger.warning(
        'Greedy solver failed for $phase phase',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Template-based before phase
  // ---------------------------------------------------------------------------

  /// Try to select a before-phase template and scale it to targets.
  ///
  /// Returns null if no suitable template is found.
  Future<List<FoodItemData>?> _tryTemplateBasedBefore({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
    required double hoursBefore,
  }) async {
    final templates = await _templatesRepo.getAllTemplates();
    if (templates.isEmpty) return null;

    // Determine meal type from hoursBefore
    final targetMealType = hoursBefore >= 2
        ? 'full_meal'
        : hoursBefore >= 1
        ? 'snack'
        : 'top_up';

    // Get user profile for allergen/dietary filtering
    final user = await _ref.read(authServiceProvider).getCurrentUser();
    final allergyDbValues =
        user?.allergies.map((a) => a.dbValue).toSet() ?? <String>{};
    final dietaryPref = user?.dietaryPreference;

    // Get disliked foods for filtering
    final prefsRepo = await _ref.read(foodPreferencesRepositoryProvider.future);
    final preferences = await prefsRepo.getFoodPreferences(userId);
    final dislikedFoodNames = preferences.entries
        .where((e) => e.value == FoodPreference.dislike)
        .map((e) => e.key)
        .toSet();

    // Filter templates
    final candidates = templates.where((t) {
      // Phase must be 'before'
      if (t.phase != 'before') return false;

      // Meal type must match (or close)
      if (t.mealType != targetMealType) return false;

      // Timing window compatibility
      final hoursBeforeMinutes = (hoursBefore * 60).round();
      if (hoursBeforeMinutes < t.timingMinMinutes) return false;
      if (hoursBeforeMinutes > t.timingMaxMinutes) return false;

      // Allergen filter
      if (allergyDbValues.isNotEmpty) {
        final templateAllergens = _parseJsonList(t.allergens);
        if (templateAllergens.any((a) => allergyDbValues.contains(a))) {
          return false;
        }
      }

      // Dietary filter
      if (dietaryPref != null) {
        final excludedDiets = _parseJsonList(t.excludedDiets);
        if (excludedDiets.contains(dietaryPref.dbValue)) return false;
      }

      // Disliked foods filter: skip template if any of its foods are disliked
      if (dislikedFoodNames.isNotEmpty) {
        final templateFoodNames = _parseJsonList(t.foodNames);
        if (templateFoodNames.any((n) => dislikedFoodNames.contains(n))) {
          return false;
        }
      }

      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    // Score by carb proximity to target (prefer templates where scale 0.5-2.0x)
    final carbTarget = macroTargets.preRun.carbsG;
    candidates.sort((a, b) {
      final scaleA = a.totalCarbsG > 0
          ? (carbTarget / a.totalCarbsG).abs()
          : 999.0;
      final scaleB = b.totalCarbsG > 0
          ? (carbTarget / b.totalCarbsG).abs()
          : 999.0;
      // Prefer scale closest to 1.0
      return (scaleA - 1.0).abs().compareTo((scaleB - 1.0).abs());
    });

    // Use best template
    final best = candidates.first;
    final scale = best.totalCarbsG > 0 ? carbTarget / best.totalCarbsG : 1.0;
    final clampedScale = scale.clamp(0.5, 2.0);

    // Parse the foods JSON array and convert to FoodItemData
    List<dynamic> foodsList;
    try {
      foodsList = jsonDecode(best.foods) as List<dynamic>;
    } catch (_) {
      return null;
    }

    final result = <FoodItemData>[];
    for (final foodJson in foodsList) {
      if (foodJson is! Map<String, dynamic>) continue;

      final foodName =
          foodJson['food_name'] as String? ??
          foodJson['display_name'] as String? ??
          'Unknown';
      final defaultServings =
          (foodJson['default_servings'] as num?)?.toDouble() ?? 1.0;
      final scaledServings = defaultServings * clampedScale;

      // Round to 0.5 increments
      final rounded = (scaledServings * 2).round() / 2;
      final quantity = max(0.5, rounded);

      final carbsPerServing = (foodJson['carbs_g'] as num?)?.toDouble() ?? 0;
      final proteinPerServing =
          (foodJson['protein_g'] as num?)?.toDouble() ?? 0;
      final fatPerServing = (foodJson['fat_g'] as num?)?.toDouble() ?? 0;
      final sodiumPerServing = (foodJson['sodium_mg'] as num?)?.toDouble() ?? 0;
      final fluidPerServing = (foodJson['fluid_ml'] as num?)?.toDouble() ?? 0;
      final caloriesPerServing =
          (foodJson['calories'] as num?)?.toInt() ??
          (carbsPerServing * 4 + proteinPerServing * 4 + fatPerServing * 9)
              .round();

      final rawQty = SolverFood.formatQuantity(quantity);
      final displayName = foodJson['display_name'] as String? ?? foodName;
      final displayNamePlural = foodJson['display_name_plural'] as String?;
      final servingUnit = foodJson['serving_unit'] as String?;

      final quantityStr = FoodItemData.buildDisplayQuantity(
        rawQty: rawQty,
        servingUnit: servingUnit,
        displayName: displayName,
        displayNamePlural: displayNamePlural,
      );

      result.add(
        FoodItemData(
          id: foodJson['food_id'] as String? ?? foodName,
          name: displayName,
          quantity: quantityStr,
          imageAddress: foodJson['image_address'] as String?,
          nutritionalInfo: NutritionalInfo(
            calories: (caloriesPerServing * quantity).round(),
            carbs: (carbsPerServing * quantity).round(),
            protein: (proteinPerServing * quantity).round(),
            fat: (fatPerServing * quantity).round(),
            sodium: (sodiumPerServing * quantity).round(),
            fluids: fluidPerServing * quantity,
          ),
          displayName: displayName,
          displayNamePlural: displayNamePlural,
          servingSize: foodJson['serving_size'] as String?,
          templateId: best.id,
          scaleMultiplier: clampedScale,
        ),
      );
    }

    return result.isEmpty ? null : result;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _sumNutrient(
    List<FoodItemData> a,
    List<FoodItemData> b,
    List<FoodItemData> c,
    int Function(NutritionalInfo) getter,
  ) {
    int sum = 0;
    for (final list in [a, b, c]) {
      for (final item in list) {
        if (item.nutritionalInfo != null) {
          sum += getter(item.nutritionalInfo!);
        }
      }
    }
    return sum;
  }

  double _sumNutrientDouble(
    List<FoodItemData> a,
    List<FoodItemData> b,
    List<FoodItemData> c,
    double Function(NutritionalInfo) getter,
  ) {
    double sum = 0;
    for (final list in [a, b, c]) {
      for (final item in list) {
        if (item.nutritionalInfo != null) {
          sum += getter(item.nutritionalInfo!);
        }
      }
    }
    return sum;
  }

  List<String> _parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }
}

/// Mutable (component, quantity) pair for pinned-formula rendering — the
/// fluid/sodium backfill adjusts quantities in place before items render.
class _ScaledComponent {
  _ScaledComponent(this.component, this.quantity);
  final Map<String, dynamic> component;
  double quantity;
}

/// Provider for [ClientPlanService].
final clientPlanServiceProvider = Provider<ClientPlanService>((ref) {
  return ClientPlanService(ref);
});
