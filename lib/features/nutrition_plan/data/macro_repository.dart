import 'dart:convert';

import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/app_external_deps.dart';
import '../domain/macro_targets.dart';
import '../domain/pre_run_macros_wire.dart';
import 'offline_macro_calculator.dart';

part 'macro_repository.g.dart';

/// Repository interface for macro targets data
abstract class MacroRepository {
  /// Generate macro targets using edge function, with offline fallback
  Future<MacroTargets> generateMacroTargets({
    required double weight,
    required String weightUnit,
    required double height,
    required String heightUnit,
    required double runDistance,
    required String distanceUnit,
    required String runPace,
    required String paceUnit,
    required double timeBeforeRunMin,
    required String gutTraining,
    required int age,
    required String gender,
    HydrationCheck hydrationCheck = HydrationCheck.unknown,
  });

  /// Save macro targets to local storage
  Future<void> saveMacroTargets(MacroTargets targets);

  /// Save macro targets scoped to a specific activity ID.
  Future<void> saveMacroTargetsForActivity(
    String activityId,
    MacroTargets targets,
  );

  /// Get cached macro targets
  Future<MacroTargets?> getCachedMacroTargets();

  /// Get cached macro targets scoped to a specific activity ID.
  ///
  /// [expectedActivityType] guards the one-time legacy → scoped migration: if
  /// the global cache holds macros for a different sport (e.g. cycling cache
  /// before a run is created), the cached blob is NOT copied into this
  /// activity's slot. Pass the activity's type whenever it's known to prevent
  /// cross-sport template corruption (issue #18). When null, the legacy
  /// migration is skipped entirely — safer default than silent corruption.
  Future<MacroTargets?> getCachedMacroTargetsForActivity(
    String activityId, {
    ActivityType? expectedActivityType,
  });

  /// Update specific macro values
  Future<MacroTargets> updateMacroTargets(
    MacroTargets targets,
    MacroSection section,
    MacroField field,
    double newValue,
  );

  /// Clear cached macro targets
  Future<void> clearCachedMacroTargets();

  /// Get original macro targets for reset functionality
  Future<MacroTargets?> getOriginalMacroTargets();

  /// Get original macro targets scoped to a specific activity ID.
  Future<MacroTargets?> getOriginalMacroTargetsForActivity(String activityId);
}

