import 'package:drift/drift.dart';

/// Table for storing macro nutrition targets for running sessions
@DataClassName('MacroTargetsTableData')
class MacroTargetsTable extends Table {
  /// Unique identifier for this macro target set
  TextColumn get id => text().withLength(min: 1, max: 50)();
  
  // Pre-run macros
  RealColumn get preRunCarbsG => real().named('pre_run_carbs_g')();
  RealColumn get preRunProteinG => real().named('pre_run_protein_g')();
  RealColumn get preRunFatCapG => real().named('pre_run_fat_cap_g')();
  RealColumn get preRunFluidsMl => real().named('pre_run_fluids_ml')();
  RealColumn get preRunSodiumMg => real().named('pre_run_sodium_mg')();
  
  // During-run macros
  RealColumn get duringCarbRateGPerH => real().named('during_carb_rate_g_per_h')();
  RealColumn get duringCarbTotalG => real().named('during_carb_total_g')();
  RealColumn get duringFluidRateMlPerH => real().named('during_fluid_rate_ml_per_h')();
  RealColumn get duringFluidTotalMl => real().named('during_fluid_total_ml')();
  RealColumn get duringSodiumRateMgPerH => real().named('during_sodium_rate_mg_per_h')();
  RealColumn get duringSodiumTotalMg => real().named('during_sodium_total_mg')();
  RealColumn get duringMassNormRateGPerH => real().named('during_mass_norm_rate_g_per_h').nullable()();
  
  // Post-run macros
  RealColumn get postRunCarbsG => real().named('post_run_carbs_g')();
  RealColumn get postRunProteinG => real().named('post_run_protein_g')();
  RealColumn get postRunFluidsMl => real().named('post_run_fluids_ml')();
  RealColumn get postRunSodiumMg => real().named('post_run_sodium_mg')();
  
  // Run metrics
  RealColumn get distanceMi => real().named('distance_mi')();
  RealColumn get durationH => real().named('duration_h')();
  RealColumn get paceMinPerMile => real().named('pace_min_per_mile').nullable()();
  RealColumn get caloriesGrossKcal => real().named('calories_gross_kcal')();
  RealColumn get met => real().named('met')();
  
  // Metadata
  TextColumn get calculationRule => text().named('calculation_rule')();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isUserModified => boolean().named('is_user_modified').withDefault(const Constant(false))();
  TextColumn get modifiedFields => text().named('modified_fields').withDefault(const Constant(''))();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    // Ensure positive values for nutritional data
    'CHECK (pre_run_carbs_g >= 0)',
    'CHECK (pre_run_protein_g >= 0)',
    'CHECK (pre_run_fat_cap_g >= 0)',
    'CHECK (pre_run_fluids_ml >= 0)',
    'CHECK (pre_run_sodium_mg >= 0)',
    'CHECK (during_carb_rate_g_per_h >= 0)',
    'CHECK (during_carb_total_g >= 0)',
    'CHECK (during_fluid_rate_ml_per_h >= 0)',
    'CHECK (during_fluid_total_ml >= 0)',
    'CHECK (during_sodium_rate_mg_per_h >= 0)',
    'CHECK (during_sodium_total_mg >= 0)',
    'CHECK (post_run_carbs_g >= 0)',
    'CHECK (post_run_protein_g >= 0)',
    'CHECK (post_run_fluids_ml >= 0)',
    'CHECK (post_run_sodium_mg >= 0)',
    'CHECK (distance_mi > 0)',
    'CHECK (duration_h > 0)',
    'CHECK (pace_min_per_mile IS NULL OR pace_min_per_mile > 0)',
    'CHECK (calories_gross_kcal >= 0)',
    'CHECK (met > 0)',
  ];
}