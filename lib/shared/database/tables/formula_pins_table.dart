import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Formula Kit pins: user-declared preference signal for plan generation.
///
/// Mirrors the Supabase `formula_pins` table (see migration
/// `20260520120000_formula_pins.sql`). Adds Drift-local sync tracking columns
/// (`needs_upload`, `local_updated_at`) that don't exist in Supabase — they're
/// used by `FormulaPinsRepository` to preserve local-dirty rows during remote
/// upsert (same offline-first pattern as `personal_templates`).
///
/// **Soft delete convention.** Unpinning sets `is_deleted = true` rather than
/// removing the row. This matches the `user_foods` pattern and lets unpin
/// events propagate correctly across devices via the existing upsert-only
/// sync handler. Every read of pins must include `WHERE NOT is_deleted`.
@DataClassName('FormulaPinEntry')
class FormulaPinsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();
  TextColumn get templateId => text().named('template_id')();

  /// Polymorphic ref: 'pre_system' | 'during_system' | 'post_system'.
  /// PR 5 adds 'personal_template' when personal formulas become pinnable.
  TextColumn get templateKind => text().named('template_kind')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  // Sync tracking (offline-first; not present in Supabase schema)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'formula_pins';
}
