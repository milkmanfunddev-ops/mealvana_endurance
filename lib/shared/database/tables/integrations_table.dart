import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Table for external training platform integrations (Final Surge, TrainingPeaks, Strava, etc.)
/// Stores OAuth tokens and sync metadata for each provider.
@DataClassName('Integration')
class IntegrationsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PRIMARY KEY (UUID)
  TextColumn get userId => text().named('user_id')(); // FOREIGN KEY to user_profiles.id

  /// Provider name: 'final_surge', 'training_peaks', 'strava', 'garmin'
  TextColumn get provider => text()();

  // OAuth tokens (encrypted at rest in Supabase)
  TextColumn get accessToken => text().named('access_token')();
  TextColumn get refreshToken => text().nullable().named('refresh_token')();
  DateTimeColumn get tokenExpiresAt => dateTime().nullable().named('token_expires_at')();

  // Provider-specific athlete data (displayed in Settings)
  TextColumn get providerAthleteId => text().named('provider_athlete_id')();
  TextColumn get providerAthleteName => text().nullable().named('provider_athlete_name')();
  TextColumn get providerAthleteEmail => text().nullable().named('provider_athlete_email')();

  // Provider-specific profile data (for auto-populating user profile during onboarding)
  // These fields are populated from Training Peaks profile API (Final Surge doesn't provide this data)
  RealColumn get providerAthleteWeightKg => real().nullable().named('provider_athlete_weight_kg')();
  TextColumn get providerAthleteBirthMonth => text().nullable().named('provider_athlete_birth_month')(); // "YYYY-MM" format
  TextColumn get providerAthleteGender => text().nullable().named('provider_athlete_gender')(); // 'm' or 'f'

  // Athlete zone data (HR, Speed, Power zones from Training Peaks)
  TextColumn get athleteZonesJson => text().nullable().named('athlete_zones_json')();

  // Sync metadata
  BoolColumn get isActive => boolean().withDefault(const Constant(true)).named('is_active')();
  DateTimeColumn get lastSyncAt => dateTime().nullable().named('last_sync_at')();
  TextColumn get lastSyncStatus => text().nullable().named('last_sync_status')(); // 'success', 'error', 'pending'
  TextColumn get lastSyncError => text().nullable().named('last_sync_error')();

  // Timestamps
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'integrations';

  @override
  List<String> get customConstraints => [
    "CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin'))",
    "CHECK (last_sync_status IS NULL OR last_sync_status IN ('success', 'error', 'pending'))",
    'UNIQUE(user_id, provider)',
  ];
}
