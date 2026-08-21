/// Unit tests for [CreditsController].
///
/// Covers:
/// - build() fetches wallet from repository on initialization.
/// - build() exposes AsyncData with correct wallet on success.
/// - build() exposes AsyncError when repository throws.
/// - refresh() re-fetches and updates state.
/// - refresh() transitions to AsyncLoading then AsyncData.
/// - refresh() transitions to AsyncError on repository failure.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

const _testUserId = '45a54f25-47c6-4730-8b21-78ea1df36bea';

class _MockCreditsRepository extends Mock implements CreditsRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _wallet100 = CreditWallet(balance: 100, freePeriod: 'trial');
const _wallet0 = CreditWallet.zero;

/// SharedPreferences instance backing every container in this file. The
/// controller uses it to remember that a user's monthly grant was already
/// requested, so it must be a real (mock-backed) instance, not a stub.
late SharedPreferences _prefs;

ProviderContainer _container(_MockCreditsRepository repo) {
  final c = ProviderContainer(
    overrides: [
      creditsRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCreditsRepository repo;

  setUpAll(() => registerFallbackValue((CreditWallet _) {}));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    repo = _MockCreditsRepository();
    when(() => repo.currentUserId).thenReturn(_testUserId);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    // The controller now provisions before reading. Default to "provisioning
    // unavailable" so every existing test still exercises the fetchWallet path
    // it was written for; the provisioning tests stub this explicitly.
    when(() => repo.ensureWallet()).thenAnswer((_) async => null);
    // The controller now opens a realtime wallet subscription on build; unit
    // tests have no socket, so "not signed in / unavailable" (null) is right.
    when(() => repo.subscribeToWallet(any())).thenReturn(null);
  });

  // -------------------------------------------------------------------------
  // build()
  // -------------------------------------------------------------------------

  group('CreditsController.build — provisioning', () {
    test(
      'a first-run user gets the provisioned balance, not a bare zero',
      () async {
        // No wallet row exists yet, so a plain read would report zero and the
        // UI would tell a brand-new user they are out of tokens.
        when(() => repo.ensureWallet()).thenAnswer((_) async => 20);
        when(
          () => repo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);

        final container = _container(repo);

        final wallet = await container.read(creditsControllerProvider.future);

        expect(wallet.balance, 20);
        verifyNever(() => repo.fetchWallet());
      },
    );

    test('the provisioning call is made at most once per user per month, '
        'however many times the provider is rebuilt', () async {
      when(() => repo.ensureWallet()).thenAnswer((_) async => 20);
      when(
        () => repo.fetchWallet(),
      ).thenAnswer((_) async => const CreditWallet(balance: 20));

      final container = _container(repo);

      await container.read(creditsControllerProvider.future);
      // Simulate the pill remounting / a post-purchase invalidate.
      for (var i = 0; i < 4; i++) {
        container.invalidate(creditsControllerProvider);
        await container.read(creditsControllerProvider.future);
      }

      // The edge function is a round trip whose answer is fixed for the
      // calendar month; rebuilds must fall through to the cheap read.
      verify(() => repo.ensureWallet()).called(1);
    });

    test('a different user on the same device still gets provisioned', () async {
      when(() => repo.ensureWallet()).thenAnswer((_) async => 20);
      when(
        () => repo.fetchWallet(),
      ).thenAnswer((_) async => const CreditWallet(balance: 20));

      final container = _container(repo);
      await container.read(creditsControllerProvider.future);

      // Someone else signs in — the marker is keyed by user id, so it must not
      // suppress their grant.
      when(() => repo.currentUserId).thenReturn('a-different-user-id');
      container.invalidate(creditsControllerProvider);
      await container.read(creditsControllerProvider.future);

      verify(() => repo.ensureWallet()).called(2);
    });

    test(
      'falls back to a plain read when provisioning is unavailable',
      () async {
        when(() => repo.ensureWallet()).thenAnswer((_) async => null);
        when(
          () => repo.fetchWallet(),
        ).thenAnswer((_) async => const CreditWallet(balance: 7));

        final container = _container(repo);

        final wallet = await container.read(creditsControllerProvider.future);

        expect(wallet.balance, 7);
      },
    );
  });

  group('CreditsController.build — initial load', () {
    test('exposes AsyncData with wallet returned by repository', () async {
      when(() => repo.fetchWallet()).thenAnswer((_) async => _wallet100);

      final container = _container(repo);
      final wallet = await container.read(creditsControllerProvider.future);

      expect(wallet.balance, 100);
      expect(wallet.freePeriod, 'trial');
    });

    test('calls fetchWallet exactly once on build', () async {
      when(() => repo.fetchWallet()).thenAnswer((_) async => _wallet0);

      final container = _container(repo);
      await container.read(creditsControllerProvider.future);

      verify(() => repo.fetchWallet()).called(1);
    });

    test(
      'a throwing repository degrades to zero rather than erroring',
      () async {
        when(() => repo.fetchWallet()).thenThrow(Exception('network error'));

        final container = _container(repo);
        final wallet = await container.read(creditsControllerProvider.future);

        expect(wallet.balance, 0);
        expect(
          container.read(creditsControllerProvider),
          isA<AsyncData<CreditWallet>>(),
          reason:
              'build() must never throw. Under keepAlive an erroring initial '
              'build leaves `.future` permanently uncompleted, and '
              'PurchaseController awaits that future while polling for the '
              'post-purchase balance — so a throwing build hangs a purchase '
              'instead of failing it.',
        );
      },
    );

    test(
      'state is AsyncData (not AsyncLoading) after build resolves',
      () async {
        when(() => repo.fetchWallet()).thenAnswer((_) async => _wallet100);

        final container = _container(repo);
        await container.read(creditsControllerProvider.future);

        final state = container.read(creditsControllerProvider);
        expect(state, isA<AsyncData<CreditWallet>>());
      },
    );

    test('zero-balance wallet is surfaced correctly', () async {
      when(() => repo.fetchWallet()).thenAnswer((_) async => CreditWallet.zero);

      final container = _container(repo);
      final wallet = await container.read(creditsControllerProvider.future);

      expect(wallet.balance, 0);
      expect(wallet.freePeriod, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // refresh()
  // -------------------------------------------------------------------------

  group('CreditsController.refresh — re-fetch', () {
    test('refresh calls fetchWallet a second time', () async {
      when(() => repo.fetchWallet()).thenAnswer((_) async => _wallet0);

      final container = _container(repo);
      await container.read(creditsControllerProvider.future);

      await container.read(creditsControllerProvider.notifier).refresh();

      // Called once for build() + once for refresh().
      verify(() => repo.fetchWallet()).called(2);
    });

    test(
      'refresh updates state with new wallet value from repository',
      () async {
        var callCount = 0;
        when(() => repo.fetchWallet()).thenAnswer((_) async {
          callCount++;
          return callCount == 1
              ? const CreditWallet(balance: 10)
              : const CreditWallet(balance: 110);
        });

        final container = _container(repo);
        await container.read(creditsControllerProvider.future);

        // Wallet before refresh.
        expect(container.read(creditsControllerProvider).value!.balance, 10);

        await container.read(creditsControllerProvider.notifier).refresh();

        // Wallet after refresh must reflect updated balance.
        expect(
          container.read(creditsControllerProvider).value!.balance,
          110,
          reason:
              'refresh() must update state with the freshest wallet balance.',
        );
      },
    );

    test('a failing background refresh keeps the last good balance '
        '(stale beats broken)', () async {
      var callCount = 0;
      when(() => repo.fetchWallet()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return _wallet100;
        throw Exception('server down');
      });

      final container = _container(repo);
      await container.read(creditsControllerProvider.future);

      await container.read(creditsControllerProvider.notifier).refresh();

      final state = container.read(creditsControllerProvider);
      expect(
        state.value?.balance,
        100,
        reason:
            'refresh() runs on every app foreground; a transient network '
            'error there must not replace a real balance with an error '
            'state. Stale beats broken.',
      );
    });

    test(
      'refresh keeps the previous balance visible while in flight',
      () async {
        final completer = Completer<CreditWallet>();
        var callCount = 0;
        when(() => repo.fetchWallet()).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return _wallet100;
          return completer.future;
        });

        final container = _container(repo);
        await container.read(creditsControllerProvider.future);

        // Kick off refresh without awaiting.
        final refreshFuture = container
            .read(creditsControllerProvider.notifier)
            .refresh();

        await Future<void>.microtask(() {});

        // No loading flash: refresh runs on app foreground, and blanking the
        // pill each time reads as the balance vanishing.
        final stateWhileLoading = container.read(creditsControllerProvider);
        expect(
          stateWhileLoading.value?.balance,
          100,
          reason:
              'The old balance must stay visible while refresh is in flight.',
        );

        // Resolve.
        completer.complete(const CreditWallet(balance: 50));
        await refreshFuture;

        final stateAfter = container.read(creditsControllerProvider);
        expect(stateAfter.value?.balance, 50);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------

  group('CreditsController — edge cases', () {
    test('freePeriod="trial" wallet is surfaced correctly', () async {
      when(() => repo.fetchWallet()).thenAnswer(
        (_) async => const CreditWallet(balance: 0, freePeriod: 'trial'),
      );

      final container = _container(repo);
      final wallet = await container.read(creditsControllerProvider.future);

      expect(wallet.balance, 0);
      expect(
        wallet.freePeriod,
        'trial',
        reason:
            'Free-trial users may have 0 balance but a non-null freePeriod.',
      );
    });

    test('large credit balance is preserved exactly', () async {
      when(
        () => repo.fetchWallet(),
      ).thenAnswer((_) async => const CreditWallet(balance: 999999));

      final container = _container(repo);
      final wallet = await container.read(creditsControllerProvider.future);

      expect(wallet.balance, 999999);
    });

    test('multiple refreshes in sequence each update state', () async {
      var balance = 0;
      when(() => repo.fetchWallet()).thenAnswer((_) async {
        balance += 50;
        return CreditWallet(balance: balance);
      });

      final container = _container(repo);
      await container.read(creditsControllerProvider.future); // build → 50

      await container
          .read(creditsControllerProvider.notifier)
          .refresh(); // refresh → 100
      expect(container.read(creditsControllerProvider).value?.balance, 100);

      await container
          .read(creditsControllerProvider.notifier)
          .refresh(); // refresh → 150
      expect(container.read(creditsControllerProvider).value?.balance, 150);
    });
  });

  group(
    'auth-change rebuild (ops 2026-08-21-cookie-balance-stale-on-auth-change)',
    () {
      // Stream emission → provider update → async controller rebuild is a
      // multi-hop async chain; poll briefly instead of trusting one microtask.
      Future<int> balanceWhen(
        ProviderContainer container,
        bool Function(int) done,
      ) async {
        for (var i = 0; i < 40; i++) {
          final w = await container.read(creditsControllerProvider.future);
          if (done(w.balance)) return w.balance;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        return (await container.read(creditsControllerProvider.future)).balance;
      }

      test(
        'a session APPEARING rebuilds the controller: zero before, granted after',
        () async {
          final authStream = StreamController<String?>.broadcast();
          addTearDown(authStream.close);
          when(
            () => repo.authUserIdChanges,
          ).thenAnswer((_) => authStream.stream);

          // Phase 1: no session — the new-user-first-run state.
          when(() => repo.currentUserId).thenReturn(null);
          when(() => repo.hasAuthenticatedUser).thenReturn(false);
          when(
            () => repo.fetchWallet(),
          ).thenAnswer((_) async => CreditWallet.zero);

          final container = _container(repo);
          addTearDown(container.dispose);
          final sub = container.listen(creditsControllerProvider, (_, __) {});
          addTearDown(sub.close);

          var wallet = await container.read(creditsControllerProvider.future);
          expect(wallet.balance, 0);
          verifyNever(() => repo.ensureWallet());

          // Phase 2: the anonymous sign-in completes (end of onboarding).
          when(() => repo.currentUserId).thenReturn('anon-1');
          when(() => repo.hasAuthenticatedUser).thenReturn(true);
          when(() => repo.ensureWallet()).thenAnswer((_) async => 50);
          authStream.add('anon-1');

          final granted = await balanceWhen(container, (b) => b == 50);
          expect(
            granted,
            50,
            reason: 'the grant must show WITHOUT a restart or a purchase',
          );
          verify(() => repo.ensureWallet()).called(1);
        },
      );

      test(
        'log out → log in as another user re-ensures for the new identity',
        () async {
          final authStream = StreamController<String?>.broadcast();
          addTearDown(authStream.close);
          when(
            () => repo.authUserIdChanges,
          ).thenAnswer((_) => authStream.stream);
          when(() => repo.currentUserId).thenReturn('user-a');
          when(() => repo.hasAuthenticatedUser).thenReturn(true);
          when(() => repo.ensureWallet()).thenAnswer((_) async => 50);
          when(
            () => repo.fetchWallet(),
          ).thenAnswer((_) async => const CreditWallet(balance: 50));

          final container = _container(repo);
          addTearDown(container.dispose);
          final sub = container.listen(creditsControllerProvider, (_, __) {});
          addTearDown(sub.close);
          await container.read(creditsControllerProvider.future);
          verify(() => repo.ensureWallet()).called(1);

          // Log out, then in as user-b: the pill must not keep user-a's number.
          // fetchWallet is user-scoped on the server, so once the identity flips
          // it answers with user-b's wallet — the stub must flip with it (the
          // second rebuild takes the stamped fetchWallet path).
          when(() => repo.currentUserId).thenReturn('user-b');
          when(() => repo.ensureWallet()).thenAnswer((_) async => 12);
          when(
            () => repo.fetchWallet(),
          ).thenAnswer((_) async => const CreditWallet(balance: 12));
          authStream.add(null);
          authStream.add('user-b');

          final switched = await balanceWhen(container, (b) => b == 12);
          expect(
            switched,
            12,
            reason: "user-b's wallet, not user-a's stale pill",
          );
        },
      );
    },
  );
}
