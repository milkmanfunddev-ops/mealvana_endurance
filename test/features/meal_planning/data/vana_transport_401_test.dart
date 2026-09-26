/// A 401 from a Vana function earns one session refresh (testing-wave
/// 117-011): a global logout elsewhere left the phone signed in while Vana
/// answered 401 eleven times. A refused refresh token signs the phone out
/// locally (the router then lands on Log In); a refresh that could not reach
/// the server leaves the session alone; nothing retries the call itself, and
/// concurrent 401s share one refresh.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes.dart';

/// GoTrue's answer to a refresh token the server has revoked.
final _refused = AuthApiException(
  'Invalid Refresh Token: Refresh Token Not Found',
  statusCode: '400',
  code: 'refresh_token_not_found',
);

class _MockAuthResponse extends Mock implements AuthResponse {}

TransportHarness _unauthenticated() =>
    TransportHarness(status: 401, body: '{"error":"unauthenticated"}');

MockGoTrueClient _auth(TransportHarness h) => h.supabase.auth as MockGoTrueClient;

void main() {
  setUpAll(() {
    registerFallbackValue(SignOutScope.local);
  });

  test('a refused refresh signs out locally; the call still fails as '
      'unauthenticated and is not retried', () async {
    final h = _unauthenticated();
    final auth = _auth(h);
    when(() => auth.refreshSession()).thenThrow(_refused);
    when(() => auth.signOut(scope: any(named: 'scope'))).thenAnswer((_) async {});

    await expectLater(
      h.transport.postJson('vana-action', {'type': 'get_home'}),
      throwsA(isA<VanaUnauthenticatedException>()),
    );

    verify(() => auth.refreshSession()).called(1);
    verify(() => auth.signOut(scope: SignOutScope.local)).called(1);
    expect(h.requests, hasLength(1), reason: 'nothing retries a 401');
  });

  test('a refresh that cannot reach the server leaves the session alone', () async {
    final h = _unauthenticated();
    final auth = _auth(h);
    when(() => auth.refreshSession()).thenThrow(
      AuthRetryableFetchException(message: 'SocketException: offline'),
    );

    await expectLater(
      h.transport.postJson('vana-action', {'type': 'get_home'}),
      throwsA(isA<VanaUnauthenticatedException>()),
    );

    verify(() => auth.refreshSession()).called(1);
    verifyNever(() => auth.signOut(scope: any(named: 'scope')));
  });

  test('a refresh that succeeds signs nothing out; the call is not retried', () async {
    final h = _unauthenticated();
    final auth = _auth(h);
    when(() => auth.refreshSession()).thenAnswer((_) async => _MockAuthResponse());

    await expectLater(
      h.transport.streamNdjson('vana-chat', {'message': 'hi'}),
      throwsA(isA<VanaUnauthenticatedException>()),
    );

    verify(() => auth.refreshSession()).called(1);
    verifyNever(() => auth.signOut(scope: any(named: 'scope')));
    expect(h.requests, hasLength(1));
  });

  test('eleven concurrent 401s share one refresh', () async {
    final h = _unauthenticated();
    final auth = _auth(h);
    final gate = Completer<AuthResponse>();
    when(() => auth.refreshSession()).thenAnswer((_) => gate.future);

    final calls = List.generate(
      11,
      (_) => h.transport
          .postJson('vana-action', {'type': 'get_home'})
          .then<Object?>((v) => v, onError: (Object e) => e),
    );
    await pumpEventQueue();
    gate.complete(_MockAuthResponse());
    final results = await Future.wait(calls);

    expect(results, everyElement(isA<VanaUnauthenticatedException>()));
    verify(() => auth.refreshSession()).called(1);
  });

  test('a 401 with no session held does not ask for a refresh', () async {
    // The session went while the request was in flight: nothing to refresh.
    final h = _unauthenticated();
    final auth = _auth(h);
    final session = auth.currentSession;
    var built = false;
    when(() => auth.currentSession).thenAnswer((_) {
      if (built) return null;
      built = true;
      return session;
    });

    await expectLater(
      h.transport.postJson('vana-action', {'type': 'get_home'}),
      throwsA(isA<VanaUnauthenticatedException>()),
    );

    verifyNever(() => auth.refreshSession());
  });

  test('GoTrue already dropped the session on the refused refresh: no second '
      'sign-out', () async {
    final h = _unauthenticated();
    final auth = _auth(h);
    final session = auth.currentSession;
    var dropped = false;
    when(() => auth.currentSession).thenAnswer((_) => dropped ? null : session);
    when(() => auth.refreshSession()).thenAnswer((_) async {
      dropped = true;
      throw _refused;
    });

    await expectLater(
      h.transport.postJson('vana-action', {'type': 'get_home'}),
      throwsA(isA<VanaUnauthenticatedException>()),
    );

    verifyNever(() => auth.signOut(scope: any(named: 'scope')));
  });
}
