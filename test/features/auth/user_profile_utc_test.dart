/// `public.users.sweat_test_date` reaches the server in UTC (develop-2026-10
/// ticket 53, after tickets 22 and 39). The column is `timestamptz`; the
/// value used to go out as a naive local wall clock, Postgres read it as
/// UTC, and the next download brought a different instant back (a Chicago
/// athlete's test day moved to the evening before).
///
/// Seam: a profile saved to the real Drift row and uploaded through the real
/// [UserRepository] against an in-memory PostgREST ([FakePostgrest]) that
/// records the upsert. The server-row case feeds `sweat_test_date` as
/// PostgREST answers it (microseconds and an offset). Asserting the trailing
/// `Z` catches a naive string in any machine time zone. Drift keeps whole
/// seconds, so "the same instant" is to the second.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _user = '5c3e1f2a-9b8d-4c7e-a6f5-0d1e2f3a4b53';

/// As PostgREST answers a `timestamptz`.
const _serverSweatTestDate = '2026-09-14T05:00:00.000000+00:00';
const _serverCreatedAt = '2026-10-07T11:11:03.123456+00:00';

Map<String, dynamic> _serverRow() => {
  'id': _user,
  'device_id': 'device-53',
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
  'sweat_test_date': _serverSweatTestDate,
  'sweat_test_source': 'commercial_test',
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

  List<Map> sentUsers() => server.writes
      .where((w) => w.table == 'users')
      .map((w) => (w.body is List ? (w.body as List).single : w.body) as Map)
      .toList();

  test('a local sweat test date goes out in UTC at the same instant',
      () async {
    // What the sweat-profile date picker hands back: local midnight.
    final picked = DateTime(2026, 9, 14);
    final profile = UserProfile.fromSupabaseRow(
      _serverRow(),
      fallbackId: _user,
    ).copyWith(sweatTestDate: picked);

    await repo.saveUserProfile(profile, needsUpload: true);
    expect((await repo.uploadDirtyRecords(_user)).success, isTrue);

    final sent = sentUsers().single['sweat_test_date'] as String;
    expect(sent, endsWith('Z'), reason: 'the offset is on the wire');
    expect(
      DateTime.parse(sent).isAtSameMomentAs(picked),
      isTrue,
      reason: '$sent is the picked instant $picked',
    );
    // A `date` column stays a plain date (ticket 39's Decisions).
    expect(sentUsers().single['birthday'], '1990-06-15');
  });

  test('a server sweat test date saved locally and uploaded twice sends the '
      'same UTC instant both times', () async {
    final original = DateTime.parse(_serverSweatTestDate);

    final downloaded = UserProfile.fromSupabaseRow(
      _serverRow(),
      fallbackId: _user,
    );
    await repo.saveUserProfile(downloaded, needsUpload: true);
    expect((await repo.uploadDirtyRecords(_user)).success, isTrue);

    // The next round trip: the local row read back, saved and uploaded.
    final row = (await db.select(db.userProfilesTable).get()).single;
    final local = db.userDao.toDomainProfile(row);
    // Drift hands the date back in local time, as the other writers' do.
    expect(local.sweatTestDate!.isUtc, isFalse);
    await repo.saveUserProfile(local, needsUpload: true);
    expect((await repo.uploadDirtyRecords(_user)).success, isTrue);

    final sent = [
      for (final m in sentUsers()) m['sweat_test_date'] as String,
    ];
    expect(sent, hasLength(2));
    for (final s in sent) {
      expect(s, endsWith('Z'), reason: 'the offset is on the wire');
      expect(
        DateTime.parse(s).isAtSameMomentAs(original),
        isTrue,
        reason: '$s is the server instant $_serverSweatTestDate',
      );
    }
  });
}