/// Implementation of macro repository
class MacroRepositoryImpl implements MacroRepository {
  const MacroRepositoryImpl({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static const _cachedKey = 'macro_targets.cached';
  static const _originalKey = 'macro_targets.original';
  static const _cachedByActivityKeyPrefix = 'macro_targets.cached.activity.';
  static const _originalByActivityKeyPrefix =
      'macro_targets.original.activity.';
  static const _activityMigrationFlagPrefix =
      'macro_targets.migrated.activity.';

  @override
  Future<MacroTargets> generateMacroTargets({
    required double weight,
    required String weightUnit,
    required double height,
    required String heightUnit,
    required double runDistance,
    required String distanceUnit,
    required String runPace,
    required String paceUnit,
    required double timeBeforeRunMin,
    required String gutTraining,
    required int age,
    required String gender,
    HydrationCheck hydrationCheck = HydrationCheck.unknown,
  }) async {
    // Use offline calculation (edge function can be added later)
    return await _generateOfflineMacroTargets(
      weight: weight,
      weightUnit: weightUnit,
      height: height,
      heightUnit: heightUnit,
      runDistance: runDistance,
      distanceUnit: distanceUnit,
      runPace: runPace,
      paceUnit: paceUnit,
      timeBeforeRunMin: timeBeforeRunMin,
      gutTraining: gutTraining,
      age: age,
      gender: gender,
      hydrationCheck: hydrationCheck,
    );
  }

  Future<MacroTargets> _generateOfflineMacroTargets({
    required double weight,
    required String weightUnit,
    required double height,
    required String heightUnit,
    required double runDistance,
    required String distanceUnit,
    required String runPace,
    required String paceUnit,
    required double timeBeforeRunMin,
    required String gutTraining,
    required int age,
    required String gender,
    // Optional sweat profile — defaults mirror edge function behavior so
    // existing callers that don't pass a profile still get reasonable
    // output. Callers with a UserProfile should pass all five.
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
    HydrationCheck hydrationCheck = HydrationCheck.unknown,
  }) async {
    final offlineResult = OfflineMacroCalculator.calculateMacros(
      weight: weight,
      weightUnit: weightUnit,
      height: height,
      heightUnit: heightUnit,
      runDistance: runDistance,
      distanceUnit: distanceUnit,
      runPace: runPace,
      paceUnit: paceUnit,
      timeBeforeRunMin: timeBeforeRunMin,
      gutTraining: gutTraining,
      age: age,
      gender: gender,
    );

    var targets = _mapApiResponseToMacroTargets(offlineResult['macros']);

    // Overlay spec-compliant hydration/sodium from the new offline methods.
    // The legacy calculateMacros still drives carbs/protein/metrics; we
    // replace only the hydration/sodium fields it produced from the
    // pre-spec formulas.
    final weightKg = weightUnit.toLowerCase() == 'kg'
        ? weight
        : weight * 0.45359237;
    final durationMin = (targets.metrics.durationMin).toDouble();

    final preHydration = preWorkoutHydrationFor(
      bodyWeightKg: weightKg,
      workoutDurationMin: durationMin,
      timeBeforeWorkoutMin: timeBeforeRunMin,
      tempC: tempC,
      hydrationCheck: hydrationCheck,
    );

    final duringHydration =
        OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: durationMin,
          weightKg: weightKg,
          sweatRateCategory: sweatRateCategory,
          sweatSodiumCat: sweatSodiumCat,
          tempC: tempC,
          humidityPct: humidityPct,
          isIndoor: isIndoor,
          sport: 'running',
          knownSweatRateMlPerHour: knownSweatRateMlPerHour,
          knownSodiumConcMgPerL: knownSodiumConcMgPerL,
        );

    targets = targets.copyWith(
      preRun: PreRunMacros(
        carbsG: targets.preRun.carbsG,
        proteinG: targets.preRun.proteinG,
        fatCapG: targets.preRun.fatCapG,
        carbsLowG: targets.preRun.carbsLowG,
        carbsHighG: targets.preRun.carbsHighG,
        proteinLowG: targets.preRun.proteinLowG,
        proteinHighG: targets.preRun.proteinHighG,
        carbTargetBasis: targets.preRun.carbTargetBasis,
        carbTiers: targets.preRun.carbTiers,
        // Hydration v6 returns null for all three fluid fields on the gate
        // path, and `null` is carried through as `null` — a gated plan must
        // render "No fluid target for this session", never "0 oz" (fuel-stat
        // F-1; the `?? 0` collapse that used to live here was the
        // coach-complaint class named in the pre-workout-macros@v2 handoff).
        fluidsMl: preHydration.fluidMl,
        fluidsLowMl: preHydration.fluidLowMl,
        fluidsHighMl: preHydration.fluidHighMl,
        // Sodium v3: Mealvana sets no pre-workout sodium target, so all three
        // engine fields are permanently null and are deliberately not mapped.
        // A 0 here would be a recommendation to consume no sodium.
        hydrationRegime: preHydration.regime,
        fluidTargetBasis: preHydration.targetBasis,
        hydrationCheckUsed: preHydration.hydrationCheckUsed,
        fluidTiers: preHydration.tiers
            .map((t) => PreRunFluidTier(tier: t.tier, fluidMl: t.fluidMl))
            .toList(),
      ),
      duringRun: targets.duringRun.copyWith(
        fluidRateMlPerH: duringHydration.hydrationRateMlph.toDouble(),
        fluidTotalMl: duringHydration.hydrationTotalMl.toDouble(),
        sodiumRateMgPerH: duringHydration.sodiumRateMgph.toDouble(),
        sodiumTotalMg: duringHydration.sodiumTotalMg.toDouble(),
        effectiveSweatRateLPerH: duringHydration.effectiveSweatRateLph,
        sodiumConcMgPerL: duringHydration.sodiumConcMgPerL,
        replacementPercent: duringHydration.replacementPct,
        floorMlPerH: duringHydration.floorMlHr,
        ceilingMlPerH: duringHydration.ceilingMlHr,
        safetyFlags: duringHydration.safetyFlags,
        isTested: duringHydration.isTested,
        isTestedSodium: knownSodiumConcMgPerL != null,
        tempC: tempC,
        humidityPct: humidityPct,
        isIndoor: isIndoor,
      ),
    );

    await saveMacroTargets(targets);
    return targets;
  }

  /// The one seam through which every offline pre-workout hydration call
  /// passes, so the urine check's three values (`pale` · `dark` · `unknown`)
  /// all reach `OfflineMacroCalculator.calculatePreWorkoutHydration`
  /// (hydration v6 *The urine check*: "the plan is computed at least twice").
  /// Pure: same inputs, same outputs — no clock, no call order.
  static PreWorkoutHydrationResult preWorkoutHydrationFor({
    required double bodyWeightKg,
    required double workoutDurationMin,
    required double timeBeforeWorkoutMin,
    double? tempC,
    HydrationCheck hydrationCheck = HydrationCheck.unknown,
  }) {
    return OfflineMacroCalculator.calculatePreWorkoutHydration(
      bodyWeightKg: bodyWeightKg,
      workoutDurationMin: workoutDurationMin,
      timeBeforeWorkoutMin: timeBeforeWorkoutMin,
      tempC: tempC,
      hydrationCheck: hydrationCheck,
    );
  }

  /// The offline map is tolerant-read: a missing key is 0, never a throw.
  /// (The mapper used to cast `pre_run_protein_g_optional` / `distance_mi`,
  /// keys the map never emitted — this path threw on every call before the
  /// pre-workout-macros@v2 work made it the hydrationCheck seam.)
  static double _numOr0(Map<String, dynamic> m, String key) =>
      (m[key] as num?)?.toDouble() ?? 0;

  MacroTargets _mapApiResponseToMacroTargets(Map<String, dynamic> macros) {
    return MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: ActivityType.running,
      preRun: PreRunMacros(
        carbsG: _numOr0(macros, 'pre_run_carbs_g'),
        // The offline map emits `pre_run_protein_g` / `pre_run_fat_g`; the
        // `_optional` / `_cap` spellings were never produced by it (this
        // path threw on every call before the pre-workout-macros@v2 work).
        proteinG: _numOr0(macros, 'pre_run_protein_g'),
        fatCapG: _numOr0(macros, 'pre_run_fat_g'),
        // The legacy map's `pre_run_water_ml` (6.5 / 5.5 ml/kg, 250 ml
        // flat) is the superseded v1 engine (PW-012); it is overlaid by
        // hydration v6 below and must never reach the BEFORE card.
        fluidsMl: (macros['pre_run_water_ml'] as num?)?.toDouble(),
        // Sodium v3: no pre-workout sodium target. `pre_run_sodium_mg` is
        // deliberately not read — it is null from the current engine, and a
        // legacy non-null value is a retired target we must not resurrect.
        hydrationRegime: PreRunMacrosWire.regimeFrom(macros),
        fluidTargetBasis: macros['pre_run_fluid_target_basis'] as String?,
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: _numOr0(macros, 'during_rate_g_per_h'),
        carbTotalG: _numOr0(macros, 'during_total_g'),
        fluidRateMlPerH: (macros['during_water_rate_ml_per_h'] as num)
            .toDouble(),
        fluidTotalMl: _numOr0(macros, 'during_water_total_ml'),
        sodiumRateMgPerH: (macros['during_sodium_rate_mg_per_h'] as num)
            .toDouble(),
        sodiumTotalMg: _numOr0(macros, 'during_sodium_total_mg'),
        massNormRateGPerH: (macros['during_mass_norm_rate_g_per_h'] as num)
            .toDouble(),
        absClampRangeGPerH: [
          ((macros['during_abs_clamp_range_g_per_h'] as List?)?[0] as num?)
                  ?.toDouble() ??
              0,
          ((macros['during_abs_clamp_range_g_per_h'] as List?)?[1] as num?)
                  ?.toDouble() ??
              0,
        ],
      ),
      postRun: PostRunMacros(
        carbsG: _numOr0(macros, 'post_run_carbs_g'),
        proteinG: _numOr0(macros, 'post_run_protein_g'),
        fluidsMl: _numOr0(macros, 'post_run_water_ml'),
        sodiumMg: _numOr0(macros, 'post_run_sodium_mg'),
      ),
      metrics: RunMetrics(
        distanceMi: _numOr0(macros, 'distance_mi'),
        distanceKm: _numOr0(macros, 'distance_km'),
        durationH: _numOr0(macros, 'duration_h'),
        durationMin: _numOr0(macros, 'duration_min'),
        paceMinPerMile: _numOr0(macros, 'pace_min_per_mile'),
        speedMph: _numOr0(macros, 'speed_mph'),
        caloriesGrossKcal: _numOr0(macros, 'calories_gross_kcal'),
        caloriesNetKcal: _numOr0(macros, 'calories_net_kcal'),
        met: _numOr0(macros, 'MET'),
      ),
      calculationRule:
          macros['pre_run_carbs_rule'] as String? ?? 'Generated offline',
      timestamp: DateTime.now(),
      isUserModified: false,
      modifiedFields: [],
    );
  }

