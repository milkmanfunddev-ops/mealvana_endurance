/// `isAdminProvider` — the client's read of `users.is_admin` (mp-144
/// clause 3). The seam is the users row as PostgREST returns it: `true`,
/// `false`, `null` on a row that predates the column, or no row at all.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../../features/meal_planning/helpers/container.dart';
import '../../features/meal_planning/helpers/fakes.dart';

void main() {
  group('adminFlagFromUsersRow (PostgREST-shaped)', () {
    test('true only when the column is literally true', () {
      expect(adminFlagFromUsersRow({'is_admin': true}), isTrue);
      expect(adminFlagFromUsersRow({'is_admin': false}), isFalse);
      expect(adminFlagFromUsersRow({'is_admin': null}), isFalse);
      expect(adminFlagFromUsersRow({'id': 'u1'}), isFalse);
      expect(adminFlagFromUsersRow(null), isFalse);
      // A stringly value from a hand-edited dump is not a grant.
      expect(adminFlagFromUsersRow({'is_admin': 'true'}), isFalse);
    });
  });

  test('signed out is never admin and never reads the table', () async {
    final container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: testDeps().analytics,
            supabaseClient: supabaseWithSession(signedIn: false),
            sentry: testDeps().sentry,
            logger: FakeLogger(),
            sharedPreferences: testDeps().sharedPreferences,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(isAdminProvider.future), isFalse);
  });
}
