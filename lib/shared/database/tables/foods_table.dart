import 'package:drift/drift.dart';
import 'dart:convert';

/// Foods table - caches food database with nutritional information (matches Supabase schema)
@DataClassName('FoodEntry')
class FoodsTable extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get imageAddress => text().nullable().named('image_address')();
  TextColumn get description => text().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get nutritionalInfo => text().map(const CustomJsonTypeConverter()).withDefault(const Constant('{}')).named('nutritional_info')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  // Serving information
  RealColumn get servingAmount => real().nullable().named('serving_amount')();
  TextColumn get servingUnit => text().nullable().named('serving_unit')();
  TextColumn get servingUnitPlural => text().nullable().named('serving_unit_plural')();
  TextColumn get servingQualifier => text().nullable().named('serving_qualifier')();
  TextColumn get servingSize => text().nullable().named('serving_size')();

  // Suitability flags
  BoolColumn get beforeRunSuitable => boolean().withDefault(const Constant(false)).named('before_run_suitable')();
  BoolColumn get duringRunSuitable => boolean().withDefault(const Constant(false)).named('during_run_suitable')();
  BoolColumn get afterRunSuitable => boolean().withDefault(const Constant(false)).named('after_run_suitable')();
  BoolColumn get runPortable => boolean().withDefault(const Constant(false)).named('run_portable')();
  BoolColumn get requiresPreparation => boolean().withDefault(const Constant(false)).named('requires_preparation')();
  BoolColumn get aidStationAvailable => boolean().withDefault(const Constant(false)).named('aid_station_available')();
  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false)).named('is_electrolyte')();
  BoolColumn get toExcludeFromSolver => boolean().withDefault(const Constant(false)).named('to_exclude_from_solver')();
  IntColumn get maxServingsBefore => integer().nullable().named('max_servings_before')();
  IntColumn get maxServingsDuring => integer().nullable().named('max_servings_during')();
  IntColumn get maxServingsAfter => integer().nullable().named('max_servings_after')();

  // Nutritional values per serving (snake_case to match Supabase)
  IntColumn get sodiumMg => integer().nullable().named('sodium_mg')();
  IntColumn get caffeineMg => integer().nullable().named('caffeine_mg')();
  IntColumn get potassiumMg => integer().nullable().named('potassium_mg')();
  RealColumn get fatPerServing => real().nullable().named('fat_per_serving')();
  RealColumn get carbsPerServing => real().nullable().named('carbs_per_serving')();
  RealColumn get proteinPerServing => real().nullable().named('protein_per_serving')();
  IntColumn get caloriesPerServing => integer().nullable().named('calories_per_serving')();
  RealColumn get fluidMlPerServing => real().nullable().named('fluid_ml_per_serving')();

  // Branding and purchasing
  TextColumn get brandId => text().nullable().named('brand_id')();
  TextColumn get productType => text().nullable().named('product_type')();
  TextColumn get purchaseUrl => text().nullable().named('purchase_url')();
  TextColumn get affiliateSource => text().nullable().named('affiliate_source')();

  // Food preferences filtering
  BoolColumn get showInPreferences => boolean().withDefault(const Constant(false)).named('show_in_preferences')();
  IntColumn get preferencePriority => integer().withDefault(const Constant(999)).named('preference_priority')();
  TextColumn get displayName => text().nullable().withLength(max: 100).named('display_name')();
  TextColumn get displayNamePlural => text().nullable().withLength(max: 100).named('display_name_plural')();
  TextColumn get displayOverride => text().nullable().withLength(max: 100).named('display_override')();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(name)', // Unique names (case-sensitive for SQLite compatibility)
  ];
}

/// JSON type converter for nutritional info
class CustomJsonTypeConverter extends TypeConverter<Map<String, dynamic>, String> {
  const CustomJsonTypeConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    try {
      return Map<String, dynamic>.from(
        const JsonDecoder().convert(fromDb)
      );
    } catch (e) {
      return {};
    }
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return const JsonEncoder().convert(value);
  }
}