  @override
  Future<void> saveMacroTargets(MacroTargets targets) async {
    final encoded = jsonEncode(targets.toJson());
    await _prefs.setString(_cachedKey, encoded);

    if (!targets.isUserModified) {
      await _prefs.setString(_originalKey, encoded);
    }
  }

  @override
  Future<void> saveMacroTargetsForActivity(
    String activityId,
    MacroTargets targets,
  ) async {
    final normalizedActivityId = activityId.trim();
    if (normalizedActivityId.isEmpty) {
      await saveMacroTargets(targets);
      return;
    }

    final encoded = jsonEncode(targets.toJson());
    await _prefs.setString(
      _cachedKeyForActivity(normalizedActivityId),
      encoded,
    );
    await _prefs.setBool(_migrationFlagForActivity(normalizedActivityId), true);

    if (!targets.isUserModified) {
      await _prefs.setString(
        _originalKeyForActivity(normalizedActivityId),
        encoded,
      );
    }
  }

  @override
  Future<MacroTargets?> getCachedMacroTargets() async {
    return _readTargets(_cachedKey);
  }

  @override
  Future<MacroTargets?> getCachedMacroTargetsForActivity(
    String activityId, {
    ActivityType? expectedActivityType,
  }) async {
    final normalizedActivityId = activityId.trim();
    if (normalizedActivityId.isEmpty) {
      return getCachedMacroTargets();
    }

    final scoped = await _readTargets(
      _cachedKeyForActivity(normalizedActivityId),
    );
    if (scoped != null) {
      return scoped;
    }

    // One-time migration: if a keyed entry does not exist yet, copy legacy
    // global cache into this activity's keyed slot and stop relying on global.
    final migrationFlag = _migrationFlagForActivity(normalizedActivityId);
    final hasMigrated = _prefs.getBool(migrationFlag) ?? false;
    if (hasMigrated) {
      return null;
    }

    final legacyCached = await getCachedMacroTargets();
    if (legacyCached == null) {
      await _prefs.setBool(migrationFlag, true);
      return null;
    }

    // Sport guard (issue #18): the global cache is sport-agnostic and may
    // hold a different sport's plan than this activity. Without this check
    // a Run created right after a Cycling plan was generated would inherit
    // cycling templates (e.g. Bar + Sports Drink + Water), silently. Refuse
    // the copy when sports don't match — the caller will regenerate and
    // overwrite the scoped slot with the correct sport's targets.
    //
    // When expectedActivityType is null (caller doesn't know), we also
    // refuse the copy: silent corruption is worse than one regeneration.
    if (expectedActivityType == null ||
        legacyCached.activityType != expectedActivityType) {
      await _prefs.setBool(migrationFlag, true);
      return null;
    }

    await saveMacroTargetsForActivity(normalizedActivityId, legacyCached);

    final legacyOriginal = await getOriginalMacroTargets();
    if (legacyOriginal != null) {
      final encodedOriginal = jsonEncode(legacyOriginal.toJson());
      await _prefs.setString(
        _originalKeyForActivity(normalizedActivityId),
        encodedOriginal,
      );
    }

    await _prefs.setBool(migrationFlag, true);
    return legacyCached;
  }

