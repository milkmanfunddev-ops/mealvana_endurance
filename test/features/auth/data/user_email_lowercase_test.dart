/// `public.users.email` is lowercase at write (develop-2026-10 ticket 21,
/// 01-009). The address reaches the profile as the athlete typed it on
/// personal info; the two write places (the local Drift row and
/// `UserProfile.toJson`, which the upload upserts) store it trimmed and
/// lowercase.
///
/// Seam: the real [UserRepository] on in-memory Drift, and the real postgrest
/// builder against an in-memory PostgREST ([FakePostgrest]) that records what
/// was upserted.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/signup_code.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../../helpers/fakes/fake_postgrest.dart';
import '../../../helpers/fakes/recording_report.dart';

const _user = '5e2f3a1b-7c4d-4e8f-9a0b-1c2d3e4f5a6b';

/// As typed on personal info in the run (Finding 01-009).
const _typed = '  Lee+E2E-01-20261007T110602Z@Example.com ';

UserProfile _profile({String? email}) => UserProfile(
  id: _user,
  deviceId: 'device-21',
  authUserId: _user,
  authProvider: 'email',
  isAnonymous: false,
  gender: Gender.male,
  birthday: DateTime(1985, 3, 3),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  onboardingCompleted: true,
  createdAt: DateTime.utc(2026, 10, 7, 11, 6, 2),
  updatedAt: DateTime.utc(2026, 10, 7, 11, 6, 2),
  appVersion: '1.0.0',
  email: email,
);

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

  Map<String, dynamic> lastUsersWrite() {
    final body = server.writes.where((w) => w.table == 'users').last.body;
    return ((body is List ? body.single : body) as Map).cast<String, dynamic>();
  }

  test('normaliseEmail trims, lowercases, and empties to null', () {
    expect(normaliseEmail(_typed), 'lee+e2e-01-20261007t110602z@example.com');
    expect(normaliseEmail('   '), isNull);
    expect(normaliseEmail(null), isNull);
  });

  test('a profile saved with the address as typed is stored and uploaded '
      'lowercase', () async {
    await repo.saveUserProfile(_profile(email: _typed), needsUpload: true);

    final row = (await db.select(db.userProfilesTable).get()).single;
    expect(row.email, 'lee+e2e-01-20261007t110602z@example.com');

    final result = await repo.uploadDirtyRecords(_user);
    expect(result.success, isTrue, reason: '$result');
    expect(
      lastUsersWrite()['email'],
      'lee+e2e-01-20261007t110602z@example.com',
    );
  });

  test('no address stays no address', () async {
    await repo.saveUserProfile(_profile(), needsUpload: true);
    await repo.uploadDirtyRecords(_user);

    expect((await db.select(db.userProfilesTable).get()).single.email, isNull);
    expect(lastUsersWrite()['email'], isNull);
  });
}
