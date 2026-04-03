import 'dart:convert';

import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/app_external_deps.dart';
import '../domain/macro_targets.dart';
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
  Future<MacroTargets?> getCachedMacroTargetsForActivity(String activityId);

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

    final targets = _mapApiResponseToMacroTargets(offlineResult['macros']);
    await saveMacroTargets(targets);
    return targets;
  }

  MacroTargets _mapApiResponseToMacroTargets(Map<String, dynamic> macros) {
    return MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityType: ActivityType.running,
      preRun: PreRunMacros(
        carbsG: (macros['pre_run_carbs_g'] as num).toDouble(),
        proteinG: (macros['pre_run_protein_g_optional'] as num).toDouble(),
        fatCapG: (macros['pre_run_fat_g_cap'] as num).toDouble(),
        fluidsMl: (macros['pre_run_water_ml'] as num).toDouble(),
        sodiumMg: (macros['pre_run_sodium_mg'] as num).toDouble(),
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: (macros['during_rate_g_per_h'] as num).toDouble(),
        carbTotalG: (macros['during_total_g'] as num).toDouble(),
        fluidRateMlPerH: (macros['during_water_rate_ml_per_h'] as num)
            .toDouble(),
        fluidTotalMl: (macros['during_water_total_ml'] as num).toDouble(),
        sodiumRateMgPerH: (macros['during_sodium_rate_mg_per_h'] as num)
            .toDouble(),
        sodiumTotalMg: (macros['during_sodium_total_mg'] as num).toDouble(),
        massNormRateGPerH: (macros['during_mass_norm_rate_g_per_h'] as num)
            .toDouble(),
        absClampRangeGPerH: [
          (macros['during_abs_clamp_range_g_per_h'][0] as num).toDouble(),
          (macros['during_abs_clamp_range_g_per_h'][1] as num).toDouble(),
        ],
      ),
      postRun: PostRunMacros(
        carbsG: (macros['post_run_carbs_g'] as num).toDouble(),
        proteinG: (macros['post_run_protein_g'] as num).toDouble(),
        fluidsMl: (macros['post_run_water_ml'] as num).toDouble(),
        sodiumMg: (macros['post_run_sodium_mg'] as num).toDouble(),
      ),
      metrics: RunMetrics(
        distanceMi: (macros['distance_mi'] as num).toDouble(),
        distanceKm: (macros['distance_km'] as num).toDouble(),
        durationH: (macros['duration_h'] as num).toDouble(),
        durationMin: (macros['duration_min'] as num).toDouble(),
        paceMinPerMile: (macros['pace_min_per_mile'] as num).toDouble(),
        speedMph: (macros['speed_mph'] as num).toDouble(),
        caloriesGrossKcal: (macros['calories_gross_kcal'] as num).toDouble(),
        caloriesNetKcal: (macros['calories_net_kcal'] as num).toDouble(),
        met: (macros['MET'] as num).toDouble(),
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
    String activityId,
  ) async {
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
