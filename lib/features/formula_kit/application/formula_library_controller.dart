import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../auth/data/user_repository.dart';
import '../../nutrition_plan/data/template_foods_repository.dart';
import '../../nutrition_plan/domain/food_item_data.dart';
import '../../onboarding/domain/allergy.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../data/during_workout_templates_repository.dart';
import '../data/formula_pins_repository.dart';
import '../data/post_workout_templates_repository.dart';
import '../data/pre_workout_templates_repository.dart';
import '../domain/after_filter_options.dart';
import '../domain/before_sub_phase.dart';
import '../domain/during_filter_options.dart';
import '../domain/formula_filter_state.dart';
import '../domain/formula_macros.dart';
import '../domain/formula_phase.dart';
import '../domain/formula_pin.dart' show TemplateKind;
import '../domain/formula_view.dart';

part 'formula_library_controller.g.dart';

/// AsyncNotifier-backed state for the Formula Library browse screen.
///
/// Owns:
///   - Filter state (phase tabs, sub-phase / activity / duration chips,
///     digestion / gut-level chips, "ignore diet" toggle).
///   - Pre-fetched Before and During formula views, derived from
///     `pre_workout_templates` + `during_workout_templates`.
///   - The user's diet + allergens, sourced from the current `UserProfile`.
///
/// PR 1 is browse-only, so this controller doesn't yet expose any
/// personalization or favorites surface — those land in PR 2-5.
class FormulaLibraryState {
  const FormulaLibraryState({
    required this.filter,
    required this.beforeFormulas,
    required this.duringFormulas,
    required this.afterFormulas,
    required this.userDiets,
    required this.userAllergies,
  });

  final FormulaFilterState filter;
  final List<BeforeFormulaView> beforeFormulas;
  final List<DuringFormulaView> duringFormulas;
  final List<AfterFormulaView> afterFormulas;

  /// Always derived from the current `UserProfile.dietaryPreference`. A
  /// single-select preference; modelled as a list to keep the matching code
  /// uniform (and to leave room for the V2 multi-select diet picker).
  final List<DietaryPreference> userDiets;
  final List<Allergy> userAllergies;

  FormulaLibraryState copyWith({
    FormulaFilterState? filter,
    List<BeforeFormulaView>? beforeFormulas,
    List<DuringFormulaView>? duringFormulas,
    List<AfterFormulaView>? afterFormulas,
    List<DietaryPreference>? userDiets,
    List<Allergy>? userAllergies,
  }) {
    return FormulaLibraryState(
      filter: filter ?? this.filter,
      beforeFormulas: beforeFormulas ?? this.beforeFormulas,
      duringFormulas: duringFormulas ?? this.duringFormulas,
      afterFormulas: afterFormulas ?? this.afterFormulas,
      userDiets: userDiets ?? this.userDiets,
      userAllergies: userAllergies ?? this.userAllergies,
    );
  }

  /// Before list with all active filters applied. Computed each access; the
  /// list is small (≤ 30 rows in V1) so memoization isn't worth the bookkeeping.
  List<BeforeFormulaView> get filteredBeforeFormulas {
    return beforeFormulas.where((f) {
      if (!_passesDietary(f.allergens, f.excludedDiets)) {
        return false;
      }
      if (filter.beforeSubPhase != null &&
          f.subPhase != filter.beforeSubPhase) {
        return false;
      }
      if (filter.beforeDigestionSpeed != null &&
          f.digestionSpeed != filter.beforeDigestionSpeed!.storageValue) {
        return false;
      }
      return true;
    }).toList();
  }

