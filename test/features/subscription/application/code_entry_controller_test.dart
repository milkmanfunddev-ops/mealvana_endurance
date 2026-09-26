/// The Code entry's controller (mp-458, paywall ticket 18), driven through the
/// REAL notifier and the REAL status notifier, with `redeem-code` faked at the
/// Supabase functions client. Every answer is fed exactly as the function
/// sends it (supabase/functions/redeem-code/handler.ts, docs/test/README.md
/// Seam tests): a 200 with `ok`, or a non-2xx that `functions.invoke` raises
/// as a FunctionException.
///
/// A Code that grants `pro` (a coach's own, a giveaway) drops the SDK's cached
/// status and asks RevenueCat again, so the gate opens without a restart.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/coach_mode/application/coach_service.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/my_coaches_controller.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/code_entry_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_paywall_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/code_redemption.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

import '../../../helpers/widget_test_harness.dart';
import '../customer_info_fixtures.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

class _MockCoachService extends Mock implements CoachService {}

/// Settings (where coach mode lives) counting its builds; its own content
/// and profile reads are out of scope here.
class _CountingSettings extends SettingsController {
  static int builds = 0;

  @override
  FutureOr<SettingsState> build() {
    builds++;
    return Completer<SettingsState>().future;
  }
}

class _NoopScheduler implements LocalNotificationScheduler {
  @override
  Future<bool> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async => true;

  @override
  Future<void> cancel(int id) async {}
}

const _userId = 'u-1';

/// The function's own refusal texts (handler.ts `REFUSALS`).
const _refusals = {
  'not_found': "We don't recognise that code. Check it and try again.",
  'not_yet_valid': "That code isn't active yet.",
  'expired': 'That code has expired.',
  'used': 'That code has already been used.',
  'already_redeemed': "You've already used that code.",
  'own_code': "That's your own code. Share it with your athletes.",
  'already_paired': "You've already asked this coach to pair.",
};