  @override
  Future<MacroTargets> updateMacroTargets(
    MacroTargets targets,
    MacroSection section,
    MacroField field,
    double newValue,
  ) async {
    MacroTargets updatedTargets;
    final fieldKey = '${section.name}.${field.name}';

    switch (section) {
      case MacroSection.preRun:
        updatedTargets = _updatePreRunMacro(targets, field, newValue);
        break;
      case MacroSection.duringRun:
        updatedTargets = _updateDuringRunMacro(targets, field, newValue);
        break;
      case MacroSection.postRun:
        updatedTargets = _updatePostRunMacro(targets, field, newValue);
        break;
    }

    // Mark as user modified and track the field
    final modifiedFields = List<String>.from(updatedTargets.modifiedFields);
    if (!modifiedFields.contains(fieldKey)) {
      modifiedFields.add(fieldKey);
    }

    final finalTargets = updatedTargets.copyWith(
      isUserModified: true,
      modifiedFields: modifiedFields,
    );

    await saveMacroTargets(finalTargets);
    return finalTargets;
  }

  MacroTargets _updatePreRunMacro(
    MacroTargets targets,
    MacroField field,
    double newValue,
  ) {
    switch (field) {
      case MacroField.preRunCarbs:
        return targets.copyWith(
          preRun: targets.preRun.copyWith(carbsG: newValue),
        );
      case MacroField.preRunProtein:
        return targets.copyWith(
          preRun: targets.preRun.copyWith(proteinG: newValue),
        );
      case MacroField.preRunFatCap:
        return targets.copyWith(
          preRun: targets.preRun.copyWith(fatCapG: newValue),
        );
      case MacroField.preRunFluids:
        // Value is already in ml, no conversion needed
        return targets.copyWith(
          preRun: targets.preRun.copyWith(fluidsMl: newValue),
        );
      case MacroField.preRunSodium:
        return targets.copyWith(
          preRun: targets.preRun.copyWith(sodiumMg: newValue),
        );
      default:
        return targets;
    }
  }