  List<DuringFormulaView> get filteredDuringFormulas {
    return duringFormulas.where((f) {
      if (!_passesDietary(f.allergens, f.excludedDiets)) {
        return false;
      }
      if (filter.duringActivity != null &&
          !f.activityTypes.contains(filter.duringActivity!.storageValue)) {
        return false;
      }
      if (filter.duringDuration != null &&
          !f.durationBrackets.contains(filter.duringDuration!.storageValue)) {
        return false;
      }
      if (filter.duringGutLevel != null &&
          !f.gutTrainingLevels.contains(filter.duringGutLevel!.storageValue)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// After list with dietary + travel-friendliness filters applied. The
  /// travel-friendliness chip is single-select — null means no filter,
  /// otherwise the list is narrowed to templates whose `travelFriendliness`
  /// matches. Templates with no `travelFriendliness` value are always shown
  /// (nothing to filter on).
  List<AfterFormulaView> get filteredAfterFormulas {
    final selected = filter.afterTravelFriendliness;
    return afterFormulas.where((f) {
      if (!_passesDietary(f.allergens, f.excludedDiets)) {
        return false;
      }
      if (selected == null) return true;
      final tf = f.travelFriendliness;
      if (tf == null) return true;
      final parsed = TravelFriendliness.fromStorageValue(tf);
      if (parsed == null) return true;
      return parsed == selected;
    }).toList();
  }

  bool _passesDietary(List<String> allergens, List<String> excludedDiets) {
    // Compare case-insensitively: the seed data stores values like "Dairy" /
    // "Gluten" (capitalized) while the user-side enums use lowercase dbValues
    // ("dairy", "gluten"). The DB will be normalized in a follow-up migration;
    // the controller stays defensive in the meantime.
    final allergensLower = allergens.map((a) => a.toLowerCase()).toSet();
    final excludedDietsLower = excludedDiets
        .map((d) => d.toLowerCase())
        .toSet();

    for (final d in filter.activeDietFilters) {
      if (excludedDietsLower.contains(d.dbValue.toLowerCase())) return false;
    }
    for (final a in filter.activeAllergyFilters) {
      if (allergensLower.contains(a.dbValue.toLowerCase())) return false;
    }
    return true;
  }

  /// Default active-filter sets implied by the user's profile. Used to
  /// determine whether the dietary section in the More Filters sheet has been
  /// modified from its out-of-the-box state.
  Set<Allergy> get profileAllergyDefaults => userAllergies.toSet();
  Set<DietaryPreference> get profileDietDefaults =>
      userDiets.where((d) => d != DietaryPreference.none).toSet();

  /// Counts the More Filters sheet fields that diverge from defaults. Diet
  /// section contributes 1 if the active set differs from the user's profile
  /// (in either direction — adding restrictions or opting out of profile ones).
  int get activeMoreFilterCount {
    var count = 0;
    if (filter.phase == FormulaPhase.before &&
        filter.beforeDigestionSpeed != null) {
      count += 1;
    }
    if (filter.phase == FormulaPhase.during && filter.duringGutLevel != null) {
      count += 1;
    }
    if (!_setEq(filter.activeAllergyFilters, profileAllergyDefaults) ||
        !_setEq(filter.activeDietFilters, profileDietDefaults)) {
      count += 1;
    }
    return count;
  }

  bool _setEq<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    for (final e in a) {
      if (!b.contains(e)) return false;
    }
    return true;
  }
}

@riverpod
class FormulaLibraryController extends _$FormulaLibraryController {
  @override
  FutureOr<FormulaLibraryState> build() async {
    final preWorkoutRepo = ref.read(preWorkoutTemplatesRepositoryProvider);
    final duringRepo = ref.read(duringWorkoutTemplatesRepositoryProvider);
    final postRepo = ref.read(postWorkoutTemplatesRepositoryProvider);
    final templateFoodsRepo = ref.read(templateFoodsRepositoryProvider);
    final pinsRepo = ref.read(formulaPinsRepositoryProvider);
    final userRepo = await ref.read(userRepositoryProvider.future);
    final logger = ref.read(appExternalDepsProvider).logger;

    // On-demand sync: only if Drift cache is empty/stale, fetch from Supabase
    // before reading. Keeps the screen useful offline for repeat visits.
    // template_foods is required so we can render component display strings
    // like "1 cup Blueberries" by joining pre_workout_templates.component_*
    // columns with template_foods.serving_unit / display_name(_plural).
    //
    // formula_pins is synced here too (#32): pins are server-authoritative for
    // cross-device visibility — a pin made on Device A must show as pinned in
    // the Library on Device B. Same shape as #31; skipping this call meant
    // the edge function honored the pin (it reads Supabase directly) while
    // the Library UI showed the formula as unpinned.
    //
    // No standalone regression test for this wiring (substep 11 decision):
    // the sync correctness is exercised by `formula_pins_repository_test.dart`
    // (dirty-preserve + tombstone propagation). A controller-level test would
    // require mocking 4+ repos for a one-line wiring change — high cost, low
    // signal. If anyone removes this call again, the failure mode is the same
    // user-visible bug (#32) and will surface in smoke testing. Future adds to
    // this build() should follow the same isStale() + syncFromRemote() pattern.
    final user = await userRepo.getCurrentUser();
    final userId = user?.id;
    if (userId != null) {
      if (await templateFoodsRepo.isStale()) {
        await templateFoodsRepo.syncFromRemote(userId);
      }
      if (await preWorkoutRepo.isStale()) {
        await preWorkoutRepo.syncFromRemote(userId);
      }
      if (await duringRepo.isStale()) {
        await duringRepo.syncFromRemote(userId);
      }
      if (await postRepo.isStale()) {
        await postRepo.syncFromRemote(userId);
      }
      if (await pinsRepo.isStale()) {
        await pinsRepo.syncFromRemote(userId);
      }
    } else {
      logger.warning(
        'FormulaLibraryController build with no authenticated user — '
        'reading from local cache only',
        context: 'FORMULA_KIT',
      );
    }

    final beforeEntries = await preWorkoutRepo.getAll();
    final duringEntries = await duringRepo.getAll();
    final afterEntries = await postRepo.getAll();
    final templateFoods = await templateFoodsRepo.getAllTemplateFoods();

    // Index template foods by their machine name (lowercased) so _mapBefore
    // can resolve `component_food_names` entries to display metadata.
    final templateFoodsByName = <String, TemplateFoodEntry>{
      for (final tf in templateFoods) tf.name.toLowerCase(): tf,
    };

    final beforeViews = beforeEntries
        .map((e) => _mapBefore(e, templateFoodsByName))
        .toList();
    final duringViews = duringEntries.map(_mapDuring).toList();
    final afterViews = afterEntries
        .map((e) => _mapAfter(e, templateFoodsByName))
        .toList();

    final userDiets = user?.dietaryPreference == null
        ? const <DietaryPreference>[]
        : [user!.dietaryPreference!];
    final userAllergies = user?.allergies ?? const <Allergy>[];

    // Seed dietary filters from the user's profile so the out-of-the-box
    // experience hides formulas with their restrictions. The user can later
    // add or remove any of the 9 allergens / any diet through the More
    // Filters sheet.
    return FormulaLibraryState(
      filter: FormulaFilterState(
        activeAllergyFilters: userAllergies.toSet(),
        activeDietFilters: userDiets
            .where((d) => d != DietaryPreference.none)
            .toSet(),
      ),
      beforeFormulas: beforeViews,
      duringFormulas: duringViews,
      afterFormulas: afterViews,
      userDiets: userDiets,
      userAllergies: userAllergies,
    );
  }

  // ── State mutations ────────────────────────────────────────────────────

  /// Switch between the Before / During / After tabs. Fires
  /// `formula_phase_switched` with `from` + `to` phase analytics values.
  Future<void> setPhase(FormulaPhase next) async {
    final current = state.value;
    if (current == null || current.filter.phase == next) return;
    final previous = current.filter.phase;
    state = AsyncData(
      current.copyWith(filter: current.filter.copyWith(phase: next)),
    );
    await _track('formula_phase_switched', {
      'from': previous.analyticsValue,
      'to': next.analyticsValue,
    });
  }

  /// Toggle a Before timing chip (Meal / Snack / Top-up).
  Future<void> toggleBeforeSubPhase(BeforeSubPhase value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.filter.beforeSubPhase == value ? null : value;
    state = AsyncData(
      current.copyWith(
        filter: current.filter.copyWith(beforeSubPhase: () => next),
      ),
    );
    if (next != null) {
      await _trackFilterApplied(
        'sub_phase',
        next.storageValue,
        current.filter.copyWith(beforeSubPhase: () => next),
      );
    }
  }

  /// Toggle the Before digestion-speed filter (More Filters sheet).
  Future<void> toggleBeforeDigestionSpeed(FormulaDigestionSpeed value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.filter.beforeDigestionSpeed == value ? null : value;
    state = AsyncData(
      current.copyWith(
        filter: current.filter.copyWith(beforeDigestionSpeed: () => next),
      ),
    );
    if (next != null) {
      await _trackFilterApplied(
        'digestion',
        next.storageValue,
        current.filter.copyWith(beforeDigestionSpeed: () => next),
      );
    }
  }

  /// Toggle a During activity chip.
  Future<void> toggleDuringActivity(DuringActivity value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.filter.duringActivity == value ? null : value;
    state = AsyncData(
      current.copyWith(
        filter: current.filter.copyWith(duringActivity: () => next),
      ),
    );
    if (next != null) {
      await _trackFilterApplied(
        'activity',
        next.storageValue,
        current.filter.copyWith(duringActivity: () => next),
      );
    }
  }

  /// Toggle a During duration chip.
  Future<void> toggleDuringDuration(DuringDuration value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.filter.duringDuration == value ? null : value;
    state = AsyncData(
      current.copyWith(
        filter: current.filter.copyWith(duringDuration: () => next),
      ),
    );
    if (next != null) {
      await _trackFilterApplied(
        'duration',
        next.storageValue,
        current.filter.copyWith(duringDuration: () => next),
      );
    }
  }

  /// Toggle the During gut-training-level chip (More Filters sheet).
  Future<void> toggleDuringGutLevel(DuringGutLevel value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.filter.duringGutLevel == value ? null : value;
    state = AsyncData(
      current.copyWith(
        filter: current.filter.copyWith(duringGutLevel: () => next),
      ),
    );
    if (next != null) {
      await _trackFilterApplied(
        'gut_training',
        next.storageValue,
        current.filter.copyWith(duringGutLevel: () => next),
      );
    }
  }

  /// Clear all More Filters sheet fields for the current phase. Phase chip
  /// filters (Timing / Activity / Duration) are left intact — those have
  /// their own clear path via [clearPhaseChipFilters]. The dietary section
  /// is reset to the user's profile defaults, not to "no filters" (matches
  /// the seeded initial state).
  void clearMoreFilters() {
    final current = state.value;
    if (current == null) return;
    final filter = current.filter;
    final profileAllergies = current.userAllergies.toSet();
    final profileDiets = current.userDiets
        .where((d) => d != DietaryPreference.none)
        .toSet();
    state = AsyncData(
      current.copyWith(
        filter: filter.copyWith(
          beforeDigestionSpeed: filter.phase == FormulaPhase.before
              ? () => null
              : null,
          duringGutLevel: filter.phase == FormulaPhase.during
              ? () => null
              : null,
          activeAllergyFilters: profileAllergies,
          activeDietFilters: profileDiets,
        ),
      ),
    );
  }

  /// Clear all phase chip filters (Timing for Before; Activity + Duration
  /// for During; Travel friendliness for After — resets to the all-three
  /// default). Sheet-level filters (digestion / gut / ignore-diet) are left
  /// intact.
  void clearPhaseChipFilters() {
    final current = state.value;
    if (current == null) return;
    final filter = current.filter;
    state = AsyncData(
      current.copyWith(
        filter: filter.copyWith(
          beforeSubPhase: filter.phase == FormulaPhase.before
              ? () => null
              : null,
          duringActivity: filter.phase == FormulaPhase.during
              ? () => null
              : null,
          duringDuration: filter.phase == FormulaPhase.during
              ? () => null
              : null,
          afterTravelFriendliness: filter.phase == FormulaPhase.after
              ? () => null
              : null,
        ),
      ),
    );
  }

  /// Toggle the After travel-friendliness chip. Single-select: tapping the
  /// active value clears the filter (returns to "show all"), tapping any
  /// other value selects it exclusively. Fires `formula_filter_applied`
  /// with the value's storage key when a value is set.
  Future<void> toggleAfterTravelFriendliness(TravelFriendliness value) async {
    final current = state.value;
    if (current == null) return;
    final next = current.filter.afterTravelFriendliness == value ? null : value;
    final nextFilter = current.filter.copyWith(
      afterTravelFriendliness: () => next,
    );
    state = AsyncData(current.copyWith(filter: nextFilter));
    if (next != null) {
      await _trackFilterApplied(
        'travel_friendliness',
        next.storageValue,
        nextFilter,
      );
    }
  }

  /// Toggle whether a specific allergy is being filtered against. When the
  /// allergy is in `activeAllergyFilters`, formulas containing it are hidden.
  /// On first build the controller seeds this set from the user's profile;
  /// the sheet lets the user opt any of the 9 allergens in or out.
  Future<void> toggleAllergyFilter(Allergy value) async {
    final current = state.value;
    if (current == null) return;
    final next = Set<Allergy>.from(current.filter.activeAllergyFilters);
    final isNowActive = !next.contains(value);
    if (isNowActive) {
      next.add(value);
    } else {
      next.remove(value);
    }
    final nextFilter = current.filter.copyWith(activeAllergyFilters: next);
    state = AsyncData(current.copyWith(filter: nextFilter));
    await _trackFilterApplied('allergen', value.dbValue, nextFilter);
  }

  /// Toggle whether a specific dietary preference is being filtered against.
  /// Mirrors [toggleAllergyFilter] for diets.
  Future<void> toggleDietFilter(DietaryPreference value) async {
    final current = state.value;
    if (current == null) return;
    final next = Set<DietaryPreference>.from(current.filter.activeDietFilters);
    final isNowActive = !next.contains(value);
    if (isNowActive) {
      next.add(value);
    } else {
      next.remove(value);
    }
    final nextFilter = current.filter.copyWith(activeDietFilters: next);
    state = AsyncData(current.copyWith(filter: nextFilter));
    await _trackFilterApplied('diet', value.dbValue, nextFilter);
  }

  /// Toggle the "pinned only" view in the AppBar. Stacks with the existing
  /// chip / dietary filters — see [FormulaFilterState.pinnedOnly] for the
  /// composition rule. Fires `pinned_filter_toggled` with the post-toggle
  /// state so we can see how often users reach for it.
  Future<void> togglePinnedOnly({required int pinnedCount}) async {
    final current = state.value;
    if (current == null) return;
    final next = !current.filter.pinnedOnly;
    state = AsyncData(
      current.copyWith(filter: current.filter.copyWith(pinnedOnly: next)),
    );
    await _track('pinned_filter_toggled', {
      'phase': current.filter.phase.analyticsValue,
      'active': next,
      'pinned_count': pinnedCount,
    });
  }

  /// Fire the entry-point analytics event. Called by the screen on mount.
  Future<void> trackLibraryOpened({required String source}) async {
    await _track('formula_library_opened', {'source': source});
  }

  /// Fire the detail-view analytics event. Called by the detail screen on mount.
  Future<void> trackDetailViewed({
    required String templateId,
    required FormulaPhase phase,
    required bool isPersonal,
  }) async {
    await _track('formula_detail_viewed', {
      'template_id': templateId,
      'phase': phase.analyticsValue,
      'is_personal': isPersonal,
    });
  }

  /// Fire the "Make this mine" tap event. Called at the very start of the
  /// fork flow so abandoned/failed forks are visible — the success case is
  /// covered separately by `personal_formula_forked` on save.
  Future<void> trackForkStarted({
    required String sourceTemplateId,
    required FormulaPhase phase,
  }) async {
    await _track('formula_fork_started', {
      'source_template_id': sourceTemplateId,
      'phase': phase.analyticsValue,
      'template_kind': _systemKindFor(phase).wireValue,
    });
  }

  /// Fire when a started fork does not reach a successful save.
  /// [reason]: 'no_user' | 'no_source_view' | 'save_failed'.
  Future<void> trackForkFailed({
    required String sourceTemplateId,
    required FormulaPhase phase,
    required String reason,
  }) async {
    await _track('formula_fork_failed', {
      'source_template_id': sourceTemplateId,
      'phase': phase.analyticsValue,
      'template_kind': _systemKindFor(phase).wireValue,
      'reason': reason,
    });
  }

  /// Fire the create-from-scratch intent event (the "New" button tap).
  Future<void> trackCreateStarted({
    required FormulaPhase phase,
    required String source,
  }) async {
    await _track('personal_formula_create_started', {
      'phase': phase.analyticsValue,
      'source': source,
    });
  }

  TemplateKind _systemKindFor(FormulaPhase phase) => switch (phase) {
    FormulaPhase.before => TemplateKind.preSystem,
    FormulaPhase.during => TemplateKind.duringSystem,
    FormulaPhase.after => TemplateKind.postSystem,
  };

  // ── Fork support ───────────────────────────────────────────────────────

  /// Build canonical [PersonalFormula.components] for the system formula
  /// [formulaId] in [phase], so "Make this mine" forks land with the source's
  /// component rows — each carrying snapshotted per-serving macros (from
  /// `template_foods`) so the editor rows and edge honoring work without extra
  /// lookups. Returns an empty list when the template can't be resolved.
  Future<List<Map<String, dynamic>>> componentsForFork(
    String formulaId,
    FormulaPhase phase,
  ) async {
    final templateFoods = await ref
        .read(templateFoodsRepositoryProvider)
        .getAllTemplateFoods();
    final byName = <String, TemplateFoodEntry>{
      for (final tf in templateFoods) tf.name.toLowerCase(): tf,
    };

    List<String> names = const [];
    Map<String, num> quantities = const {};

    switch (phase) {
      case FormulaPhase.before:
        final entries = await ref
            .read(preWorkoutTemplatesRepositoryProvider)
            .getAll();
        final e = _firstById(entries, formulaId, (x) => x.id);
        if (e == null) return const [];
        names = _decodeStringArray(e.componentFoodNames);
        quantities = _decodeQuantityMap(e.componentQuantities);
      case FormulaPhase.during:
        final entries = await ref
            .read(duringWorkoutTemplatesRepositoryProvider)
            .getAll();
        final e = _firstById(entries, formulaId, (x) => x.id);
        if (e == null) return const [];
        names = _decodeStringArray(e.componentFoodNames);
      // During templates carry carb ratios, not serving counts — default to
      // one serving per component. During formulas are intentionally
      // quantity-less in the editor (the solver derives amounts), so this
      // default is never user-visible.
      case FormulaPhase.after:
        final entries = await ref
            .read(postWorkoutTemplatesRepositoryProvider)
            .getAll();
        final e = _firstById(entries, formulaId, (x) => x.id);
        if (e == null) return const [];
        names = _decodeStringArray(e.componentFoodNames);
        quantities = _decodeQuantityMap(e.defaultServings);
    }

    final components = <Map<String, dynamic>>[];
    for (final name in names) {
      final tf = byName[name.toLowerCase()];
      final qty = (quantities[name.toLowerCase()] ?? 1).toDouble();
      final carbs = tf?.carbsG ?? 0.0;
      final protein = tf?.proteinG ?? 0.0;
      final fat = tf?.fatG ?? 0.0;
      final calories =
          tf?.calories ?? ((carbs * 4) + (protein * 4) + (fat * 9)).round();
      components.add(<String, dynamic>{
        FormulaMacros.kFoodId: tf?.id ?? name,
        FormulaMacros.kFoodName: tf?.displayName ?? _humanizeName(name),
        FormulaMacros.kQuantity: qty,
        FormulaMacros.kServingUnit: tf?.servingUnit,
        FormulaMacros.kSource: FormulaMacros.sourceTemplate,
        FormulaMacros.kCarbsPerServing: carbs,
        FormulaMacros.kProteinPerServing: protein,
        FormulaMacros.kFatPerServing: fat,
        FormulaMacros.kSodiumMg: tf?.sodiumMg ?? 0.0,
        FormulaMacros.kFluidMlPerServing: tf?.fluidMl ?? 0.0,
        FormulaMacros.kCaloriesPerServing: calories,
      });
    }
    return components;
  }

  T? _firstById<T>(List<T> items, String id, String Function(T) idOf) {
    for (final it in items) {
      if (idOf(it) == id) return it;
    }
    return null;
  }

  /// Humanise a machine component name (`medjool_dates` → `Medjool Dates`) for
  /// the rare case `template_foods` has no matching row.
  String _humanizeName(String raw) => raw
      .split('_')
      .where((s) => s.isNotEmpty)
      .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');

  // ── Mapping helpers ────────────────────────────────────────────────────

  BeforeFormulaView _mapBefore(
    PreWorkoutTemplateEntry e,
    Map<String, TemplateFoodEntry> templateFoodsByName,
  ) {
    // pre_workout_templates stores macros + component proportions as
    // PER-SERVING values. The card / detail view surfaces a single canonical
    // serving (matching the fueling-plan screen and the legacy serving_unit
    // description) — `min_servings` / `max_servings` describe scaling that's
    // the user's choice at plan time, not something we collapse into a
    // headline number here.
    final carbs = e.carbsPerServing;
    final protein = e.proteinPerServing;
    final fat = e.fatPerServing;
    final calories = ((carbs * 4) + (protein * 4) + (fat * 9)).round();

    final componentNames = _decodeStringArray(e.componentFoodNames);
    final componentQuantities = _decodeQuantityMap(e.componentQuantities);
    final componentDisplayStrings = componentNames
        .map(
          (n) => _buildComponentDisplayString(
            componentName: n,
            // Per-serving proportion straight from component_quantities,
            // no max_servings multiplier — matches the rest of the macros
            // surfaced on this view.
            proportion: componentQuantities[n.toLowerCase()] ?? 1,
            templateFoodsByName: templateFoodsByName,
          ),
        )
        .toList();

    return BeforeFormulaView(
      id: e.id,
      name: e.name,
      // pre_workout_templates has no meal_type column — derive from time_window.
      subPhase: BeforeSubPhase.fromTimeWindow(e.timeWindow),
      // Lowercase to match FormulaDigestionSpeed.storageValue (`fast`/`medium`).
      digestionSpeed: e.digestionSpeed.toLowerCase(),
      templateType: e.templateType,
      componentDisplayStrings: componentDisplayStrings,
      allergens: _decodeStringArray(e.allergens),
      excludedDiets: _decodeStringArray(e.excludedDiets),
      totalCarbsG: carbs,
      totalProteinG: protein,
      totalFatG: fat,
      totalSodiumMg: e.sodiumMg,
      totalFluidMl: e.fluidMl,
      totalCalories: calories,
      timingWindow: e.timeWindow,
      notes: e.notes,
    );
  }

  /// Produce a single component line like `"1 cup Blueberries"` or `"4 Medjool
  /// Dates"`. Falls back to a titlecased component name if `template_foods`
  /// doesn't have a matching row.
  String _buildComponentDisplayString({
    required String componentName,
    required num proportion,
    required Map<String, TemplateFoodEntry> templateFoodsByName,
  }) {
    final tf = templateFoodsByName[componentName.toLowerCase()];
    final qty = proportion.toDouble();
    final qtyStr = _formatQuantity(qty);

    if (tf == null) {
      // Best-effort fallback: prepend qty to the raw component name (which
      // is the machine identifier like "medjool_dates"). Humanise underscores.
      final humanName = componentName
          .split('_')
          .where((s) => s.isNotEmpty)
          .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
          .join(' ');
      return '$qtyStr $humanName';
    }

    return FoodItemData.buildDisplayQuantity(
      rawQty: qtyStr,
      servingUnit: tf.servingUnit,
      displayName: tf.displayName,
      displayNamePlural: tf.displayNamePlural,
    );
  }

  /// Format a numeric servings count for display: `1` (not `1.0`), `0.5`,
  /// `1.5`. Stays in sync with the conventions used by the fuel-log row and
  /// expandable food item widgets.
  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(qty.toStringAsFixed(2).endsWith('0') ? 1 : 2);
  }

  /// Decode the JSONB `component_quantities` column into a lowercased map.
  /// Stored shape is `{"banana": 1, "blueberries": 0.5}`. Returns an empty
  /// map for null / malformed input.
  Map<String, num> _decodeQuantityMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            if (entry.value is num)
              entry.key.toString().toLowerCase(): entry.value as num,
        };
      }
    } catch (_) {}
    return const {};
  }

  DuringFormulaView _mapDuring(DuringWorkoutTemplateEntry e) {
    Map<String, double>? ratios;
    if (e.componentCarbRatios != null && e.componentCarbRatios!.isNotEmpty) {
      try {
        final decoded = jsonDecode(e.componentCarbRatios!);
        if (decoded is Map) {
          ratios = decoded.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          );
        }
      } catch (_) {
        ratios = null;
      }
    }
    return DuringFormulaView(
      id: e.id,
      templateNumber: e.templateNumber,
      name: e.name,
      formula: e.formula,
      foodForm: e.foodForm,
      activityTypes: _decodeStringArray(e.activityTypes),
      durationBrackets: _decodeStringArray(e.durationBrackets),
      gutTrainingLevels: _decodeStringArray(e.gutTrainingLevels),
      componentFoodNames: _decodeStringArray(e.componentFoodNames),
      allergens: _decodeStringArray(e.allergens),
      excludedDiets: _decodeStringArray(e.excludedDiets),
      componentCarbRatios: ratios,
      primaryToSecondaryRatio: e.primaryToSecondaryRatio,
      notes: e.notes,
    );
  }

  AfterFormulaView _mapAfter(
    PostWorkoutTemplateEntry e,
    Map<String, TemplateFoodEntry> templateFoodsByName,
  ) {
    final componentNames = _decodeStringArray(e.componentFoodNames);
    // `default_servings` shape mirrors pre_workout_templates.component_quantities:
    // `{"cottage_cheese": 1, "applesauce": 1}`. Reuse the same JSON decoder.
    final defaultServings = _decodeQuantityMap(e.defaultServings);

    final componentDisplayStrings = componentNames
        .map(
          (n) => _buildComponentDisplayString(
            componentName: n,
            proportion: defaultServings[n.toLowerCase()] ?? 1,
            templateFoodsByName: templateFoodsByName,
          ),
        )
        .toList();

    // Aggregate macros by summing per-component (template_foods macros ×
    // default servings count). When a component has no matching template_foods
    // row, contribute zero — UI surfaces it as "0g" rather than crashing.
    var carbs = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    var sodium = 0.0;
    var fluid = 0.0;
    for (final name in componentNames) {
      final qty = (defaultServings[name.toLowerCase()] ?? 1).toDouble();
      final tf = templateFoodsByName[name.toLowerCase()];
      if (tf == null) continue;
      carbs += tf.carbsG * qty;
      protein += tf.proteinG * qty;
      fat += tf.fatG * qty;
      sodium += tf.sodiumMg * qty;
      fluid += (tf.fluidMl ?? 0) * qty;
    }
    final calories = ((carbs * 4) + (protein * 4) + (fat * 9)).round();

    return AfterFormulaView(
      id: e.id,
      templateNumber: e.templateNumber,
      name: e.name,
      formula: e.formula,
      activityTypes: _decodeStringArray(e.activityTypes),
      componentFoodNames: componentNames,
      componentDisplayStrings: componentDisplayStrings,
      carbSources: _decodeStringArray(e.carbSources),
      allergens: _decodeStringArray(e.allergens),
      excludedDiets: _decodeStringArray(e.excludedDiets),
      selectionPriority: e.selectionPriority,
      totalCarbsG: carbs,
      totalProteinG: protein,
      totalFatG: fat,
      totalSodiumMg: sodium,
      totalFluidMl: fluid,
      totalCalories: calories,
      portions: e.portions,
      travelFriendliness: e.travelFriendliness,
      flavorProfile: e.flavorProfile,
      prepEffort: e.prepEffort,
      proteinAnchor: e.proteinAnchor,
      targetCarbProteinRatio: e.targetCarbProteinRatio,
      notes: e.notes,
    );
  }

  List<String> _decodeStringArray(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _trackFilterApplied(
    String filterType,
    String value,
    FormulaFilterState newFilter,
  ) async {
    final current = state.value;
    final moreCount = current?.activeMoreFilterCount ?? 0;
    await _track('formula_filter_applied', {
      'filter_type': filterType,
      'value': value,
      'active_filter_count': newFilter.activeChipFilterCount + moreCount,
    });
  }

  Future<void> _track(String event, Map<String, dynamic> properties) async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(event, properties: properties);
  }
}