void main() {
  late _MockFunctions functions;
  late _MockSubscriptionService service;
  late _MockRepository repo;
  late bool cacheDropped;
  late _MockCoachService coaches;

  setUp(() {
    coaches = _MockCoachService();
    _CountingSettings.builds = 0;
    when(
      () => coaches.syncCurrentCoachDataFromSupabase(),
    ).thenAnswer((_) async => false);
    when(
      () => coaches.syncRelationshipsFromSupabase(),
    ).thenAnswer((_) async => []);
    when(() => coaches.syncMyCoachesData()).thenAnswer((_) async {});
    when(() => coaches.syncMyAthletesProfiles()).thenAnswer((_) async {});
    when(() => coaches.getMyCoaches()).thenAnswer((_) async => []);
    when(() => coaches.getPendingCoachRequests()).thenAnswer((_) async => []);
    when(() => coaches.getCurrentCoachInfo()).thenAnswer((_) async => null);
    when(() => coaches.getMyAthletes()).thenAnswer((_) async => []);
    when(() => coaches.getPendingAthleteRequests()).thenAnswer((_) async => []);

    functions = _MockFunctions();
    service = _MockSubscriptionService();
    repo = _MockRepository();
    cacheDropped = false;
    when(() => repo.currentUserId).thenReturn(_userId);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => service.setStatusListener(any())).thenReturn(null);
    when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
    when(() => service.logIn(any())).thenAnswer((_) async {});
    // RevenueCat's cache still says "never" until it is dropped; after that
    // the SDK asks RevenueCat, which holds the server's grant.
    when(() => service.forgetCachedStatus()).thenAnswer((_) async {
      cacheDropped = true;
    });
    when(() => service.fetchStatus()).thenAnswer(
      (_) async =>
          statusOf(cacheDropped ? customerInfoGranted : customerInfoNever),
    );
  });

  void answer(Future<FunctionResponse> Function() respond) {
    when(
      () => functions.invoke('redeem-code', body: any(named: 'body')),
    ).thenAnswer((_) => respond());
  }

  void answer200(Map<String, dynamic> body) =>
      answer(() async => FunctionResponse(status: 200, data: body));

  ProviderContainer container() {
    final client = _MockSupabase();
    when(() => client.functions).thenReturn(functions);
    final c = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: client),
        subscriptionServiceProvider.overrideWithValue(service),
        userEntitlementsRepositoryProvider.overrideWithValue(repo),
        entitlementAnswerTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 60),
        ),
        localNotificationSchedulerProvider.overrideWithValue(_NoopScheduler()),
        coachServiceProvider.overrideWithValue(coaches),
        settingsControllerProvider.overrideWith(_CountingSettings.new),
        subscriptionClockProvider.overrideWithValue(
          () => customerInfoFetchedAt,
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(codeEntryControllerProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  Future<SubscriptionStatus> status(ProviderContainer c) =>
      c.read(subscriptionStatusProvider.future);

  group('a Code that grants pro opens the gate', () {
    test(
      "a coach's own Code: coach, 30 days, and the status re-asked",
      () async {
        answer200({'ok': true, 'kind': 'coach', 'pro_days': 30});
        final c = container();
        expect((await status(c)).active, isFalse);

        final result = await c
            .read(codeEntryControllerProvider.notifier)
            .redeem('coach42');

        expect(result, isA<CodeRedeemed>());
        final redeemed = result! as CodeRedeemed;
        expect(redeemed.kind, RedeemedKind.coach);
        expect(redeemed.proDays, 30);
        expect(c.read(codeEntryControllerProvider).value, same(result));
        verify(() => service.forgetCachedStatus()).called(1);
        expect((await status(c)).active, isTrue);
      },
    );

    test('a giveaway Code: 365 days, and the status re-asked', () async {
      answer200({'ok': true, 'kind': 'giveaway', 'pro_days': 365});
      final c = container();
      await status(c);

      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('WIN365');

      expect((result! as CodeRedeemed).kind, RedeemedKind.giveaway);
      expect((result as CodeRedeemed).proDays, 365);
      verify(() => service.forgetCachedStatus()).called(1);
      expect((await status(c)).active, isTrue);
    });

    // 87-001: ticket 45's purchase lock holds for a redeemed Code too. From
    // the Code's success until the router takes the paywall away, the
    // paywall's controller stays busy, so Continue cannot start a purchase.
    test('a Code that opens the gate holds the paywall busy until the '
        'account is closed again', () async {
      answer200({'ok': true, 'kind': 'giveaway', 'pro_days': 365});
      final c = container();
      final paywall = c.listen(proPaywallControllerProvider, (_, _) {});
      addTearDown(paywall.close);
      await status(c);
      expect(c.read(proPaywallControllerProvider), isA<AsyncData<void>>());

      await c.read(codeEntryControllerProvider.notifier).redeem('E2EGIVE365');

      expect(c.read(proPaywallControllerProvider), isA<AsyncLoading<void>>());
      // A later push that keeps the account open changes nothing.
      await c.read(subscriptionStatusProvider.notifier).refresh();
      expect(c.read(proPaywallControllerProvider), isA<AsyncLoading<void>>());

      // The Grant ends (or another account signs in): a later paywall sells.
      cacheDropped = false;
      await c.read(subscriptionStatusProvider.notifier).refresh();
      expect(c.read(proPaywallControllerProvider), isA<AsyncData<void>>());
    });
  });

  group('a Code that grants nothing leaves the status alone', () {
    test("an athlete entering a coach's Code: a pending pairing", () async {
      answer200({'ok': true, 'kind': 'paired', 'coach_user_id': 'coach-9'});
      final c = container();
      await status(c);

      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('COACH42');

      final redeemed = result! as CodeRedeemed;
      expect(redeemed.kind, RedeemedKind.paired);
      expect(redeemed.coachUserId, 'coach-9');
      expect(redeemed.grantsPro, isFalse);
      verifyNever(() => service.forgetCachedStatus());
      expect((await status(c)).active, isFalse);
    });

    test("an influencer's Code: only attributed", () async {
      answer200({'ok': true, 'kind': 'attributed'});
      final c = container();

      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('RUNFAST');

      expect((result! as CodeRedeemed).kind, RedeemedKind.attributed);
      verifyNever(() => service.forgetCachedStatus());
    });
  });

  // mp-600 (card mp-598): a Code that changes coaching updates the app at
  // once. The pairing lists are the REAL controllers over a faked
  // CoachService: what they show after the Code is what the pull brought.
  group('a Code that changes coaching refreshes coach mode and the '
      'pairings', () {
    final now = DateTime.utc(2026, 9, 26);
    final pending = CoachAthleteRelationship(
      id: 'rel-1',
      coachUserId: 'coach-9',
      athleteUserId: _userId,
      requestedBy: 'athlete',
      requestedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test("an athlete's coach Code: the pending pairing shows in My Coaches "
        'at once', () async {
      answer200({'ok': true, 'kind': 'paired', 'coach_user_id': 'coach-9'});
      final c = container();
      final list = c.listen(myCoachesControllerProvider, (_, _) {});
      addTearDown(list.close);
      final settings = c.listen(settingsControllerProvider, (_, _) {});
      addTearDown(settings.close);
      expect(
        (await c.read(myCoachesControllerProvider.future)).pendingRequests,
        isEmpty,
      );
      await settle(); // the list's own one-time background sync
      clearInteractions(coaches);
      final settingsBuilds = _CountingSettings.builds;

      // The server opened the pairing; the pull brings it into the local DB.
      when(
        () => coaches.syncRelationshipsFromSupabase(),
      ).thenAnswer((_) async => [pending]);
      when(
        () => coaches.getPendingCoachRequests(),
      ).thenAnswer((_) async => [pending]);

      await c.read(codeEntryControllerProvider.notifier).redeem('COACH42');

      verify(() => coaches.syncRelationshipsFromSupabase()).called(1);
      verify(() => coaches.syncMyCoachesData()).called(1);
      final shown = await c.read(myCoachesControllerProvider.future);
      expect(shown.pendingRequests.map((r) => r.coachUserId), ['coach-9']);
      await settle();
      expect(_CountingSettings.builds, greaterThan(settingsBuilds));
    });

    test("a coach's own Code: coach mode and the dashboard are rebuilt from "
        'the new coach record', () async {
      answer200({'ok': true, 'kind': 'coach', 'pro_days': 30});
      final c = container();
      final dash = c.listen(coachDashboardControllerProvider, (_, _) {});
      addTearDown(dash.close);
      final settings = c.listen(settingsControllerProvider, (_, _) {});
      addTearDown(settings.close);
      expect(
        (await c.read(coachDashboardControllerProvider.future)).isCoach,
        isFalse,
      );
      final settingsBuilds = _CountingSettings.builds;

      // The server wrote an approved coaches row; the pull brings it local.
      when(
        () => coaches.syncCurrentCoachDataFromSupabase(),
      ).thenAnswer((_) async => true);
      when(() => coaches.getCurrentCoachInfo()).thenAnswer(
        (_) async =>
            const CoachInfo(userId: _userId, deviceId: 'd-1', isCoach: true),
      );

      await c.read(codeEntryControllerProvider.notifier).redeem('coach42');

      expect(
        (await c.read(coachDashboardControllerProvider.future)).isCoach,
        isTrue,
      );
      await settle();
      expect(_CountingSettings.builds, greaterThan(settingsBuilds));
    });

    test('a failed pull still leaves the Code redeemed', () async {
      answer200({'ok': true, 'kind': 'paired', 'coach_user_id': 'coach-9'});
      when(
        () => coaches.syncRelationshipsFromSupabase(),
      ).thenThrow(Exception('offline'));
      final c = container();

      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('COACH42');

      expect((result! as CodeRedeemed).kind, RedeemedKind.paired);
      expect(c.read(codeEntryControllerProvider).hasError, isFalse);
    });

    test('a giveaway or influencer Code leaves coaching alone', () async {
      for (final body in [
        {'ok': true, 'kind': 'giveaway', 'pro_days': 365},
        {'ok': true, 'kind': 'attributed'},
      ]) {
        answer200(body);
        final c = container();
        await c.read(codeEntryControllerProvider.notifier).redeem('X');
      }
      verifyNever(() => coaches.syncRelationshipsFromSupabase());
      verifyNever(() => coaches.syncCurrentCoachDataFromSupabase());
    });
  });

  group('refusals are answers, each with its reason', () {
    const expected = {
      'not_found': CodeRefusal.notFound,
      'not_yet_valid': CodeRefusal.notYetValid,
      'expired': CodeRefusal.expired,
      'used': CodeRefusal.used,
      'already_redeemed': CodeRefusal.alreadyRedeemed,
      'own_code': CodeRefusal.ownCode,
      'already_paired': CodeRefusal.alreadyPaired,
    };
    for (final entry in expected.entries) {
      test(entry.key, () async {
        answer200({
          'ok': false,
          'reason': entry.key,
          'message': _refusals[entry.key],
        });
        final c = container();

        final result = await c
            .read(codeEntryControllerProvider.notifier)
            .redeem('NOPE');

        expect(result, isA<CodeRefused>());
        expect((result! as CodeRefused).reason, entry.value);
        expect(c.read(codeEntryControllerProvider).hasError, isFalse);
        verifyNever(() => service.forgetCachedStatus());
      });
    }

    test('a reason this build does not know keeps the server words', () async {
      answer200({
        'ok': false,
        'reason': 'region_locked',
        'message': 'That code only works in Canada.',
      });
      final c = container();

      final result =
          await c.read(codeEntryControllerProvider.notifier).redeem('CA1')
              as CodeRefused;

      expect(result.reason, CodeRefusal.other);
      expect(result.serverMessage, 'That code only works in Canada.');
    });

    test('a Code the server reads as blank (400 invalid_input) is not found, '
        'never "try again"', () async {
      answer(
        () async => throw FunctionException(
          status: 400,
          details: {'error': 'invalid_input', 'details': 'code is required'},
        ),
      );
      final c = container();

      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('ABC');

      expect(result, isA<CodeRefused>());
      expect((result! as CodeRefused).reason, CodeRefusal.notFound);
      expect(c.read(codeEntryControllerProvider).hasError, isFalse);
      verifyNever(() => service.forgetCachedStatus());
    });

    test('a Code too long to be one (400 code_too_long) is refused as too '
        'long, never "try again" (11-003)', () async {
      answer(
        () async => throw FunctionException(
          status: 400,
          details: {
            'error': 'code_too_long',
            'details': 'code is longer than 32 characters',
            'max_length': 32,
          },
        ),
      );
      final c = container();

      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('THIS-CODE-IS-FAR-TOO-LONG-TO-BE-ONE-X');

      expect(result, isA<CodeRefused>());
      expect((result! as CodeRefused).reason, CodeRefusal.tooLong);
      expect(c.read(codeEntryControllerProvider).hasError, isFalse);
      verifyNever(() => service.forgetCachedStatus());
    });
  });

  group('no answer is an error, never a grant', () {
    Future<CodeRedeemFailureKind?> failureOf(ProviderContainer c) async {
      final result = await c
          .read(codeEntryControllerProvider.notifier)
          .redeem('ABC');
      expect(result, isNull);
      final state = c.read(codeEntryControllerProvider);
      expect(state.hasError, isTrue);
      return (state.error as CodeRedeemFailure?)?.kind;
    }

    test('an anonymous session (403 sign_in_required)', () async {
      answer(
        () async => throw FunctionException(
          status: 403,
          details: {'error': 'sign_in_required'},
        ),
      );
      expect(
        await failureOf(container()),
        CodeRedeemFailureKind.signInRequired,
      );
    });

    test('the store down (502 store_unavailable)', () async {
      answer(
        () async => throw FunctionException(
          status: 502,
          details: {'error': 'store_unavailable'},
        ),
      );
      expect(await failureOf(container()), CodeRedeemFailureKind.unavailable);
      verifyNever(() => service.forgetCachedStatus());
    });

    test('no network', () async {
      answer(() async => throw Exception('SocketException'));
      expect(await failureOf(container()), CodeRedeemFailureKind.unavailable);
    });

    test('a body it cannot read', () async {
      answer(() async => FunctionResponse(status: 200, data: 'oops'));
      expect(await failureOf(container()), CodeRedeemFailureKind.unavailable);
    });
  });

  test('sends the Code as typed, trimmed; the server normalises it', () async {
    answer200({'ok': true, 'kind': 'attributed'});
    final c = container();

    await c.read(codeEntryControllerProvider.notifier).redeem('  run fast ');

    verify(
      () => functions.invoke('redeem-code', body: {'code': 'run fast'}),
    ).called(1);
  });

  test('a blank Code is never sent', () async {
    final c = container();

    final result = await c
        .read(codeEntryControllerProvider.notifier)
        .redeem('   ');

    expect(result, isNull);
    verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
  });

  test('reset clears the last answer for the next entry', () async {
    answer200({'ok': false, 'reason': 'used', 'message': _refusals['used']});
    final c = container();
    final notifier = c.read(codeEntryControllerProvider.notifier);
    await notifier.redeem('USED');
    expect(c.read(codeEntryControllerProvider).value, isA<CodeRefused>());

    notifier.reset();

    expect(
      c.read(codeEntryControllerProvider),
      const AsyncData<CodeRedemption?>(null),
    );
  });
}
