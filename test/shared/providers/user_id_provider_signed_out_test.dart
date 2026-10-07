// DEV-8G (round-up 2026-10): signed out with no cached profile, the real
// `userIdProvider` throws "No user profile found. User must complete
// onboarding first." The Riverpod net reported each throw as a Fault (7
// events), but it is the router's signal to send the athlete to
// welcome/onboarding, not a failure. This drives the real provider in that
// state and classifies exactly what it throws, the way `Report.fault` does.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/application/supabase_auth_service.dart'
    as supabase_auth;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/expected_failures.dart';

import '../../helpers/fakes/fake_supabase_client.dart';

void main() {
  test('signed out with no cached profile: what userIdProvider throws is the '
      'no_profile signal, not a Fault (DEV-8G)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        supabase_auth.currentUserProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: const NoopAnalyticsTracker(),
            supabaseClient: fakeSupabaseClient(),
            sharedPreferences: prefs,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    Object? thrown;
    try {
      await container.read(userIdProvider.future);
    } catch (e) {
      thrown = e is ProviderException ? e.exception : e;
    }

    expect(thrown, isNotNull, reason: 'no session, no profile: it must throw');
    expect(
      thrown.toString(),
      contains('No user profile found. User must complete onboarding first.'),
    );
    expect(
      classifyExpectedFailure(describeThrowable(thrown!)),
      ExpectedFailure.noProfile,
    );
  });
}
