/// The device regression: "Build My Plan" does nothing after sign-out.
///
/// `OnboardingSessionController` is auto-dispose and `_getStarted` reaches it
/// with a bare `ref.read(...notifier)` — nothing watches it. When the session
/// call is slow (a real `signInAnonymously()` network round-trip, as opposed
/// to a test double that returns immediately) the provider is disposed while
/// the call is still in flight. `ensureOnboardingSession` then assigns
/// `state =` on a disposed notifier, and THAT assignment is outside
/// `AsyncValue.guard` — so it throws out of the method, past the call site,
/// and `navigator.push` below it never runs.
///
/// The signature matched the field report exactly: the anonymous user IS
/// created server-side (the network call completed), and the UI does nothing.
/// "I already have an account" kept working because it is synchronous and
/// touches no provider state.
///
/// The pre-fix screen wrapped the whole thing in try/catch, so navigation was
/// unconditional. That guarantee is what regressed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_session_controller.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  test(
    'ensureOnboardingSession never throws when its provider is disposed '
    'mid-flight — the tap must still be able to navigate',
    () async {
      final container = ProviderContainer(
        overrides: [mockAppExternalDeps(), mockSharedPreferences()],
      );

      final notifier =
          container.read(onboardingSessionControllerProvider.notifier);

      // Start the call, then dispose while it is still in flight — exactly
      // what auto-dispose does on device during the network round-trip.
      final pending = notifier.ensureOnboardingSession();
      container.dispose();

      await expectLater(pending, completes);
    },
  );
}
