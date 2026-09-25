/// `CoachRepository.findUserIdByAthleteCode` (ticket 102): the local lookup
/// matches the code against the signed-in account's profile only. It used
/// to scan every profile on the phone, so another account's leftover row
/// answered a code the server should have resolved.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../../helpers/fakes/fake_supabase_client.dart';

class _MockLogger extends Mock implements AppLogger {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);
  @override
  final String id;
}

const _a = 'aaaaaaaa-0000-4000-8000-000000000001';
const _b = 'bbbbbbbb-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;
  late MockSupabaseClient client;
  late CoachRepository repo;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    for (final id in [_a, _b]) {
      await db
          .into(db.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: id,
              deviceId: 'device',
              authUserId: Value(id),
            ),
          );
    }
    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(_FakeUser(_b));
    client = fakeSupabaseClient(auth: auth) as MockSupabaseClient;
    // The server is the only place another account's code resolves; here it
    // is off, so a remote lookup answers null through the repository's catch.
    when(() => client.from(any())).thenThrow(StateError('remote off'));
    repo = CoachRepository(
      supabase: client,
      database: db,
      logger: _MockLogger(),
      sentry: const NoopSentryReporter(),
    );
  });

  test("another account's code is not answered from its local row", () async {
    expect(await repo.findUserIdByAthleteCode('ATH-AAAAAAAA'), isNull);
    verify(() => client.from('users')).called(1);
  });

  test("the signed-in account's own code resolves locally", () async {
    expect(await repo.findUserIdByAthleteCode('ATH-BBBBBBBB'), _b);
    verifyNever(() => client.from(any()));
  });
}
