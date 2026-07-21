import 'package:drift/drift.dart';

/// Post-workout template table — read-only reference data.
///
/// Mirrors Supabase `public.post_workout_templates` (v2 Notion schema applied
/// 2026-05-18 in `_archived/20260518100000_post_workout_templates_v2_notion.sql`).
/// Each row is a curated recovery formula combining one or more foods, sized
/// for a single standard portion (no body-size scaling for After phase).
///
/// Synced from Supabase via `PostWorkoutTemplatesRepository`
/// (delete-and-batch-insert pattern, mirrors `DuringWorkoutTemplatesRepository`).
///
/// Postgres arrays (`activity_types`, `component_food_names`, `allergens`,
/// `excluded_diets`, `carb_sources`) are stored locally as JSON-encoded
/// strings. JSONB columns (`component_ratios`, `default_servings`) are stored
/// as JSON strings verbatim.
///
/// PR 3 (Formula Kit After-phase parity) introduces this mirror so the
/// library can browse + pin post-workout formulas.
@DataClassName('PostWorkoutTemplateEntry')
class PostWorkoutTemplatesTable extends Table {
  /// UUID primary key (matches Supabase id).
  TextColumn get id => text()();

  /// Monotonic display/order number (matches Supabase template_number).
  IntColumn get templateNumber => integer().named('template_number')();

  /// Display name (e.g., 'Chocolate Milk Solo').
  TextColumn get name => text()();

  /// Short formula string (e.g., '2 cups chocolate milk').
  TextColumn get formula => text()();

  /// Human-readable portion description shown to the athlete. Nullable.
  TextColumn get portions => text().nullable()();

  /// JSON array of activity types this template applies to.
  /// e.g. `["running", "cycling", "swimming", "triathlon", "brick"]`.
  TextColumn get activityTypes =>
      text().withDefault(const Constant('[]')).named('activity_types')();

  /// JSON array of `template_foods.name` values that compose this formula.
  TextColumn get componentFoodNames =>
      text().withDefault(const Constant('[]')).named('component_food_names')();

  /// JSON object mapping component food name → ratio share of the formula.
  /// e.g. `{"chocolate_milk": 1.0}`. Nullable.
  TextColumn get componentRatios =>
      text().nullable().named('component_ratios')();

  /// JSON object mapping food name → serving count in that food's catalog
  /// serving size. Defines the canonical single portion for this template.
  /// e.g. `{"toaster_waffle": 1, "banana": 1}`.
  TextColumn get defaultServings =>
      text().withDefault(const Constant('{}')).named('default_servings')();

  /// Human-readable carb:protein ratio (e.g., '~3:1'). Nullable.
  TextColumn get targetCarbProteinRatio =>
      text().nullable().named('target_carb_protein_ratio')();

  /// Where the template can be eaten: 'in_bag' | 'cooler_friendly' |
  /// 'home_only'. Primary PR 3 filter axis. Nullable in source schema.
  TextColumn get travelFriendliness =>
      text().nullable().named('travel_friendliness')();

  /// Sensory dimension: 'sweet_creamy' | 'sweet_crunchy' | 'savory_salty' |
  /// 'warm_comforting' | 'mixed'. Used for V2 re-rolls. Nullable.
  TextColumn get flavorProfile => text().nullable().named('flavor_profile')();

  /// Prep effort: 'grab_and_go' | 'assemble' | 'cook'. Nullable.
  TextColumn get prepEffort => text().nullable().named('prep_effort')();

  /// Primary protein category (Notion taxonomy): 'whey_shake' | 'plant_shake'
  /// | 'yogurt' | 'cottage_cheese' | 'chocolate_milk' | 'smoothie' | 'egg' |
  /// 'nut_butter' | 'deli_cheese'. Nullable.
  TextColumn get proteinAnchor => text().nullable().named('protein_anchor')();

  /// JSON array of carb source tags (snake_case subset of Notion taxonomy).
  TextColumn get carbSources =>
      text().withDefault(const Constant('[]')).named('carb_sources')();

  /// Tie breaker for template selection. Higher = preferred when scores tie.
  /// Used by the PR 3 after-phase solver's non-pin fallthrough.
  IntColumn get selectionPriority =>
      integer().withDefault(const Constant(0)).named('selection_priority')();

  /// JSON array of allergens. e.g. `["dairy", "gluten"]`.
  TextColumn get allergens => text().withDefault(const Constant('[]'))();

  /// JSON array of diets that should exclude this template.
  /// e.g. `["vegan"]`.
  TextColumn get excludedDiets =>
      text().withDefault(const Constant('[]')).named('excluded_diets')();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'post_workout_templates';
}
