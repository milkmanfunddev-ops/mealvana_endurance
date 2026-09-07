import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// One meal inside a week's plan — local mirror of the Supabase `plan_meals`
/// row (`supabase/migrations/20260827090000_meal_planning_vana.sql` + `icon`).
///
/// Rows are created server-side (`pick_meals` / `swap_meal`, remote-ack).
/// Local-first edits (`servings`, `session`, `comments`, remove) set
/// `needs_upload` and are replayed through the `plan_*` RPCs / row updates by
/// `MealPlanRepository.uploadDirtyRecords`.
///
/// **`is_deleted` is local-only.** The server hard-deletes plan meals
/// (`plan_remove_meal` → DELETE; plan archive cascades), so this column is a
/// tombstone that survives until the removal has been replayed remotely.
/// Every read filters `WHERE NOT is_deleted`.
@DataClassName('PlanMealEntry')
class PlanMealsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get planId => text().named('plan_id')();
  TextColumn get userId => text().named('user_id')();

  /// 'library' | 'saved'.
  TextColumn get source => text()();
  TextColumn get libraryMealId => text().nullable().named('library_meal_id')();
  TextColumn get savedMealId => text().nullable().named('saved_meal_id')();

  TextColumn get name => text()();

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack'.
  TextColumn get mealType => text().named('meal_type')();

  /// 'cook-sun' | 'topup-wed' | 'fresh-fri' | null (batch cooking off).
  TextColumn get session => text().nullable()();

  IntColumn get servings => integer().withDefault(const Constant(1))();
  IntColumn get servingsLeft =>
      integer().withDefault(const Constant(1)).named('servings_left')();

  // Per-serving macros as stored on the server row.
  IntColumn get kcal => integer().nullable()();
  RealColumn get carbsG => real().nullable().named('carbs_g')();
  RealColumn get proteinG => real().nullable().named('protein_g')();
  RealColumn get fatG => real().nullable().named('fat_g')();

  /// JSON array of `{from, to, effect?}`.
  TextColumn get swapsApplied =>
      text().withDefault(const Constant('[]')).named('swaps_applied')();

  /// JSON array of `{role, text, at}`.
  TextColumn get comments => text().withDefault(const Constant('[]'))();

  IntColumn get position => integer().withDefault(const Constant(0))();

  /// `MealIcon` key copied from the source meal at add/swap time.
  TextColumn get icon => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  /// Local tombstone (see class doc) — not a Supabase column.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  // Sync tracking (offline-first; not present in Supabase schema).
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'plan_meals';
}