  MacroTargets _updateDuringRunMacro(
    MacroTargets targets,
    MacroField field,
    double newValue,
  ) {
    switch (field) {
      case MacroField.duringRunCarbTotal:
        return targets.copyWith(
          duringRun: targets.duringRun.withUpdatedTotalCarbs(
            newValue,
            targets.metrics.durationH,
          ),
        );
      case MacroField.duringRunFluidTotal:
        // Value is already in ml, no conversion needed
        return targets.copyWith(
          duringRun: targets.duringRun.withUpdatedTotalFluids(
            newValue,
            targets.metrics.durationH,
          ),
        );
      case MacroField.duringRunSodiumTotal:
        return targets.copyWith(
          duringRun: targets.duringRun.withUpdatedTotalSodium(
            newValue,
            targets.metrics.durationH,
          ),
        );
      default:
        return targets;
    }
  }

  MacroTargets _updatePostRunMacro(
    MacroTargets targets,
    MacroField field,
    double newValue,
  ) {
    switch (field) {
      case MacroField.postRunCarbs:
        return targets.copyWith(
          postRun: targets.postRun.copyWith(carbsG: newValue),
        );
      case MacroField.postRunProtein:
        return targets.copyWith(
          postRun: targets.postRun.copyWith(proteinG: newValue),
        );
      case MacroField.postRunFluids:
        // Value is already in ml, no conversion needed
        return targets.copyWith(
          postRun: targets.postRun.copyWith(fluidsMl: newValue),
        );
      case MacroField.postRunSodium:
        return targets.copyWith(
          postRun: targets.postRun.copyWith(sodiumMg: newValue),
        );
      default:
        return targets;
    }
  }

  @override
  Future<void> clearCachedMacroTargets() async {
    await _prefs.remove(_cachedKey);
    await _prefs.remove(_originalKey);
  }

  @override
  Future<MacroTargets?> getOriginalMacroTargets() async {
    return _readTargets(_originalKey);
  }

  @override
  Future<MacroTargets?> getOriginalMacroTargetsForActivity(
    String activityId,
  ) async {
    final normalizedActivityId = activityId.trim();
    if (normalizedActivityId.isEmpty) {
      return getOriginalMacroTargets();
    }
    return _readTargets(_originalKeyForActivity(normalizedActivityId));
  }

  Future<MacroTargets?> _readTargets(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MacroTargets.fromJson(decoded);
    } catch (error, stackTrace) {
      DebugLogger.error('Failed to decode cached macro targets', error: error);
      DebugLogger.debug(stackTrace.toString());
      return null;
    }
  }

  String _cachedKeyForActivity(String activityId) =>
      '$_cachedByActivityKeyPrefix$activityId';

  String _originalKeyForActivity(String activityId) =>
      '$_originalByActivityKeyPrefix$activityId';

  String _migrationFlagForActivity(String activityId) =>
      '$_activityMigrationFlagPrefix$activityId';
}

@riverpod
MacroRepository macroRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MacroRepositoryImpl(sharedPreferences: prefs);
}
