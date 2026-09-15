/// Unit tests for [UserEntitlementsRepository] — the auth-identity seam the
/// subscription feature reads. There is no remote read and no Drift cache
/// any more: the client's gate is RevenueCat's cache (mp-284), and the
/// server's two-field table is the webhook's and the edge functions' alone
/// (mp-285).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id, {this.isAnonymous = false});
  @override
  final String id;
  @override
  final bool isAnonymous;
}

class _FakeSession extends Fake implements Session {
  _FakeSession(this.user);
  @override
  final User user;
}

void main() {
  late _MockSupabaseClient supabase;
  late _MockGoTrueClient auth;
  late UserEntitlementsRepository repo;

  setUp(() {
    supabase = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.onAuthStateChange,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    repo = UserEntitlementsRepository(supabase: supabase);
  });

  test('signed out → no user id, not anonymous', () {
    expect(repo.currentUserId, isNull);
    expect(repo.isAnonymousUser, isFalse);
  });

  test('signed in → the auth user id', () {
    when(() => auth.currentUser).thenReturn(_FakeUser('u-1'));
    expect(repo.currentUserId, 'u-1');
    expect(repo.isAnonymousUser, isFalse);
  });

  test('an anonymous session is reported as such (purchases refuse it)', () {
    when(() => auth.currentUser).thenReturn(_FakeUser('anon', isAnonymous: true));
    expect(repo.isAnonymousUser, isTrue);
  });

  test('authUserIdChanges maps sessions to ids, distinct, null on sign-out', () async {
    final events = StreamController<AuthState>();
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);

    final seen = <String?>[];
    final sub = repo.authUserIdChanges.listen(seen.add);
    addTearDown(sub.cancel);

    events
      ..add(AuthState(AuthChangeEvent.signedIn, _FakeSession(_FakeUser('u-1'))))
      // A token refresh for the same user must not chatter.
      ..add(
        AuthState(AuthChangeEvent.tokenRefreshed, _FakeSession(_FakeUser('u-1'))),
      )
      ..add(AuthState(AuthChangeEvent.signedOut, null))
      ..add(AuthState(AuthChangeEvent.signedIn, _FakeSession(_FakeUser('u-2'))));
    await events.close();
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['u-1', null, 'u-2']);
  });
}
