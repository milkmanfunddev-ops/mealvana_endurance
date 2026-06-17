import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Formula Kit personal formulas: user-owned, reusable fueling "recipes" tied
/// to a workout phase (before / during / after).
///
/// Mirrors the Supabase `personal_formulas` table (see the section in
/// `docs/database/apply_all.sql`). A personal formula is a DISTINCT concept
/// from a `personal_templates` row (which stores a saved nutrition-plan
/// snapshot), so it lives in its own table rather than overloading
/// `personal_templates` with a provenance discriminator.
///
/// Adds Drift-local sync tracking columns (`needs_upload`, `local_updated_at`)
/// that don't exist in Supabase — used by `PersonalFormulasRepository` to
/// preserve local-dirty rows during remote upsert (same offline-first pattern
/// as `formula_pins` / `personal_templates`).
///
/// **Soft delete convention.** Deleting a formula sets `is_deleted = true`
/// rather than removing the row, so the delete propagates across devices via
/// the upsert-only sync handler and any `formula_pins` referencing it can be
/// reconciled at the app layer. Every read must include `WHERE NOT is_deleted`.
@DataClassName('PersonalFormulaEntry')
class PersonalFormulasTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();
  TextColumn get name => text()();

  /// How the formula was authored: 'forked_formula' | 'from_scratch_formula'.
  TextColumn get provenance => text()();

  /// Which phase this formula fuels: 'before' | 'during' | 'after'.
  TextColumn get phase => text()();

  /// Forked-only: the system template this was copied from (polymorphic, no FK).
  TextColumn get sourceTemplateId =>
      text().nullable().named('source_template_id')();

  /// Forked-only: 'pre_system' | 'during_system' | 'post_system'.
  TextColumn get sourceTemplateKind =>
      text().nullable().named('source_template_kind')();

  // Phase-specific scope metadata (only the relevant phase fills these).
  TextColumn get subPhase => text().nullable().named('sub_phase')();
  TextColumn get digestSpeed => text().nullable().named('digest_speed')();

  /// During/After: JSON-encoded array of activity types.
  TextColumn get activities => text().nullable()();

  /// During: JSON-encoded array of duration brackets.
  TextColumn get durations => text().nullable()();
  TextColumn get gutTraining => text().nullable().named('gut_training')();
  TextColumn get travelFriendliness =>
      text().nullable().named('travel_friendliness')();

  /// The formula body: JSON-encoded array of component objects.
  TextColumn get components => text().withDefault(const Constant('[]'))();

  TextColumn get notes => text().nullable()();

  // Coach AI insight persistence (persist-unless-edited).
  TextColumn get coachInsightText =>
      text().nullable().named('coach_insight_text')();
  TextColumn get coachInsightMarker =>
      text().nullable().named('coach_insight_marker')();

  // Denormalized macro totals for list/detail display.
  IntColumn get totalCarbsG => integer().nullable().named('total_carbs_g')();
  IntColumn get totalProteinG =>
      integer().nullable().named('total_protein_g')();
  IntColumn get totalFatG => integer().nullable().named('total_fat_g')();
  IntColumn get totalSodiumMg =>
      integer().nullable().named('total_sodium_mg')();
  IntColumn get totalFluidsMl =>
      integer().nullable().named('total_fluids_ml')();
  IntColumn get totalCalories => integer().nullable().named('total_calories')();

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
  String get tableName => 'personal_formulas';
}
