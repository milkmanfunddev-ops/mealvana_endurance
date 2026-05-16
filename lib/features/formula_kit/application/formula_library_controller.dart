import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../auth/data/user_repository.dart';
import '../../nutrition_plan/data/templates_repository.dart';
import '../../onboarding/domain/allergy.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../data/during_workout_templates_repository.dart';
import '../domain/before_sub_phase.dart';
import '../domain/during_filter_options.dart';
import '../domain/formula_filter_state.dart';
import '../domain/formula_phase.dart';
import '../domain/formula_view.dart';

part 'formula_library_controller.g.dart';

/// AsyncNotifier-backed state for the Formula Library browse screen.
///
/// Owns:
///   - Filter state (phase tabs, sub-phase / activity / duration chips,
///     digestion / gut-level chips, "ignore diet" toggle).
///   - Pre-fetched Before and During formula views, derived from
///     `templates` (phase='before') + `during_workout_templates`.
///   - The user's diet + allergens, sourced from the current `UserProfile`.
///
/// PR 1 is browse-only, so this controller doesn't yet expose any
/// personalization or favorites surface — those land in PR 2-5.
class FormulaLibraryState {
  const FormulaLibraryState({
    required this.filter,
    required this.beforeFormulas,
    required this.duringFormulas,
    required this.userDiets,
    required this.userAllergies,
  });

  final FormulaFilterState filter;
  final List<BeforeFormulaView> beforeFormulas;
  final List<DuringFormulaView> duringFormulas;

  /// Always derived from the current `UserProfile.dietaryPreference`. A
  /// single-select preference; modelled as a list to keep the matching code
  /// uniform (and to leave room for the V2 multi-select diet picker).
  final List<DietaryPreference> userDiets;
  final List<Allergy> userAllergies;

  FormulaLibraryState copyWith({
    FormulaFilterState? filter,
    List<BeforeFormulaView>? beforeFormulas,
    List<DuringFormulaView>? duringFormulas,
    List<DietaryPreference>? userDiets,
    List<Allergy>? userAllergies,
  }) {
    return FormulaLibraryState(
      filter: filter ?? this.filter,
      beforeFormulas: beforeFormulas ?? this.beforeFormulas,
      duringFormulas: duringFormulas ?? this.duringFormulas,
      userDiets: userDiets ?? this.userDiets,
      userAllergies: userAllergies ?? this.userAllergies,
    );
  }

