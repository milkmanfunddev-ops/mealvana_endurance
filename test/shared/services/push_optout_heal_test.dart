import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

/// The heal rule for an SDK-level push opt-out (the unreachable-player
/// Critical's mechanism, 2026-10-01): a player with a valid APNs token but
/// notification_types=-30, created by the app's only optOut() racing its own
/// optIn() in the settings reset button — and permanent, because nothing else
/// ever opted back in.
///
/// The rule lives in a pure predicate so it is testable without the OneSignal
/// static SDK; `_initializeOneSignal` applies it with the OS-permission bool
/// that `requestPermission(false)` returns and the SDK's `optedIn` state.
/// These four cases ARE the contract — especially the two that must NOT heal.
void main() {
  group('shouldHealPushOptOut', () {
    test('heals: permission granted + SDK explicitly opted out', () {
      expect(
        NotificationService.shouldHealPushOptOut(
          permissionGranted: true,
          optedIn: false,
        ),
        isTrue,
        reason: 'valid token, -30 state — the fleet case this exists for',
      );
    });

    test('never heals without permission — optIn() would PROMPT', () {
      // The SDK docs: optIn "will prompt the user for push notifications
      // permission" if it is missing. This init deliberately never hijacks
      // previously-denied users (fallbackToSettings: false), and the heal
      // must not become the thing that does.
      expect(
        NotificationService.shouldHealPushOptOut(
          permissionGranted: false,
          optedIn: false,
        ),
        isFalse,
      );
    });

    test('never heals on unknown (null) state', () {
      // optedIn is bool?: null means the SDK has not reported yet. Acting on
      // unknown risks an optIn before state settles; the next launch sees
      // cached state and heals then. Patience over guessing.
      expect(
        NotificationService.shouldHealPushOptOut(
          permissionGranted: true,
          optedIn: null,
        ),
        isFalse,
      );
    });

    test('no-op when already opted in', () {
      expect(
        NotificationService.shouldHealPushOptOut(
          permissionGranted: true,
          optedIn: true,
        ),
        isFalse,
      );
    });
  });
}
