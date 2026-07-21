import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Table for personal nutrition plan templates
/// Users can save their nutrition plans as reusable templates
@DataClassName('PersonalTemplateEntry')
class PersonalTemplatesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();
  TextColumn get name => text()();
  TextColumn get activityType =>
      text().named('activity_type')(); // 'running'/'cycling'/'swimming'/'brick'

  // Original activity context
  IntColumn get originalDurationMinutes =>
      integer().nullable().named('original_duration_minutes')();
  RealColumn get originalDistance => real().nullable().named(
    'original_distance',
  )(); // miles for run/cycle, meters for swim
  TextColumn get originalActivityTitle =>
      text().nullable().named('original_activity_title')();

  // Full plan data stored as JSON string
  TextColumn get planData => text().named('plan_data')();

  // Denormalized macro totals for quick display
  IntColumn get totalCarbsG => integer().nullable().named('total_carbs_g')();
  IntColumn get totalProteinG =>
      integer().nullable().named('total_protein_g')();
  IntColumn get totalFatG => integer().nullable().named('total_fat_g')();
  IntColumn get totalSodiumMg =>
      integer().nullable().named('total_sodium_mg')();
  IntColumn get totalFluidsMl =>
      integer().nullable().named('total_fluids_ml')();
  IntColumn get totalCalories => integer().nullable().named('total_calories')();

  // Brick metadata stored as JSON string (null for single-sport)
  TextColumn get brickSegmentOrder =>
      text().nullable().named('brick_segment_order')();

  // Metadata
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  // Sync tracking (offline-first architecture)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'personal_templates';
}
