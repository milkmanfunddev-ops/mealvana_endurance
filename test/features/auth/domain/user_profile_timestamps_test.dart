/// `public.users.created_at` stops moving (develop-2026-10 ticket 22,
/// 01-004). It used to go out as a local wall clock with no offset; Postgres
/// read it as UTC, the next download brought the wrong instant back, and
/// every profile upload shifted it once more (pass A was 10 h off after two
/// uploads).
///
/// Seam: a `users` row as PostgREST returns it (microseconds and an offset),
/// saved to the real Drift row, read back, and uploaded twice through the
/// real [UserRepository] against an in-memory PostgREST ([FakePostgrest])
/// that records the upsert. Asserting the trailing `Z` catches a naive
/// string in any machine time zone. Drift keeps whole seconds, so "the same
/// instant" is the server's instant to the second.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../../helpers/fakes/fake_postgrest.dart';
import '../../../helpers/fakes/recording_report.dart';

const _user = '7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

/// As PostgREST answers it.
const _serverCreatedAt = '2026-10-07T11:11:03.123456+00:00';

Map<String, dynamic> _serverRow() => {
  'id': _user,
  'device_id': 'device-22',
  'auth_user_id': _user,
  'auth_provider': 'email',
  'is_anonymous': false,
  'gender': 'female',
  'birthday': '1990-06-15',
  'height_feet': 5,
  'height_inches': 6,
  'weight_pounds': 140,
  'runs_with_water_bottle': false,
  'gut_training_level': 'moderate',
  'onboarding_completed': true,
  'created_at': _serverCreatedAt,
  'updated_at': _serverCreatedAt,
  'app_version': '1.0.0',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late UserRepository repo;

  setUp(() async {
    db = AppDatabase.memory();
    server = FakePostgrest();
    await server.signIn(_user);
    repo = UserRepository(
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );
  });

  tearDown(() => db.close());

  List<String> sentCreatedAts() => server.writes
      .where((w) => w.table == 'users')
      .map((w) => (w.body is List ? (w.body as List).single : w.body) as Map)
      .map((m) => m['created_at'] as String)
      .toList();

  test('a server row saved locally and uploaded twice sends the same UTC '
      'instant both times', () async {
    final original = DateTime.parse(_serverCreatedAt);
    // Drift's resolution: whole seconds.
    final toTheSecond = DateTime.fromMillisecondsSinceEpoch(
      original.millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: true,
    );

    final downloaded = UserProfile.fromSupabaseRow(
      _serverRow(),
      fallbackId: _user,
    );
    await repo.saveUserProfile(downloaded, needsUpload: true);
    expect((await repo.uploadDirtyRecords(_user)).success, isTrue);

    // The next round trip: the local row read back, saved and uploaded.
    final row = (await db.select(db.userProfilesTable).get()).single;
    await repo.saveUserProfile(
      db.userDao.toDomainProfile(row),
      needsUpload: true,
    );
    expect((await repo.uploadDirtyRecords(_user)).success, isTrue);

    final sent = sentCreatedAts();
    expect(sent, hasLength(2));
    for (final s in sent) {
      expect(s, endsWith('Z'), reason: 'the offset is on the wire');
      expect(
        DateTime.parse(s).isAtSameMomentAs(toTheSecond),
        isTrue,
        reason: '$s is the server instant $_serverCreatedAt',
      );
    }
  });
}
