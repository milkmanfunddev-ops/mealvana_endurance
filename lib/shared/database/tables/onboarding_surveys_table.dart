import 'package:drift/drift.dart';

/// Onboarding survey answers: sports, goals, and pitfalls the athlete picked,
/// plus a JSON escape hatch for small flags — one row per user.
///
/// Mirrors the Supabase `onboarding_surveys` table (see
/// `supabase/migrations/_archived/20260806120000_onboarding_surveys.sql`).
/// This is the ONE new table of the onboarding redesign
/// (docs/features/onboarding-redesign/README.md §3): everything else the new
/// flow collects rides existing `users` columns. Future survey questions go
/// into `survey_payload`, not new columns — keep schema churn at zero.
///
/// `user_id` is the primary key (one survey per user; re-onboarding
/// overwrites). It references user_profiles.id by convention only, matching
/// the other user-scoped tables (SQLite FK enforcement is off; Supabase has
/// the real constraint).
@DataClassName('OnboardingSurveyEntry')
class OnboardingSurveysTable extends Table {
  TextColumn get userId => text().named('user_id')();

  /// JSON array of OnboardingSport dbValues, e.g. ["running","triathlon"].
  TextColumn get sports => text()();

  /// JSON array of OnboardingGoal dbValues.
  TextColumn get goals => text()();

  /// JSON array of OnboardingPitfall dbValues.
  TextColumn get pitfalls => text()();

  /// JSON object for small survey flags (tridot_notify, sweat_test_interest,
  /// declined_training_apps, connected_provider, ...).
  TextColumn get surveyPayload => text().nullable().named('survey_payload')();

  DateTimeColumn get completedAt => dateTime().named('completed_at')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  // Sync tracking (offline-first; not present in Supabase schema)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {userId};

  @override
  String get tableName => 'onboarding_surveys';
}
