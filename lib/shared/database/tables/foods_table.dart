import 'package:drift/drift.dart';

/// Foods table - master food database with nutritional information (matches new Supabase schema)
@DataClassName('FoodEntry')
class FoodsTable extends Table {
  /// UUID primary key (matches Supabase foods.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Food name (matches Supabase foods.name)
  TextColumn get name => text().nullable()();

  /// Image URL (matches Supabase foods.image_address)
  TextColumn get imageAddress => text().nullable().named('image_address')();

  /// When the food was created (matches Supabase foods.created_at)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  // Simplified serving information (matches new Supabase schema)
  RealColumn get servingAmount => real().nullable().named('serving_amount')();

  // Serving limits (matches Supabase schema)
  IntColumn get maxServingsBefore => integer().nullable().named('max_servings_before')();
  IntColumn get maxServingsDuring => integer().nullable().named('max_servings_during')();
  IntColumn get maxServingsAfter => integer().nullable().named('max_servings_after')();

  // Food suitability fields (matches Supabase schema)
  BoolColumn get beforeRunSuitable => boolean().withDefault(const Constant(false)).named('before_run_suitable')();
  BoolColumn get duringRunSuitable => boolean().withDefault(const Constant(false)).named('during_run_suitable')();
  BoolColumn get runPortable => boolean().withDefault(const Constant(false)).named('run_portable')();
  BoolColumn get requiresPreparation => boolean().withDefault(const Constant(false)).named('requires_preparation')();
  BoolColumn get aidStationAvailable => boolean().withDefault(const Constant(false)).named('aid_station_available')();

  // Nutritional values per serving (matches Supabase schema)
  IntColumn get sodiumMg => integer().nullable().named('sodium_mg')();
  IntColumn get caffeineMg => integer().nullable().named('caffeine_mg')();
  IntColumn get potassiumMg => integer().nullable().named('potassium_mg')();
  RealColumn get fatPerServing => real().nullable().named('fat_per_serving')();
  RealColumn get carbsPerServing => real().nullable().named('carbs_per_serving')();
  RealColumn get proteinPerServing => real().nullable().named('protein_per_serving')();
  IntColumn get caloriesPerServing => integer().nullable().named('calories_per_serving')();
  RealColumn get fluidMlPerServing => real().nullable().named('fluid_ml_per_serving')();


  // Food preferences and solver configuration (matches Supabase schema)
  BoolColumn get showInPreferences => boolean().withDefault(const Constant(false)).named('show_in_preferences')();
  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false)).named('is_electrolyte')();
  BoolColumn get toExcludeFromSolver => boolean().withDefault(const Constant(false)).named('to_exclude_from_solver')();

  // Display name (matches Supabase schema)
  TextColumn get displayName => text().nullable().withLength(max: 100).named('display_name')(); // e.g., "gel", "banana"
  TextColumn get displayNamePlural => text().nullable().withLength(max: 100).named('display_name_plural')(); // e.g., "gels", "bananas"

  // Serving description (matches Supabase schema)
  TextColumn get servingDescription => text().nullable().named('serving_description')(); // e.g., "1 medium", "1 cup cooked"

  // Additional fields matching Supabase schema
  TextColumn get description => text().nullable()(); // Product description
  TextColumn get instructions => text().nullable()(); // Food instructions/preparation

  // JSONB field for nutritional information (stored as TEXT in SQLite)
  TextColumn get nutritionalInfo => text().nullable().named('nutritional_info')();

  // Serving unit fields (matching Supabase schema)
  TextColumn get servingUnit => text().nullable().named('serving_unit')();
  TextColumn get servingUnitPlural => text().nullable().named('serving_unit_plural')();
  TextColumn get servingQualifier => text().nullable().named('serving_qualifier')();
  TextColumn get servingSize => text().nullable().named('serving_size')();

  // Phase suitability fields (matching Supabase schema)
  BoolColumn get afterRunSuitable => boolean().nullable().named('after_run_suitable')();

  // Product type ID - References product_types.id (matches Supabase foods.product_type_id)
  TextColumn get productTypeId => text().nullable().named('product_type_id')();

  // Affiliate marketing fields (matching Supabase schema)
  TextColumn get purchaseUrl => text().nullable().named('purchase_url')();
  TextColumn get affiliateSource => text().nullable().named('affiliate_source')();

  // Preference priority (matching Supabase schema)
  IntColumn get preferencePriority => integer().nullable().named('preference_priority')();
  
  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'foods';

  @override
  List<String> get customConstraints => [
    // Note: Unique constraint on name removed to match Supabase schema
    // Supabase uses case-insensitive unique index: uq_foods_lower_name
  ];
}

