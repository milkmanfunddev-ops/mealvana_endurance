/// `isAdminProvider` — the client's read of `users.is_admin` (mp-144
/// clause 3). The seam is the users row as PostgREST returns it: `true`,
/// `false`, `null` on a row that predates the column, or no row at all.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Ticket 130 (Finding 89-010): one failed read at an offline start hid
  /// Team review for the whole session. The read still answers false on a
  /// failure (the gate awaits it), and reads again when the network comes
  /// back or the app resumes.
  group('a failed read is retried', () {
    late int reads;
    late StubConnectivity connectivity;
    late ProviderContainer container;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      reads = 0;
      final client = supabaseWithSession();
      when(() => client.from('users')).thenAnswer((_) {
        reads++;
        throw const SocketException('Network is unreachable');
      });
      connectivity = StubConnectivity(online: false);
      container = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: testDeps().analytics,
              supabaseClient: client,
              sentry: testDeps().sentry,
              logger: FakeLogger(),
              sharedPreferences: testDeps().sharedPreferences,
            ),
          ),
          connectivityCheckerProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(container.dispose);
      container.listen(isAdminProvider, (_, _) {});
    });

    test('answers false, then reads again when the network returns', () async {
      expect(await container.read(isAdminProvider.future), isFalse);
      expect(reads, 1);

      connectivity.changes.add(false);
      await pumpEventQueue();
      expect(reads, 1, reason: 'going offline is not a reason to read');

      connectivity.changes.add(true);
      await pumpEventQueue();
      expect(await container.read(isAdminProvider.future), isFalse);
      expect(reads, 2, reason: 'the network came back: read again');
    });

    test(
      'an online report with no offline before it does not re-read',
      () async {
        // connectivity_plus reports the current state on subscribe: a read
        // that failed while online (a 5xx) must not loop on that report.
        expect(await container.read(isAdminProvider.future), isFalse);
        expect(reads, 1);

        connectivity.changes.add(true);
        await pumpEventQueue();
        expect(reads, 1);
      },
    );

    test('reads again on the next app resume', () async {
      expect(await container.read(isAdminProvider.future), isFalse);
      expect(reads, 1);

      // Backgrounded and brought back, one state at a time as the platform
      // sends them (the test binding does not fill in the steps between).
      final binding = TestWidgetsFlutterBinding.instance;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      await pumpEventQueue();
      expect(await container.read(isAdminProvider.future), isFalse);
      expect(reads, 2);
    });
  });

  // Testing-wave 118-003, 119-004, 120-009: GoTrue's auth stream replays
  // every past event to a new subscriber. Each rebuild subscribed again,
  // saw a replayed event whose session was not the current user, and
  // invalidated itself: a failing read every 25-70 ms while offline.
  test(
    'replayed auth events with another session never re-read; only a real '
    'user change does',
    () async {
      final replayed = [
        const AuthState(AuthChangeEvent.signedOut, null),
        AuthState(AuthChangeEvent.initialSession, _sessionFor('user-0')),
        AuthState(AuthChangeEvent.tokenRefreshed, _sessionFor('user-1')),
      ];
      TestWidgetsFlutterBinding.ensureInitialized();
      var reads = 0;
      final connectivity = StubConnectivity(online: false);
      final live = StreamController<AuthState>.broadcast();
      addTearDown(live.close);
      final client = supabaseWithSession();
      final auth = client.auth as MockGoTrueClient;
      // What GoTrue's ReplaySubject does: every past event, then live ones.
      Stream<AuthState> replayThenLive() async* {
        yield* Stream.fromIterable(replayed);
        yield* live.stream;
      }

      when(() => auth.onAuthStateChange).thenAnswer((_) => replayThenLive());
      when(() => client.from('users')).thenAnswer((_) {
        reads++;
        throw const SocketException('Network is unreachable');
      });
      final c = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: testDeps().analytics,
              supabaseClient: client,
              sentry: testDeps().sentry,
              logger: FakeLogger(),
              sharedPreferences: testDeps().sharedPreferences,
            ),
          ),
          connectivityCheckerProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(c.dispose);
      c.listen(isAdminProvider, (_, _) {});

      expect(await c.read(isAdminProvider.future), isFalse);
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
      expect(reads, 1, reason: 'the replay is not a user change');

      // A real sign-out: GoTrue drops the user before it emits the event.
      when(() => auth.currentUser).thenReturn(null);
      live.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      expect(await c.read(isAdminProvider.future), isFalse);
      expect(reads, 1, reason: 'signed out: no read, no user to read for');
    },
  );
}

Session _sessionFor(String userId) {
  final session = MockSession();
  final user = MockUser();
  when(() => user.id).thenReturn(userId);
  when(() => session.user).thenReturn(user);
  when(() => session.accessToken).thenReturn('token-$userId');
  return session;
}
