import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/domain/activity_type.dart';
import '../domain/macro_targets.dart';
import 'offline_macro_calculator.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

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

  /// Get cached macro targets
  Future<MacroTargets?> getCachedMacroTargets();

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
}

/// Implementation of macro repository
class MacroRepositoryImpl implements MacroRepository {
  const MacroRepositoryImpl({
    required this.database,
  });

  final AppDatabase database;

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
        fluidRateMlPerH: (macros['during_water_rate_ml_per_h'] as num).toDouble(),
        fluidTotalMl: (macros['during_water_total_ml'] as num).toDouble(),
        sodiumRateMgPerH: (macros['during_sodium_rate_mg_per_h'] as num).toDouble(),
        sodiumTotalMg: (macros['during_sodium_total_mg'] as num).toDouble(),
        massNormRateGPerH: (macros['during_mass_norm_rate_g_per_h'] as num).toDouble(),
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
      calculationRule: macros['pre_run_carbs_rule'] as String? ?? 'Generated offline',
      timestamp: DateTime.now(),
      isUserModified: false,
      modifiedFields: [],
    );
  }

  @override
  Future<void> saveMacroTargets(MacroTargets targets) async {
    final macroTargetsCompanion = MacroTargetsTableCompanion.insert(
      id: targets.id,
      preRunCarbsG: targets.preRun.carbsG,
      preRunProteinG: targets.preRun.proteinG,
      preRunFatCapG: targets.preRun.fatCapG,
      preRunFluidsMl: targets.preRun.fluidsMl,
      preRunSodiumMg: targets.preRun.sodiumMg,
      duringCarbRateGPerH: targets.duringRun.carbRateGPerH,
      duringCarbTotalG: targets.duringRun.carbTotalG,
      duringFluidRateMlPerH: targets.duringRun.fluidRateMlPerH,
      duringFluidTotalMl: targets.duringRun.fluidTotalMl,
      duringSodiumRateMgPerH: targets.duringRun.sodiumRateMgPerH,
      duringSodiumTotalMg: targets.duringRun.sodiumTotalMg,
      duringMassNormRateGPerH: Value(targets.duringRun.massNormRateGPerH),
      postRunCarbsG: targets.postRun.carbsG,
      postRunProteinG: targets.postRun.proteinG,
      postRunFluidsMl: targets.postRun.fluidsMl,
      postRunSodiumMg: targets.postRun.sodiumMg,
      distanceMi: targets.metrics.distanceMi,
      durationH: targets.metrics.durationH,
      paceMinPerMile: Value(targets.metrics.paceMinPerMile),
      caloriesGrossKcal: targets.metrics.caloriesGrossKcal,
      met: targets.metrics.met,
      calculationRule: targets.calculationRule,
      timestamp: targets.timestamp,
      isUserModified: Value(targets.isUserModified),
      modifiedFields: Value(targets.modifiedFields.join(',')),
    );

    await database.into(database.macroTargetsTable).insertOnConflictUpdate(macroTargetsCompanion);
    
    // If this is a newly generated macro target (not user modified), also store as original
    if (!targets.isUserModified) {
      await _saveOriginalMacroTargets(targets);
    }
  }

  /// Save original macro targets for reset functionality
  Future<void> _saveOriginalMacroTargets(MacroTargets targets) async {
    // Store as a separate entry with a special ID prefix
    final originalId = 'original_${targets.id}';
    final originalTargetsCompanion = MacroTargetsTableCompanion.insert(
      id: originalId,
      preRunCarbsG: targets.preRun.carbsG,
      preRunProteinG: targets.preRun.proteinG,
      preRunFatCapG: targets.preRun.fatCapG,
      preRunFluidsMl: targets.preRun.fluidsMl,
      preRunSodiumMg: targets.preRun.sodiumMg,
      duringCarbRateGPerH: targets.duringRun.carbRateGPerH,
      duringCarbTotalG: targets.duringRun.carbTotalG,
      duringFluidRateMlPerH: targets.duringRun.fluidRateMlPerH,
      duringFluidTotalMl: targets.duringRun.fluidTotalMl,
      duringSodiumRateMgPerH: targets.duringRun.sodiumRateMgPerH,
      duringSodiumTotalMg: targets.duringRun.sodiumTotalMg,
      duringMassNormRateGPerH: Value(targets.duringRun.massNormRateGPerH),
      postRunCarbsG: targets.postRun.carbsG,
      postRunProteinG: targets.postRun.proteinG,
      postRunFluidsMl: targets.postRun.fluidsMl,
      postRunSodiumMg: targets.postRun.sodiumMg,
      distanceMi: targets.metrics.distanceMi,
      durationH: targets.metrics.durationH,
      paceMinPerMile: Value(targets.metrics.paceMinPerMile),
      caloriesGrossKcal: targets.metrics.caloriesGrossKcal,
      met: targets.metrics.met,
      calculationRule: '${targets.calculationRule} (Original)',
      timestamp: targets.timestamp,
      isUserModified: Value(false),
      modifiedFields: Value(''),
    );

    await database.into(database.macroTargetsTable).insertOnConflictUpdate(originalTargetsCompanion);
  }

  @override
  Future<MacroTargets?> getCachedMacroTargets() async {
    final query = database.select(database.macroTargetsTable)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    if (result == null) {
      DebugLogger.debug('DEBUG: No cached macro targets found');
      return null;
    }

    DebugLogger.debug('DEBUG: Found cached macro targets:');
    DebugLogger.debug('  Pre-run carbs: ${result.preRunCarbsG}g');
    DebugLogger.debug('  During-run carbs: ${result.duringCarbTotalG}g');
    DebugLogger.debug('  Post-run carbs: ${result.postRunCarbsG}g');
    DebugLogger.debug('  Total carbs should be: ${result.preRunCarbsG + result.duringCarbTotalG + result.postRunCarbsG}g');
    DebugLogger.debug('  Pre-run sodium: ${result.preRunSodiumMg}mg');
    DebugLogger.debug('  During-run sodium: ${result.duringSodiumTotalMg}mg');
    DebugLogger.debug('  Post-run sodium: ${result.postRunSodiumMg}mg');
    DebugLogger.debug('  Total sodium should be: ${result.preRunSodiumMg + result.duringSodiumTotalMg + result.postRunSodiumMg}mg');
    DebugLogger.debug('  Pre-run fluids: ${result.preRunFluidsMl}ml');
    DebugLogger.debug('  During-run fluids: ${result.duringFluidTotalMl}ml');
    DebugLogger.debug('  Post-run fluids: ${result.postRunFluidsMl}ml');
    DebugLogger.debug('  Total fluids should be: ${result.preRunFluidsMl + result.duringFluidTotalMl + result.postRunFluidsMl}ml');
    DebugLogger.debug('  isUserModified: ${result.isUserModified}');

    return _mapDatabaseRowToMacroTargets(result);
  }

  MacroTargets _mapDatabaseRowToMacroTargets(MacroTargetsTableData row) {
    return MacroTargets(
      id: row.id,
      activityType: ActivityType.running,
      preRun: PreRunMacros(
        carbsG: row.preRunCarbsG,
        proteinG: row.preRunProteinG,
        fatCapG: row.preRunFatCapG,
        fluidsMl: row.preRunFluidsMl,
        sodiumMg: row.preRunSodiumMg,
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: row.duringCarbRateGPerH,
        carbTotalG: row.duringCarbTotalG,
        fluidRateMlPerH: row.duringFluidRateMlPerH,
        fluidTotalMl: row.duringFluidTotalMl,
        sodiumRateMgPerH: row.duringSodiumRateMgPerH,
        sodiumTotalMg: row.duringSodiumTotalMg,
        massNormRateGPerH: row.duringMassNormRateGPerH ?? 0,
        absClampRangeGPerH: [30, 60], // Default values
      ),
      postRun: PostRunMacros(
        carbsG: row.postRunCarbsG,
        proteinG: row.postRunProteinG,
        fluidsMl: row.postRunFluidsMl,
        sodiumMg: row.postRunSodiumMg,
      ),
      metrics: RunMetrics(
        distanceMi: row.distanceMi,
        distanceKm: row.distanceMi * 1.60934, // Convert to km
        durationH: row.durationH,
        durationMin: row.durationH * 60,
        paceMinPerMile: row.paceMinPerMile,
        speedMph: row.paceMinPerMile != null ? 60.0 / row.paceMinPerMile! : row.distanceMi / row.durationH,
        caloriesGrossKcal: row.caloriesGrossKcal,
        caloriesNetKcal: row.caloriesGrossKcal * 0.8, // Estimate
        met: row.met,
      ),
      calculationRule: row.calculationRule,
      timestamp: row.timestamp,
      isUserModified: row.isUserModified,
      modifiedFields: row.modifiedFields.isEmpty ? [] : row.modifiedFields.split(','),
    );
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

  MacroTargets _updatePreRunMacro(MacroTargets targets, MacroField field, double newValue) {
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

  MacroTargets _updateDuringRunMacro(MacroTargets targets, MacroField field, double newValue) {
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

  MacroTargets _updatePostRunMacro(MacroTargets targets, MacroField field, double newValue) {
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
    await database.delete(database.macroTargetsTable).go();
  }

  @override
  Future<MacroTargets?> getOriginalMacroTargets() async {
    // Look for the most recent original macro targets
    final query = database.select(database.macroTargetsTable)
      ..where((t) => t.id.like('original_%'))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    if (result == null) {
      DebugLogger.debug('DEBUG: No original macro targets found');
      return null;
    }

    DebugLogger.debug('DEBUG: Found original macro targets with ID: ${result.id}');
    DebugLogger.debug('  Original pre-run carbs: ${result.preRunCarbsG}g');
    
    return _mapDatabaseRowToMacroTargets(result);
  }
}

@riverpod
Future<MacroRepository> macroRepository(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  return MacroRepositoryImpl(
    database: database,
  );
}
