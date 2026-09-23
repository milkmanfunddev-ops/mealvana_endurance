// Regression test for the push-alias detachment bug found on prod 2026-09-22.
//
// `garmin-push` targets OneSignal by `include_aliases.external_id`, so the
// device is reachable only while the athlete's Supabase user id is attached
// to it. The client used one setter for two very different things:
//
//   * "the athlete signed out"        -> detach (correct)
//   * "the session has not restored"  -> ALSO detached (the bug)
//
// Startup passes `auth.currentUser?.id`, which is null whenever the Supabase
// session is still restoring. A returning athlete never emits `signedIn` —
// the session comes back as `initialSession`/`tokenRefreshed` — so nothing
// re-attached the alias, and every push afterwards came back
// `invalid_aliases` while OneSignal still answered 200. Measured blast
// radius the day it was found: 6 of 17 prod athletes unreachable.
//
// These assertions run against the real NotificationService. OneSignal itself
// is never initialised in a test binding, so the sync step returns early and
// no SDK call is attempted — the identity bookkeeping is what is under test.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('remote push identity', () {
    test('a known athlete id is retained for the next sync', () async {
      await NotificationService.setRemotePushUserId('athlete-1');
      expect(NotificationService.pendingRemotePushUserId, 'athlete-1');
    });

    test('null does NOT detach — it means "not known yet", not "signed out"',
        () async {
      await NotificationService.setRemotePushUserId('athlete-1');

      // Exactly what startup does on an offline launch or a refresh in
      // flight: auth.currentUser is null for a still-signed-in athlete.
      await NotificationService.setRemotePushUserId(null);

      expect(
        NotificationService.pendingRemotePushUserId,
        'athlete-1',
        reason: 'an unrestored session must never strand the device — this is '
            'the exact path that produced invalid_aliases on prod',
      );
    });

    test('empty and whitespace ids are treated the same as null', () async {
      await NotificationService.setRemotePushUserId('athlete-1');
      await NotificationService.setRemotePushUserId('');
      await NotificationService.setRemotePushUserId('   ');
      expect(NotificationService.pendingRemotePushUserId, 'athlete-1');
    });

    test('an explicit sign-out DOES detach', () async {
      await NotificationService.setRemotePushUserId('athlete-1');
      await NotificationService.clearRemotePushUserId();
      expect(NotificationService.pendingRemotePushUserId, isNull);
    });

    test('switching athletes replaces the id', () async {
      await NotificationService.setRemotePushUserId('athlete-1');
      await NotificationService.setRemotePushUserId('athlete-2');
      expect(NotificationService.pendingRemotePushUserId, 'athlete-2');
    });

    test('an id is trimmed before it is claimed', () async {
      await NotificationService.clearRemotePushUserId();
      await NotificationService.setRemotePushUserId('  athlete-3  ');
      expect(NotificationService.pendingRemotePushUserId, 'athlete-3');
    });
  });
}
