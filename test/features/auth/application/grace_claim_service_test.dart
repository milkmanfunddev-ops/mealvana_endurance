// The grace claim, app side (mp-455 §4; paywall ticket 09).
//
// After an old anonymous install signs up onto its user, the app asks the
// `grace-claim` function for the grace month. The answers are fed as the
// function sends them (supabase/functions/grace-claim/handler.ts): a 200
// with `ok`, or a non-2xx that functions.invoke raises as FunctionException.
// The claim never throws: whatever the answer, the athlete moves on to the
// paywall. When access was granted, the SDK's cached status is dropped so the
// gate asks RevenueCat again.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/application/grace_claim_service.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';

import '../../../helpers/widget_test_harness.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockSubscriptions extends Mock implements SubscriptionService {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

User _user(String id, {bool anonymous = false}) {
  final user = _MockUser();
  when(() => user.id).thenReturn(id);
  when(() => user.isAnonymous).thenReturn(anonymous);
  return user;
}

/// The claim with its pending mark kept in real (in-memory) preferences, a
/// signed-in [user], and the function answering from [answers] in turn.
Future<
  ({
    GraceClaimService service,
    _MockFunctions functions,
    SharedPreferences prefs,
    _MockAuth auth,
  })
>
_withPrefs({
  required User? user,
  required List<Future<FunctionResponse> Function()> answers,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final functions = _MockFunctions();
  var call = 0;
  when(
    () => functions.invoke('grace-claim'),
  ).thenAnswer((_) => answers[call++]());
  final auth = _MockAuth();
  when(() => auth.currentUser).thenReturn(user);
  final client = _MockSupabase();
  when(() => client.functions).thenReturn(functions);
  when(() => client.auth).thenReturn(auth);
  final subs = _MockSubscriptions();
  when(() => subs.forgetCachedStatus()).thenAnswer((_) async {});
  return (
    service: GraceClaimService(
      supabase: client,
      subscriptions: subs,
      logger: MockAppLogger(),
      prefs: prefs,
    ),
    functions: functions,
    prefs: prefs,
    auth: auth,
  );
}

Future<FunctionResponse> _granted() async => FunctionResponse(
  status: 200,
  data: {'ok': true, 'status': 'granted', 'pro_days': 30},
);

Future<FunctionResponse> _storeDown() async => throw FunctionException(
  status: 502,
  details: {'error': 'store_unavailable'},
);

({GraceClaimService service, _MockFunctions functions, _MockSubscriptions subs})
_wired(Future<FunctionResponse> Function() answer) {
  final functions = _MockFunctions();
  when(() => functions.invoke('grace-claim')).thenAnswer((_) => answer());
  final client = _MockSupabase();
  when(() => client.functions).thenReturn(functions);
  final subs = _MockSubscriptions();
  when(() => subs.forgetCachedStatus()).thenAnswer((_) async {});
  return (
    service: GraceClaimService(
      supabase: client,
      subscriptions: subs,
      logger: MockAppLogger(),
    ),
    functions: functions,
    subs: subs,
  );
}

void main() {
  test('a grant drops the cached status so the gate asks RevenueCat', () async {
    final w = _wired(
      () async => FunctionResponse(
        status: 200,
        data: {'ok': true, 'status': 'granted', 'pro_days': 30},
      ),
    );
    expect(await w.service.claim(), GraceClaimResult.granted);
    verify(() => w.subs.forgetCachedStatus()).called(1);
  });

  test('already held reads as held, and still refreshes', () async {
    final w = _wired(
      () async => FunctionResponse(
        status: 200,
        data: {'ok': true, 'status': 'already', 'pro_days': 0},
      ),
    );
    expect(await w.service.claim(), GraceClaimResult.alreadyHeld);
    verify(() => w.subs.forgetCachedStatus()).called(1);
  });

  test('a refusal is not eligible, and leaves the cache alone', () async {
    final w = _wired(
      () async => FunctionResponse(
        status: 200,
        data: {'ok': false, 'reason': 'not_eligible'},
      ),
    );
    expect(await w.service.claim(), GraceClaimResult.notEligible);
    verifyNever(() => w.subs.forgetCachedStatus());
  });

  test('before the flip is not eligible', () async {
    final w = _wired(
      () async => FunctionResponse(
        status: 200,
        data: {'ok': false, 'reason': 'before_flip'},
      ),
    );
    expect(await w.service.claim(), GraceClaimResult.notEligible);
  });

  test('a store outage (502) fails without throwing', () async {
    final w = _wired(
      () async => throw FunctionException(
        status: 502,
        details: {'error': 'store_unavailable'},
      ),
    );
    expect(await w.service.claim(), GraceClaimResult.failed);
    verifyNever(() => w.subs.forgetCachedStatus());
  });

  test('no network fails without throwing', () async {
    final w = _wired(() async => throw Exception('SocketException'));
    expect(await w.service.claim(), GraceClaimResult.failed);
  });

  test('no answer in time fails without holding the athlete', () async {
    final functions = _MockFunctions();
    when(
      () => functions.invoke('grace-claim'),
    ).thenAnswer((_) => Completer<FunctionResponse>().future);
    final client = _MockSupabase();
    when(() => client.functions).thenReturn(functions);
    final service = GraceClaimService(
      supabase: client,
      subscriptions: _MockSubscriptions(),
      logger: MockAppLogger(),
      timeout: const Duration(milliseconds: 10),
    );
    expect(await service.claim(), GraceClaimResult.failed);
  });

  // mp-561 (card mp-555): a failed claim is tried again at the next start.
  group('retry at the next start', () {
    const uid = 'old-install-user';

    test('a failed claim leaves the account marked; the retry at the next '
        'start claims again and clears the mark once answered', () async {
      final w = await _withPrefs(
        user: _user(uid),
        answers: [_storeDown, _granted],
      );
      expect(await w.service.claim(), GraceClaimResult.failed);
      expect(w.prefs.getString(GraceClaimService.pendingKey), uid);

      expect(await w.service.retryPending(), GraceClaimResult.granted);
      expect(w.prefs.getString(GraceClaimService.pendingKey), isNull);
      verify(() => w.functions.invoke('grace-claim')).called(2);
    });

    test(
      'an answered claim leaves no mark, so the next start asks nothing',
      () async {
        final w = await _withPrefs(user: _user(uid), answers: [_granted]);
        expect(await w.service.claim(), GraceClaimResult.granted);
        expect(w.prefs.getString(GraceClaimService.pendingKey), isNull);

        expect(await w.service.retryPending(), isNull);
        verify(() => w.functions.invoke('grace-claim')).called(1);
      },
    );

    test('a refusal (not eligible) is an answer: no retry', () async {
      final w = await _withPrefs(
        user: _user(uid),
        answers: [
          () async => FunctionResponse(
            status: 200,
            data: {'ok': false, 'reason': 'not_eligible'},
          ),
        ],
      );
      expect(await w.service.claim(), GraceClaimResult.notEligible);
      expect(w.prefs.getString(GraceClaimService.pendingKey), isNull);
    });

    test(
      'a retry that fails again keeps the mark for the start after',
      () async {
        final w = await _withPrefs(
          user: _user(uid),
          answers: [_storeDown],
          stored: {GraceClaimService.pendingKey: uid},
        );
        expect(await w.service.retryPending(), GraceClaimResult.failed);
        expect(w.prefs.getString(GraceClaimService.pendingKey), uid);
      },
    );

    test('no mark: the retry never calls the function', () async {
      final w = await _withPrefs(user: _user(uid), answers: []);
      expect(await w.service.retryPending(), isNull);
      verifyNever(() => w.functions.invoke('grace-claim'));
    });

    test('another account signed in: no claim, and the mark is kept for '
        'the account it names', () async {
      final w = await _withPrefs(
        user: _user('someone-else'),
        answers: [],
        stored: {GraceClaimService.pendingKey: uid},
      );
      expect(await w.service.retryPending(), isNull);
      verifyNever(() => w.functions.invoke('grace-claim'));
      expect(w.prefs.getString(GraceClaimService.pendingKey), uid);
    });

    test('signed out or still anonymous: no claim', () async {
      for (final user in <User?>[null, _user(uid, anonymous: true)]) {
        final w = await _withPrefs(
          user: user,
          answers: [],
          stored: {GraceClaimService.pendingKey: uid},
        );
        expect(await w.service.retryPending(), isNull);
        verifyNever(() => w.functions.invoke('grace-claim'));
      }
    });
  });
}
