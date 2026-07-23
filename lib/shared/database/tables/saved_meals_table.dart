import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Explicit user favorites ("My Meals") for one-tap re-logging.
///
/// Mirrors the Supabase `saved_meals` table (see
/// `docs/database/meal_logging_jade_schema.sql`). Recents come straight from
/// `meal_logs`; this table only holds meals the user starred with a custom
/// name. Offline-first with the standard `needs_upload` dirty tracking and
/// soft delete via `is_deleted` (every read filters `WHERE NOT is_deleted`).
@DataClassName('SavedMealEntry')
class SavedMealsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();

  TextColumn get name => text()();

  /// JSON-encoded array of food components (same shape as meal_logs.items).
  TextColumn get items => text().withDefault(const Constant('[]'))();

  IntColumn get calories => integer().nullable()();
  RealColumn get carbsG => real().nullable().named('carbs_g')();
  RealColumn get proteinG => real().nullable().named('protein_g')();
  RealColumn get fatG => real().nullable().named('fat_g')();
  RealColumn get sodiumMg => real().nullable().named('sodium_mg')();

  TextColumn get photoPath => text().nullable().named('photo_path')();

  /// Bumped each time the saved meal is re-logged (sorts the picker).
  DateTimeColumn get lastUsedAt =>
      dateTime().nullable().named('last_used_at')();

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
  String get tableName => 'saved_meals';
}
