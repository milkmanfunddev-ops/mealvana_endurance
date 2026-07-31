import 'package:drift/drift.dart';

/// During-workout template table — read-only reference data.
///
/// Mirrors Supabase `public.during_workout_templates`. Each row is a curated
/// formula combining one or more foods appropriate for a specific activity
/// type, duration bracket, and gut-training level. Synced from Supabase via
/// [DuringWorkoutTemplatesRepository] (delete-and-batch-insert pattern).
///
/// Postgres arrays (`activity_types`, `duration_brackets`,
/// `gut_training_levels`, `component_food_names`, `allergens`,
/// `excluded_diets`) are stored locally as JSON-encoded strings. The
/// `component_carb_ratios` JSONB column is stored as a JSON string verbatim.
@DataClassName('DuringWorkoutTemplateEntry')
class DuringWorkoutTemplatesTable extends Table {
  /// UUID primary key (matches Supabase id).
  TextColumn get id => text()();

  /// Monotonic display/order number (matches Supabase template_number).
  IntColumn get templateNumber => integer().named('template_number')();

  /// Display name (e.g., 'Gel + Water (Running)').
  TextColumn get name => text()();

  /// Short formula string (e.g., 'Gel + Water + Sports Drink').
  TextColumn get formula => text()();

  /// Food form bucket (e.g., 'Gel', 'Liquid + Gel/Chew', 'Solid + Liquid').
  TextColumn get foodForm => text().named('food_form')();

  /// JSON array of activity types this template applies to.
  /// e.g. `["running", "cycling"]`.
  TextColumn get activityTypes =>
      text().withDefault(const Constant('[]')).named('activity_types')();

  /// JSON array of duration brackets.
  /// e.g. `["90-150 min", "150-240 min"]`.
  TextColumn get durationBrackets =>
      text().withDefault(const Constant('[]')).named('duration_brackets')();

  /// JSON array of gut-training levels this template targets.
  /// e.g. `["low", "moderate", "high"]`.
  TextColumn get gutTrainingLevels =>
      text().withDefault(const Constant('[]')).named('gut_training_levels')();

  /// JSON array of `template_foods.name` values that compose this formula.
  TextColumn get componentFoodNames =>
      text().withDefault(const Constant('[]')).named('component_food_names')();

  /// JSON object mapping component food name → carb ratio.
  /// e.g. `{"energy_gel": 0.7, "sports_drink": 0.3}`. Nullable.
  TextColumn get componentCarbRatios =>
      text().nullable().named('component_carb_ratios')();

  /// Unit ratio for triple-source templates (e.g., "1:1"). Nullable.
  TextColumn get primaryToSecondaryRatio =>
      text().nullable().named('primary_to_secondary_ratio')();

  /// JSON array of allergens. e.g. `["gluten", "dairy"]`.
  TextColumn get allergens => text().withDefault(const Constant('[]'))();

  /// JSON array of diets that should exclude this template.
  /// e.g. `["vegan"]`.
  TextColumn get excludedDiets =>
      text().withDefault(const Constant('[]')).named('excluded_diets')();

  TextColumn get notes => text().nullable()();

  /// Tie breaker for default-formula / template selection. Higher = preferred
  /// when scores tie. Mirrors Supabase `selection_priority`; consumed by the
  /// client-side default-formula selector used to seed onboarding pins.
  IntColumn get selectionPriority =>
      integer().withDefault(const Constant(0)).named('selection_priority')();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'during_workout_templates';
}