  /// Before list with all active filters applied. Computed each access; the
  /// list is small (≤ 30 rows in V1) so memoization isn't worth the bookkeeping.
  List<BeforeFormulaView> get filteredBeforeFormulas {
    return beforeFormulas.where((f) {
      if (!filter.ignoreDietaryProfile && !_passesDietary(f.allergens, f.excludedDiets)) {
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
      if (!filter.ignoreDietaryProfile && !_passesDietary(f.allergens, f.excludedDiets)) {
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

  bool _passesDietary(List<String> allergens, List<String> excludedDiets) {
    // Exclude if formula's excluded_diets intersects the user's diet.
    for (final d in userDiets) {
      if (excludedDiets.contains(d.dbValue)) return false;
    }
    // Exclude if formula's allergens intersect the user's allergens.
    for (final a in userAllergies) {
      if (allergens.contains(a.dbValue)) return false;
    }
    return true;
  }
}

@riverpod
class FormulaLibraryController extends _$FormulaLibraryController {
  @override
  FutureOr<FormulaLibraryState> build() async {
    final templatesRepo = ref.read(templatesRepositoryProvider);
    final duringRepo = ref.read(duringWorkoutTemplatesRepositoryProvider);
    final userRepo = await ref.read(userRepositoryProvider.future);
    final logger = ref.read(appExternalDepsProvider).logger;

    // On-demand sync: only if Drift cache is empty/stale, fetch from Supabase
    // before reading. Keeps the screen useful offline for repeat visits.
    final user = await userRepo.getCurrentUser();
    final userId = user?.id;
    if (userId != null) {
      // Fire-and-await sequentially so dependencies (template_foods) sync
      // before consumers — matches SyncDependencyGraph ordering.
      if (await templatesRepo.isStale()) {
        await templatesRepo.syncFromRemote(userId);
      }
      if (await duringRepo.isStale()) {
        await duringRepo.syncFromRemote(userId);
      }
    } else {
      logger.warning(
        'FormulaLibraryController build with no authenticated user — '
        'reading from local cache only',
        context: 'FORMULA_KIT',
      );
    }

    final beforeEntries = await templatesRepo.getAllTemplates();
    final duringEntries = await duringRepo.getAll();

    final beforeViews = beforeEntries
        .where((e) => e.phase == 'before')
        .map(_mapBefore)
        .toList();
    final duringViews = duringEntries.map(_mapDuring).toList();

    return FormulaLibraryState(
      filter: const FormulaFilterState(),
      beforeFormulas: beforeViews,
      duringFormulas: duringViews,
      userDiets: user?.dietaryPreference == null
          ? const []
          : [user!.dietaryPreference!],
      userAllergies: user?.allergies ?? const [],
    );
  }

  // ── State mutations ────────────────────────────────────────────────────

  /// Switch between the Before / During tabs. Fires `formula_phase_switched`.
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

  /// Clear all phase chip filters (Timing for Before; Activity + Duration
  /// for During). Sheet-level filters (digestion / gut / ignore-diet) are
  /// left intact.
  void clearPhaseChipFilters() {
    final current = state.value;
    if (current == null) return;
    final filter = current.filter;
    state = AsyncData(
      current.copyWith(
        filter: filter.copyWith(
          beforeSubPhase: filter.phase == FormulaPhase.before ? () => null : null,
          duringActivity: filter.phase == FormulaPhase.during ? () => null : null,
          duringDuration: filter.phase == FormulaPhase.during ? () => null : null,
        ),
      ),
    );
  }

  /// Toggle "Show all" — when true, the user's dietary profile is bypassed.
  Future<void> setIgnoreDietaryProfile(bool value) async {
    final current = state.value;
    if (current == null || current.filter.ignoreDietaryProfile == value) return;
    state = AsyncData(
      current.copyWith(
        filter: current.filter.copyWith(ignoreDietaryProfile: value),
      ),
    );
    if (value) {
      await _trackFilterApplied(
        'diet',
        'ignore',
        current.filter.copyWith(ignoreDietaryProfile: value),
      );
    }
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

  // ── Mapping helpers ────────────────────────────────────────────────────

  BeforeFormulaView _mapBefore(TemplateEntry e) {
    final components = _extractComponentDisplayNames(e.foods);
    return BeforeFormulaView(
      id: e.id,
      name: e.name,
      subPhase: BeforeSubPhase.fromStorageValue(e.mealType),
      digestionSpeed: e.digestionSpeed,
      componentDisplayNames: components,
      allergens: _decodeStringArray(e.allergens),
      excludedDiets: _decodeStringArray(e.excludedDiets),
      totalCarbsG: e.totalCarbsG,
      totalProteinG: e.totalProteinG,
      totalFatG: e.totalFatG,
      totalSodiumMg: e.totalSodiumMg,
      totalFluidMl: e.totalFluidMl,
      totalCalories: e.totalCalories,
      timingWindow: e.timingWindow,
      notes: e.notes,
    );
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

  /// templates.foods is stored as a JSON array of objects with
  /// `display_name` (preferred) or `food_name`. Extract a flat display list.
  List<String> _extractComponentDisplayNames(String foodsJson) {
    if (foodsJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(foodsJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => (m['display_name'] ?? m['food_name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _trackFilterApplied(
    String filterType,
    String value,
    FormulaFilterState newFilter,
  ) async {
    await _track('formula_filter_applied', {
      'filter_type': filterType,
      'value': value,
      'active_filter_count':
          newFilter.activeChipFilterCount + newFilter.activeMoreFilterCount,
    });
  }

  Future<void> _track(String event, Map<String, dynamic> properties) async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(event, properties: properties);
  }
}
