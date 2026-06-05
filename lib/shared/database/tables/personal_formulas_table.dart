import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Formula Kit personal formulas: a user's edited/forked copy of a system
/// Before/During formula (the "Make this mine" save from
/// `formula_detail_screen`).
///
/// Mirrors the Supabase `personal_formulas` table (see
/// `docs/database/apply_all.sql` Section 4). Distinct from
/// [PersonalTemplatesTable], which stores whole nutrition-plan snapshots —
/// that table is frozen + deprecated in PR 5d.
///
/// Adds Drift-local sync columns (`needs_upload`, `local_updated_at`) absent
/// from Supabase; used by `PersonalFormulasRepository` to preserve local-dirty
/// rows during remote upsert (same offline-first pattern as `formula_pins`).
///
/// **Soft delete convention.** Deleting a personal formula sets
/// `is_deleted = true` rather than removing the row, so the change propagates
/// across devices via the upsert-only sync handler. Every read must include
/// `WHERE NOT is_deleted`.
///
/// **JSON columns.** [components], [activityTypes], [durationBrackets], and
/// [gutTrainingLevels] hold JSON strings (Drift has no native array/JSONB
/// type). The repository encodes/decodes them; Supabase stores `components` as
/// JSONB and the during arrays as `text[]`.
@DataClassName('PersonalFormulaEntry')
class PersonalFormulasTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();
  TextColumn get name => text()();

  /// 'before' | 'during'. After-phase has no edit state (standard portion).
  TextColumn get phase => text()();

  /// The system template this was forked from (nullable for from-scratch).
  /// Polymorphic — may reference pre_workout_templates or
  /// during_workout_templates. Stored as text, not FK.
  TextColumn get sourceTemplateId =>
      text().nullable().named('source_template_id')();

  // Before-phase context (null for during).
  TextColumn get subPhase => text().nullable().named('sub_phase')();
  TextColumn get digestionSpeed => text().nullable().named('digestion_speed')();
  TextColumn get templateType => text().nullable().named('template_type')();

  // During-phase context (null for before). JSON-encoded string arrays.
  TextColumn get activityTypes => text().nullable().named('activity_types')();
  TextColumn get durationBrackets =>
      text().nullable().named('duration_brackets')();
  TextColumn get gutTrainingLevels =>
      text().nullable().named('gut_training_levels')();

  /// JSON array of edited components (food identity + per-serving macros +
  /// quantity). See table doc + apply_all.sql Section 4.
  TextColumn get components => text().withDefault(const Constant('[]'))();

  // Denormalized macro totals for list display.
  RealColumn get totalCarbsG =>
      real().withDefault(const Constant(0)).named('total_carbs_g')();
  RealColumn get totalProteinG =>
      real().withDefault(const Constant(0)).named('total_protein_g')();
  RealColumn get totalFatG =>
      real().withDefault(const Constant(0)).named('total_fat_g')();
  RealColumn get totalSodiumMg =>
      real().withDefault(const Constant(0)).named('total_sodium_mg')();
  RealColumn get totalFluidMl =>
      real().withDefault(const Constant(0)).named('total_fluid_ml')();
  IntColumn get totalCalories =>
      integer().withDefault(const Constant(0)).named('total_calories')();

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
