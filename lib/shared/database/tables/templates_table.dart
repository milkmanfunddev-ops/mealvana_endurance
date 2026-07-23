import 'package:drift/drift.dart';

/// Templates table - pre-workout nutrition templates with denormalized food data
/// Mirrors Supabase templates table (read-only reference data)
@DataClassName('TemplateEntry')
class TemplatesTable extends Table {
  /// UUID primary key (matches Supabase templates.id)
  TextColumn get id => text()();

  /// Template name (e.g., 'Toast + PB + Banana')
  TextColumn get name => text()();

  /// URL-friendly slug (e.g., 'toast-pb-banana')
  TextColumn get slug => text()();

  // Phase & Timing
  /// Phase: before/during/after/transition
  TextColumn get phase => text().withDefault(const Constant('before'))();

  /// Display label: '< 30 min', '30-60 min', '1-2 hours', '3-4 hours'
  TextColumn get timingWindow => text().named('timing_window')();

  IntColumn get timingMinMinutes => integer().named('timing_min_minutes')();
  IntColumn get timingMaxMinutes => integer().named('timing_max_minutes')();

  /// Meal type: top_up/snack/full_meal/during_fuel/recovery/transition_fuel
  TextColumn get mealType =>
      text().withDefault(const Constant('snack')).named('meal_type')();

  // Categorization
  /// Base category for conflict avoidance (e.g., 'Toast / Bread', 'Bagel')
  TextColumn get baseCategory => text().named('base_category')();

  /// Digestion speed: fast/medium/slow
  TextColumn get digestionSpeed =>
      text().withDefault(const Constant('medium')).named('digestion_speed')();

  /// Union of all food allergens (JSON array string)
  TextColumn get allergens => text().withDefault(const Constant('[]'))();

  /// Diets that should exclude this template (JSON array string)
  TextColumn get excludedDiets =>
      text().withDefault(const Constant('[]')).named('excluded_diets')();

  TextColumn get notes => text().nullable()();

  /// JSONB foods array stored as JSON string
  /// Each item: {food_id, food_name, display_name, serving_size,
  ///             default_servings, min_servings, max_servings,
  ///             carbs_g, protein_g, fat_g, sodium_mg, fluid_ml}
  TextColumn get foods => text().withDefault(const Constant('[]'))();

  // Precomputed totals (at default_servings)
  RealColumn get totalCarbsG =>
      real().withDefault(const Constant(0)).named('total_carbs_g')();
  RealColumn get totalProteinG =>
      real().withDefault(const Constant(0)).named('total_protein_g')();
  RealColumn get totalFatG =>
      real().withDefault(const Constant(0)).named('total_fat_g')();
  RealColumn get totalSodiumMg =>
      real().withDefault(const Constant(0)).named('total_sodium_mg')();
  RealColumn get totalFluidMl =>
      real().withDefault(const Constant(0)).named('total_fluid_ml')();
  IntColumn get totalCalories =>
      integer().withDefault(const Constant(0)).named('total_calories')();

  /// Validation status: unvalidated/validated/needs_adjustment/failed
  TextColumn get validationStatus => text()
      .withDefault(const Constant('unvalidated'))
      .named('validation_status')();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0)).named('sort_order')();

  /// Denormalized food names for conflict avoidance (JSON array string)
  TextColumn get foodNames =>
      text().withDefault(const Constant('[]')).named('food_names')();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'templates';
}
