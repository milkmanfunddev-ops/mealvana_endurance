import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// A week's meal plan — local mirror of the Supabase `meal_plans` row
/// (`supabase/migrations/20260827090000_meal_planning_vana.sql` + the
/// `days` / `conversation_id` / `day_notes*` additions).
///
/// jsonb columns (`rules shopping days day_notes`) are stored as TEXT JSON.
/// Plans are only ever *created* server-side (`pick_meals` / `new_plan` via
/// `vana-action`, remote-ack); the local-first edits are `shopping` toggles and
/// `days` slot writes, replayed by `MealPlanRepository.uploadDirtyRecords`.
///
/// Server-side `(user_id, week_start)` uniqueness for non-archived plans is a
/// **partial** index — never `onConflict` on it; upsert `onConflict: 'id'`.
@DataClassName('MealPlanEntry')
class MealPlansTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();

  /// Monday of the week as 'yyyy-MM-dd' (Supabase DATE, no tz drift).
  TextColumn get weekStart => text().named('week_start')();

  /// 'draft' | 'confirmed' | 'archived'.
  TextColumn get status => text().withDefault(const Constant('draft'))();

  BoolColumn get batchCooking =>
      boolean().withDefault(const Constant(true)).named('batch_cooking')();

  /// JSON array of `PlanRule`.
  TextColumn get rules => text().withDefault(const Constant('[]'))();

  /// JSON array of `ShoppingItem`.
  TextColumn get shopping => text().withDefault(const Constant('[]'))();

  /// Vana's one-line week brief (legacy; null today).
  TextColumn get brief => text().nullable()();

  /// The Vana conversation that owns this draft; null = week-level plan.
  TextColumn get conversationId => text().nullable().named('conversation_id')();

  /// JSON object `{ 'yyyy-MM-dd': DayPlan }` — the day-planner slots.
  TextColumn get days => text().withDefault(const Constant('{}'))();

  /// JSON object `{ 'yyyy-MM-dd': text }` — precomputed day notes.
  TextColumn get dayNotes =>
      text().withDefault(const Constant('{}')).named('day_notes')();

  /// True while an edit has invalidated [dayNotes] (server regenerates).
  BoolColumn get dayNotesStale =>
      boolean().withDefault(const Constant(true)).named('day_notes_stale')();

  DateTimeColumn get dayNotesAt =>
      dateTime().nullable().named('day_notes_at')();

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
  String get tableName => 'meal_plans';
}
