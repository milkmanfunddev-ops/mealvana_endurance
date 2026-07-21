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
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  // Simplified serving information (matches new Supabase schema)
  RealColumn get servingAmount => real().nullable().named('serving_amount')();

  // Serving limits (matches Supabase schema)
  IntColumn get maxServingsBefore =>
      integer().nullable().named('max_servings_before')();
  IntColumn get maxServingsDuring =>
      integer().nullable().named('max_servings_during')();
  IntColumn get maxServingsAfter =>
      integer().nullable().named('max_servings_after')();

  // Array-based columns (stored as JSON strings in SQLite, arrays in Postgres)
  /// Categories: array of category_enum values (e.g., ['before_run', 'during_run'])
  TextColumn get categories => text().nullable()();

  /// Activity types: array of activity_type_enum values (e.g., ['running', 'cycling'])
  TextColumn get activityTypes => text().nullable().named('activity_types')();

  // Nutritional values per serving (matches Supabase schema)
  IntColumn get sodiumMg => integer().nullable().named('sodium_mg')();
  IntColumn get caffeineMg => integer().nullable().named('caffeine_mg')();
  IntColumn get potassiumMg => integer().nullable().named('potassium_mg')();
  RealColumn get fatPerServing => real().nullable().named('fat_per_serving')();
  RealColumn get carbsPerServing =>
      real().nullable().named('carbs_per_serving')();
  RealColumn get proteinPerServing =>
      real().nullable().named('protein_per_serving')();
  IntColumn get caloriesPerServing =>
      integer().nullable().named('calories_per_serving')();
  RealColumn get fluidMlPerServing =>
      real().nullable().named('fluid_ml_per_serving')();

  // Food preferences and solver configuration (matches Supabase schema)
  BoolColumn get showInPreferences => boolean()
      .withDefault(const Constant(false))
      .named('show_in_preferences')();
  BoolColumn get isElectrolyte =>
      boolean().withDefault(const Constant(false)).named('is_electrolyte')();
  BoolColumn get toExcludeFromSolver => boolean()
      .withDefault(const Constant(false))
      .named('to_exclude_from_solver')();
  BoolColumn get isEssential =>
      boolean().withDefault(const Constant(false)).named('is_essential')();

  // Display name (matches Supabase schema)
  TextColumn get displayName => text()
      .nullable()
      .withLength(max: 100)
      .named('display_name')(); // e.g., "gel", "banana"
  TextColumn get displayNamePlural => text()
      .nullable()
      .withLength(max: 100)
      .named('display_name_plural')(); // e.g., "gels", "bananas"

  // Serving description (matches Supabase schema)
  TextColumn get servingDescription => text().nullable().named(
    'serving_description',
  )(); // e.g., "1 medium", "1 cup cooked"

  // Additional fields matching Supabase schema
  TextColumn get description => text().nullable()(); // Product description
  TextColumn get instructions =>
      text().nullable()(); // Food instructions/preparation

  // JSONB field for nutritional information (stored as TEXT in SQLite)
  TextColumn get nutritionalInfo =>
      text().nullable().named('nutritional_info')();

  // Serving unit fields (matching Supabase schema)
  TextColumn get servingUnit => text().nullable().named('serving_unit')();
  TextColumn get servingUnitPlural =>
      text().nullable().named('serving_unit_plural')();
  TextColumn get servingQualifier =>
      text().nullable().named('serving_qualifier')();
  TextColumn get servingSize => text().nullable().named('serving_size')();

  // Product type ID - References product_types.id (matches Supabase foods.product_type_id)
  TextColumn get productTypeId => text().nullable().named('product_type_id')();

  // Affiliate marketing fields (matching Supabase schema)
  TextColumn get purchaseUrl => text().nullable().named('purchase_url')();
  TextColumn get affiliateSource =>
      text().nullable().named('affiliate_source')();

  // Preference priority (matching Supabase schema)
  IntColumn get preferencePriority =>
      integer().nullable().named('preference_priority')();

  // NEW: Allergen and diet exclusion arrays for onboarding revamp
  /// Allergens contained in this food stored as PostgreSQL array format (e.g., '{dairy,gluten}')
  /// Values: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
  TextColumn get allergens =>
      text().withDefault(const Constant('{}')).named('allergens')();

  /// Diets that should exclude this food stored as PostgreSQL array format (e.g., '{vegan,vegetarian}')
  /// Values: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
  TextColumn get excludedDiets =>
      text().withDefault(const Constant('{}')).named('excluded_diets')();

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
