import 'package:drift/drift.dart';

/// Pre-workout template table — read-only reference data.
///
/// Mirrors Supabase `public.pre_workout_templates`. Each row is a curated
/// Before-phase formula (e.g. "Oats & Berries", "Bagel with Banana") with
/// per-serving macros and a serving range. Synced from Supabase via
/// [PreWorkoutTemplatesRepository] (delete-and-batch-insert pattern).
///
/// Postgres arrays (`allergens`, `component_food_names`, `excluded_diets`)
/// are stored locally as JSON-encoded strings; the JSONB column
/// `component_quantities` is stored as a JSON string verbatim.
@DataClassName('PreWorkoutTemplateEntry')
class PreWorkoutTemplatesTable extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// e.g. 'Bagel', 'Oats / Granola', 'Hydration'.
  TextColumn get baseCategory => text().named('base_category')();

  /// Timing label, e.g. '< 30 min', '30-90 min', '1.5-3 hours'.
  TextColumn get timeWindow => text().named('time_window')();

  /// Digestion speed bucket as stored in Supabase, e.g. 'Fast', 'Medium'.
  TextColumn get digestionSpeed => text().named('digestion_speed')();

  /// JSON array of allergens, e.g. `["gluten", "dairy"]`.
  TextColumn get allergens =>
      text().withDefault(const Constant('[]'))();

  TextColumn get servingUnit => text().named('serving_unit')();

  RealColumn get minServings => real().named('min_servings')();
  RealColumn get maxServings => real().named('max_servings')();

  BoolColumn get plusBanana =>
      boolean().withDefault(const Constant(false)).named('plus_banana')();
  BoolColumn get plusSportsDrink =>
      boolean().withDefault(const Constant(false)).named('plus_sports_drink')();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  RealColumn get carbsPerServing => real().named('carbs_per_serving')();
  RealColumn get proteinPerServing => real().named('protein_per_serving')();
  RealColumn get fatPerServing => real().named('fat_per_serving')();
  RealColumn get sodiumMg => real().named('sodium_mg')();
  RealColumn get fluidMl => real().named('fluid_ml')();

  /// e.g. 'food', 'drink', 'electrolyte'.
  TextColumn get templateType => text().named('template_type')();

  /// JSON array of component food names referenced by this template.
  TextColumn get componentFoodNames => text()
      .withDefault(const Constant('[]'))
      .named('component_food_names')();

  /// JSON object mapping component name → quantity. Stored verbatim.
  TextColumn get componentQuantities =>
      text().nullable().named('component_quantities')();

  /// JSON array of diets that should exclude this template.
  TextColumn get excludedDiets =>
      text().withDefault(const Constant('[]')).named('excluded_diets')();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'pre_workout_templates';
}
