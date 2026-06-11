import 'package:drift/drift.dart';

/// Read-only local cache of the curated endurance recipe catalog.
///
/// Mirrors the Supabase `recipes` table (see
/// `docs/database/meal_logging_jade_schema.sql`). Content is managed
/// server-side (service role only); the app downloads active recipes and
/// caches them here for offline browsing/logging — same read-only mirror
/// pattern as the workout template tables. No `needs_upload` tracking.
@DataClassName('RecipeEntry')
class RecipesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// JSON-encoded array of ingredient strings.
  TextColumn get ingredients => text().withDefault(const Constant('[]'))();

  /// JSON-encoded array of instruction strings.
  TextColumn get instructions => text().withDefault(const Constant('[]'))();

  IntColumn get prepTimeMinutes =>
      integer().withDefault(const Constant(0)).named('prep_time_minutes')();
  IntColumn get servings => integer().withDefault(const Constant(1))();

  /// Wire values match the app's RecipeType enum:
  /// 'preRun' | 'duringRun' | 'postRun' | 'general'.
  TextColumn get type => text().withDefault(const Constant('general'))();

  // Per-serving nutrition.
  RealColumn get calories => real().withDefault(const Constant(0))();
  RealColumn get carbsG => real().withDefault(const Constant(0)).named('carbs_g')();
  RealColumn get proteinG =>
      real().withDefault(const Constant(0)).named('protein_g')();
  RealColumn get fatG => real().withDefault(const Constant(0)).named('fat_g')();
  RealColumn get fiberG =>
      real().withDefault(const Constant(0)).named('fiber_g')();
  RealColumn get sugarG =>
      real().withDefault(const Constant(0)).named('sugar_g')();
  RealColumn get sodiumMg =>
      real().withDefault(const Constant(0)).named('sodium_mg')();

  TextColumn get imageUrl => text().nullable().named('image_url')();

  /// JSON-encoded array of tag strings.
  TextColumn get tags => text().nullable()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'recipes';
}
