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

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockCreditsRepository extends Mock implements CreditsRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _wallet100 = CreditWallet(balance: 100, freePeriod: 'trial');
const _wallet0 = CreditWallet.zero;

ProviderContainer _container(_MockCreditsRepository repo) {
  final c = ProviderContainer(
    overrides: [creditsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCreditsRepository repo;

  setUp(() {
    repo = _MockCreditsRepository();
  });

  // -------------------------------------------------------------------------
  // build()
  // -------------------------------------------------------------------------

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

    test('exposes AsyncError when repository throws on build', () async {
      when(() => repo.fetchWallet()).thenThrow(Exception('network error'));

      final container = _container(repo);
      // Await the future and expect it to throw.
      final threw = await container
          .read(creditsControllerProvider.future)
          .then((_) => false)
          .catchError((_) => true);

      expect(
        threw,
        isTrue,
        reason: 'build() must propagate repository exceptions as AsyncError.',
      );
    });

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

    test(
      'refresh exposes AsyncError when repository throws on re-fetch',
      () async {
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
          state,
          isA<AsyncError<CreditWallet>>(),
          reason: 'refresh() must surface repository errors as AsyncError.',
        );
      },
    );

    test('refresh sets AsyncLoading before resolving', () async {
      final completer = Completer<CreditWallet>();
      var callCount = 0;
      when(() => repo.fetchWallet()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return _wallet0;
        return completer.future;
      });

      final container = _container(repo);
      await container.read(creditsControllerProvider.future);

      // Kick off refresh without awaiting.
      final refreshFuture = container
          .read(creditsControllerProvider.notifier)
          .refresh();

      // Give the event loop a tick to transition to loading.
      await Future<void>.microtask(() {});

      final stateWhileLoading = container.read(creditsControllerProvider);
      expect(
        stateWhileLoading,
        isA<AsyncLoading<CreditWallet>>(),
        reason: 'State must be AsyncLoading while refresh is in progress.',
      );

      // Resolve.
      completer.complete(const CreditWallet(balance: 50));
      await refreshFuture;

      final stateAfter = container.read(creditsControllerProvider);
      expect(stateAfter.value?.balance, 50);
    });
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
}
