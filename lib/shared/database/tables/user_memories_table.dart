import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// "What Vana knows" — local mirror of the Supabase `user_memories` row
/// (`supabase/migrations/20260827090000_meal_planning_vana.sql`), minus the
/// pgvector `embedding` column (server-only; recall is an RPC).
///
/// Holds both free facts (`preference | constraint | pattern | episode`) and
/// the two boolean settings (`kind = 'setting'`, `key = 'batch_cooking' |
/// 'show_macros'`). Settings and deletes are local-first; facts are written
/// server-side by the model (`rememberFact`) and pulled by sync.
///
/// Server-side `(user_id, key)` uniqueness for live settings is a **partial**
/// index — never `onConflict` on it; upsert `onConflict: 'id'`.
@DataClassName('UserMemoryEntry')
class UserMemoriesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();

  /// 'preference' | 'constraint' | 'pattern' | 'episode' | 'setting'.
  TextColumn get kind => text()();

  /// Settings key for `kind = 'setting'`; null otherwise.
  TextColumn get key => text().nullable()();

  TextColumn get fact => text()();

  /// JSON-encoded scalar/collection (`jsonb` on the server); null when unset.
  TextColumn get value => text().nullable()();

  RealColumn get confidence => real().withDefault(const Constant(0.8))();

  /// 'conversation' | 'inferred' | 'settings'.
  TextColumn get source => text().withDefault(const Constant('conversation'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get lastConfirmedAt => dateTime().named('last_confirmed_at')();
  DateTimeColumn get expiresAt => dateTime().nullable().named('expires_at')();

  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  // Sync tracking (offline-first; not present in Supabase schema).
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'user_memories';
}
