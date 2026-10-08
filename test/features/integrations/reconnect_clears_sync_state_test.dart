// Ticket 64 (develop-2026-10, Finding 50-009): a reconnect clears the sync
// state a disconnect left on the row. Lee (2026-10-08): "reconnect clears
// requires_reauth". Every connect already builds a fresh model with status
// `pending` (null for Runna) and no error, and `upsertIntegration` writes
// every column of it; this test pins that.
//
// Seam: a stale server row (the dev V.O2 row as it stood on 2026-10-08) →
// `syncFromRemote` → the REAL IntegrationsRepository on in-memory Drift →
// `upsertIntegration` with the model each connect builds → the REAL postgrest
// builder against FakePostgrest, which records the upsert.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _userId = 'u-64';

/// The server row a pre-47 disconnect left: inactive, token cleared, still
/// carrying a reauth state and an English sentence.
Map<String, dynamic> _staleServerRow(String provider) => {
  'id': 'srv-$provider',
  'user_id': _userId,
  'provider': provider,
  'access_token': '',
  'refresh_token': null,
  'token_expires_at': null,
  'provider_athlete_id': 'ath-old',
  'is_active': false,
  'last_sync_status': requiresReauthStatus,
  'last_sync_error': 'Please reconnect your account',
  'created_at': '2026-07-03T10:00:00Z',
  'updated_at': '2026-10-08T13:26:26Z',
};

/// The model each connect path builds, field for field (line refs at
/// `876ca27e`): V.O2 `vdot_oauth_service.dart:122-134`, TrainingPeaks
/// `training_peaks_oauth_service.dart:159-180`, Final Surge
/// `final_surge_oauth_service.dart:111-124`, Garmin
/// `garmin_oauth_service.dart:147-161`, Runna
/// `connect_training_controller.dart` `connectRunna`.
final _connectModels = <String, IntegrationModel Function()>{
  'vdot': () => IntegrationModel(
    userId: _userId,
    provider: 'vdot',
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
    tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    providerAthleteId: _userId,
    providerAthleteName: 'V.O2',
    isActive: true,
    lastSyncStatus: 'pending',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  'training_peaks': () => IntegrationModel(
    userId: _userId,
    provider: 'training_peaks',
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
    tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    providerAthleteId: '2687398',
    providerAthleteName: 'Test Athlete',
    providerAthleteEmail: 'athlete@example.com',
    providerAthleteWeightKg: 70,
    providerAthleteBirthMonth: '1990-01',
    providerAthleteGender: 'm',
    providerIsPremium: true,
    isActive: true,
    lastSyncStatus: 'pending',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  'final_surge': () => IntegrationModel(
    userId: _userId,
    provider: 'final_surge',
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
    tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    providerAthleteId: 'fs-1',
    providerAthleteName: 'Test Athlete',
    providerAthleteEmail: 'athlete@example.com',
    isActive: true,
    lastSyncStatus: 'pending',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  'garmin': () => IntegrationModel(
    userId: _userId,
    provider: 'garmin',
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
    tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    providerAthleteId: 'garmin-user-1',
    providerAthleteName: 'Garmin Connect',
    isActive: true,
    lastSyncStatus: 'pending',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  'runna': () => const IntegrationModel(
    userId: _userId,
    provider: 'runna',
    accessToken: 'https://cal.runna.com/feed.ics',
    providerAthleteId: 'runna-abc',
    isActive: true,
  ),
};

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository repository;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // `syncFromRemote` stamps its last sync time in SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    addTearDown(db.close);
    server = FakePostgrest();
    server.tables['users'] = [
      {'id': _userId},
    ];
    await server.signIn(_userId);
    repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );
  });

  Future<void> seedStale(String provider) async {
    server.tables['integrations'] = [_staleServerRow(provider)];
    final seeded = await repository.syncFromRemote(_userId);
    expect(seeded.success, isTrue, reason: seeded.error);
    final row = await repository.getIntegration(_userId, provider);
    expect(row!.isActive, isFalse);
    expect(row.lastSyncStatus, requiresReauthStatus);
  }

  Map<String, dynamic> lastIntegrationUpsert() {
    final write = server.writes.lastWhere((w) => w.table == 'integrations');
    final body = write.body;
    final row = body is List ? body.single : body;
    return (row as Map).cast<String, dynamic>();
  }

  for (final entry in _connectModels.entries) {
    final provider = entry.key;
    final expectedStatus = provider == 'runna' ? null : 'pending';

    test('$provider: a reconnect clears requires_reauth on the row and server',
        () async {
      await seedStale(provider);

      await repository.upsertIntegration(entry.value());

      final row = await repository.getIntegration(_userId, provider);
      expect(row!.id, 'srv-$provider');
      expect(row.isActive, isTrue);
      expect(row.lastSyncStatus, expectedStatus);
      expect(row.lastSyncError, isNull);
      expect(row.needsReconnect, isFalse);

      final sent = lastIntegrationUpsert();
      expect(sent['id'], 'srv-$provider');
      expect(sent['is_active'], isTrue);
      expect(sent['last_sync_status'], expectedStatus);
      expect(sent['last_sync_error'], isNull);
    });
  }

  test('a refused push keeps the reconnect; the stale server row does not '
      'come back over it', () async {
    await seedStale('training_peaks');
    // Session mismatch: `_remoteWriteAllowed` refuses, the row stays dirty.
    await server.signIn('someone-else');

    await repository.upsertIntegration(_connectModels['training_peaks']!());
    expect(
      server.writes.where((w) => w.table == 'integrations'),
      isEmpty,
    );

    // The server still holds the stale row; a later download skips the
    // dirty local row.
    await repository.syncFromRemote(_userId);

    final row = await repository.getIntegration(_userId, 'training_peaks');
    expect(row!.isActive, isTrue);
    expect(row.lastSyncStatus, 'pending');
    expect(row.lastSyncError, isNull);
  });
}
