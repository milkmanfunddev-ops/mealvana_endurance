import 'package:drift/drift.dart';

/// Template foods table - food ingredient catalog for nutrition templates
/// Mirrors Supabase template_foods table (read-only reference data)
@DataClassName('TemplateFoodEntry')
class TemplateFoodsTable extends Table {
  /// UUID primary key (matches Supabase template_foods.id)
  TextColumn get id => text()();

  /// Machine-readable identifier (e.g., 'white_bread')
  TextColumn get name => text()();

  /// Human-readable name (e.g., 'White Bread')
  TextColumn get displayName => text().named('display_name')();

  /// Serving description (e.g., '1 slice', '1 cup cooked')
  TextColumn get servingSize => text().named('serving_size')();

  /// Weight per serving in grams
  RealColumn get servingWeightG => real().nullable().named('serving_weight_g')();

  // Nutrition per serving
  IntColumn get calories => integer().withDefault(const Constant(0))();
  RealColumn get carbsG => real().withDefault(const Constant(0)).named('carbs_g')();
  RealColumn get proteinG => real().withDefault(const Constant(0)).named('protein_g')();
  RealColumn get fatG => real().withDefault(const Constant(0)).named('fat_g')();
  RealColumn get fiberG => real().nullable().named('fiber_g')();
  RealColumn get sodiumMg => real().withDefault(const Constant(0)).named('sodium_mg')();
  RealColumn get fluidMl => real().nullable().named('fluid_ml')();

  // Metadata
  /// Allergen tags stored as JSON array string (e.g., '["gluten","dairy"]')
  TextColumn get allergens => text().withDefault(const Constant('[]'))();

  /// Digestion speed: fast/medium/slow
  TextColumn get digestionSpeed => text().withDefault(const Constant('medium')).named('digestion_speed')();

  BoolColumn get isActive => boolean().withDefault(const Constant(true)).named('is_active')();

  /// Diets that should exclude this food (JSON array string)
  TextColumn get excludedDiets => text().withDefault(const Constant('[]')).named('excluded_diets')();

  /// Product type: real_food/bar/gel/chew/supplement/beverage/condiment/sports_drink
  TextColumn get productType => text().withDefault(const Constant('real_food')).named('product_type')();

  /// Activity types this food is suitable for (JSON array string)
  TextColumn get activityTypes => text().withDefault(const Constant('["running","cycling","swimming"]')).named('activity_types')();

  /// Categories this food belongs to (JSON array string)
  TextColumn get categories => text().withDefault(const Constant('["before_run"]'))();

  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false)).named('is_electrolyte')();
  BoolColumn get requiresPreparation => boolean().withDefault(const Constant(false)).named('requires_preparation')();

  RealColumn get caffeineMg => real().nullable().named('caffeine_mg')();
  RealColumn get potassiumMg => real().nullable().named('potassium_mg')();

  // Drink pool metadata
  BoolColumn get isDrinkPool => boolean().withDefault(const Constant(false)).named('is_drink_pool')();

  /// Which phases this drink can be selected for (JSON array string)
  TextColumn get drinkPoolPhases => text().withDefault(const Constant('[]')).named('drink_pool_phases')();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'template_foods';
}
