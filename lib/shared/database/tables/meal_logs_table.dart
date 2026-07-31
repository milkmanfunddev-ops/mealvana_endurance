import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Logged meals for the Daily Macros tab (breakfast / lunch / dinner / snack;
/// multiple snack rows per day are expected).
///
/// Mirrors the Supabase `meal_logs` table (see
/// `docs/database/meal_logging_jade_schema.sql`). Entries are created locally
/// first (offline-first) by any of the five logging methods — photo, manual,
/// describe-to-AI, saved/recent meal, or recipe — and uploaded later via the
/// repository's dirty-record upload (`needs_upload`, onConflict: 'id').
///
/// **Soft delete convention.** Deleting a log sets `is_deleted = true` so the
/// delete propagates across devices through upsert-only sync. Every read must
/// include `WHERE NOT is_deleted`.
@DataClassName('MealLogEntry')
class MealLogsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();

  /// Local calendar day the meal counts toward, stored as 'yyyy-MM-dd' to
  /// match the Supabase DATE column without timezone drift.
  TextColumn get logDate => text().named('log_date')();

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack', or NULL when the user leaves
  /// the meal untagged (optional since schema v14 — see the build-a-meal
  /// redesign notes on [AppDatabase.migration]).
  TextColumn get slot => text().nullable()();

  /// Display title, e.g. "Oatmeal + banana".
  TextColumn get name => text()();

  /// How the entry was created:
  /// 'photo' | 'manual' | 'describe' | 'saved' | 'recipe' | 'jade_baseline'.
  TextColumn get source => text()();

  /// JSON-encoded array of food components
  /// ({ name, portion, calories, carb_g, protein_g, fat_g, sodium_mg }).
  TextColumn get items => text().withDefault(const Constant('[]'))();

  // Denormalized totals — what the consumed-vs-target layer reads.
  IntColumn get calories => integer().nullable()();
  RealColumn get carbsG => real().nullable().named('carbs_g')();
  RealColumn get proteinG => real().nullable().named('protein_g')();
  RealColumn get fatG => real().nullable().named('fat_g')();
  RealColumn get sodiumMg => real().nullable().named('sodium_mg')();

  /// Object path inside the `meal-photos` storage bucket (not a URL).
  TextColumn get photoPath => text().nullable().named('photo_path')();

  /// Provenance pointers (no FKs — sources may be deleted independently).
  TextColumn get recipeId => text().nullable().named('recipe_id')();
  TextColumn get savedMealId => text().nullable().named('saved_meal_id')();

  TextColumn get notes => text().nullable()();

  /// When the meal was eaten (user-adjustable), distinct from createdAt.
  DateTimeColumn get eatenAt => dateTime().nullable().named('eaten_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  // Sync tracking (offline-first; not present in Supabase schema).
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'meal_logs';
}
