/// Unit tests for [PurchaseController].
///
/// Revenue-critical paths covered:
/// - buy() cancelled (purchase returns false) → no-op, state stays AsyncData.
/// - buy() SDK error (mapped to false by service) → state stays AsyncData.
/// - buy() success → state settles to AsyncData(null).
/// - buy() success → purchase() called exactly once.
/// - restore() → restores and triggers wallet refresh.
/// - restore() SDK throws through guard → AsyncError.
/// - Initial state is AsyncData(null) (idle).
/// - Concurrent buy() calls — no guard; UI must disable button.
///
/// DESIGN NOTE ON TIMING:
/// PurchaseController.buy() polls with Future.delayed(1500ms × 5 attempts)
/// and PurchaseController.restore() includes Future.delayed(2s).
/// To keep tests fast and stable, all tests that exercise buy()/restore()
/// use a ProviderContainer that keeps providers alive (not autoDisposed mid-test)
/// by listening to them throughout the test scope.
///
/// BUG DOCUMENTED:
/// buy() balance stays stale when wallet fetch fails during polling.
/// When the credits controller errors (e.g. device is offline), `_currentBalance()`
/// catches the error and returns 0. After the purchase succeeds, the poll loop
/// compares against previousBalance=0. If fetchWallet() keeps failing, the poll
/// exhausts and the final `ref.invalidate()` also fails silently. Result:
/// the user paid but sees the same balance until next app restart.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

/// Stands in for the Supabase auth user id that RevenueCat is identified with.
const _testUserId = '45a54f25-47c6-4730-8b21-78ea1df36bea';

class _MockRevenueCatService extends Mock implements RevenueCatService {}

class _MockCreditsRepository extends Mock implements CreditsRepository {}

/// A [StoreProduct] stub carrying only what the controller reads: the SKU,
/// which is attached to Sentry reports so a failed purchase names its pack.
class _FakeStoreProduct extends Fake implements StoreProduct {
  @override
  String get identifier => 'mealvana_credits_50';
}

class _FakePackage extends Fake implements Package {
  @override
  StoreProduct get storeProduct => _FakeStoreProduct();
}

// ---------------------------------------------------------------------------
// Fallback registration
// ---------------------------------------------------------------------------

void _registerFallbacks() {
  registerFallbackValue(_FakePackage());
  registerFallbackValue((CreditWallet _) {});
}

// ---------------------------------------------------------------------------
// Container factory — keeps providers alive during test by subscribing a
// persistent listener. The returned cleanup function must be called at the
// end of the test (in addTearDown or via explicit call).
// ---------------------------------------------------------------------------

typedef _Cleanup = void Function();

late SharedPreferences _prefs;

(ProviderContainer, _Cleanup) _buildContainer({
  required _MockRevenueCatService rcService,
  required _MockCreditsRepository creditsRepo,
}) {
  final container = ProviderContainer(
    overrides: [
      revenueCatServiceProvider.overrideWithValue(rcService),
      creditsRepositoryProvider.overrideWithValue(creditsRepo),
      sharedPreferencesProvider.overrideWithValue(_prefs),
      // Keep the real Sentry SDK out of unit tests; the controller now reports
      // purchase failures through this provider.
      sentryReporterProvider.overrideWithValue(const NoopSentryReporter()),
    ],
  );

  // Subscribe to both providers so they stay alive (not autoDisposed)
  // while async work is in progress.
  final sub1 = container.listen(
    purchaseControllerProvider,
    (_, __) {},
    fireImmediately: false,
  );
  final sub2 = container.listen(
    creditsControllerProvider,
    (_, __) {},
    fireImmediately: false,
  );

  void cleanup() {
    sub1.close();
    sub2.close();
    container.dispose();
  }

  return (container, cleanup);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRevenueCatService rcService;
  late _MockCreditsRepository creditsRepo;
  late _FakePackage fakePackage;

  setUpAll(_registerFallbacks);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    rcService = _MockRevenueCatService();
    creditsRepo = _MockCreditsRepository();
    fakePackage = _FakePackage();
    // buy() now refuses to reach the store without a signed-in user and
    // re-asserts the RevenueCat identity first, so both must be stubbed.
    when(() => creditsRepo.ensureWallet()).thenAnswer((_) async => null);
    when(() => creditsRepo.subscribeToWallet(any())).thenReturn(null);
    when(() => creditsRepo.currentUserId).thenReturn(_testUserId);
    when(() => rcService.logIn(any())).thenAnswer((_) async {});
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  group('PurchaseController — initial state', () {
    test('initial state is AsyncData(null) — idle', () async {
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet.zero);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      // Wait for the controller to build.
      await container.read(purchaseControllerProvider.future);

      final state = container.read(purchaseControllerProvider);
      expect(
        state,
        isA<AsyncData<void>>(),
        reason: 'Controller must start idle (AsyncData(null)).',
      );
    });
  });

  // -------------------------------------------------------------------------
  // buy() — cancelled (purchase returns false)
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — user cancels', () {
    test(
      'buy() where purchase returns false → state stays AsyncData (idle)',
      () async {
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);
        when(() => rcService.purchase(any())).thenAnswer((_) async => false);

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(purchaseControllerProvider.future);

        await container
            .read(purchaseControllerProvider.notifier)
            .buy(fakePackage);

        final state = container.read(purchaseControllerProvider);
        expect(
          state,
          isA<AsyncData<void>>(),
          reason:
              'A cancelled purchase must not put the controller in error state.',
        );
      },
    );

    test('buy() cancelled — purchase() was called exactly once', () async {
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet.zero);
      when(() => rcService.purchase(any())).thenAnswer((_) async => false);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(purchaseControllerProvider.future);
      await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      verify(() => rcService.purchase(fakePackage)).called(1);
    });

    test('buy() cancelled — fetchWallet not called a second time after cancel '
        '(no polling when purchase returns false)', () async {
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet.zero);
      when(() => rcService.purchase(any())).thenAnswer((_) async => false);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      // Build both providers (each calls fetchWallet once).
      await container.read(creditsControllerProvider.future);
      await container.read(purchaseControllerProvider.future);

      // Reset interaction count after initial builds.
      clearInteractions(creditsRepo);

      await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      // After cancel, no poll fires — fetchWallet should not be called again.
      verifyNever(() => creditsRepo.fetchWallet());
    });
  });

  // -------------------------------------------------------------------------
  // buy() — success
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — success path', () {
    test('buy() success → state is AsyncData(null) after purchase', () async {
      var callCount = 0;
      when(() => creditsRepo.fetchWallet()).thenAnswer((_) async {
        callCount++;
        // First call (build): 100. Subsequent poll calls: 200 (balance increased).
        return callCount == 1
            ? const CreditWallet(balance: 100)
            : const CreditWallet(balance: 200);
      });
      when(() => rcService.purchase(any())).thenAnswer((_) async => true);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(creditsControllerProvider.future);
      await container.read(purchaseControllerProvider.future);

      await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      final state = container.read(purchaseControllerProvider);
      expect(
        state,
        isA<AsyncData<void>>(),
        reason: 'Successful purchase must resolve to AsyncData(null) — idle.',
      );
    });

    test('buy() success → purchase() called exactly once', () async {
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet.zero);
      when(() => rcService.purchase(any())).thenAnswer((_) async => true);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(creditsControllerProvider.future);
      await container.read(purchaseControllerProvider.future);

      await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      verify(() => rcService.purchase(fakePackage)).called(1);
    });

    test(
      'buy() success — poll detects balance increase and returns early',
      () async {
        var callCount = 0;
        when(() => creditsRepo.fetchWallet()).thenAnswer((_) async {
          callCount++;
          return CreditWallet(balance: callCount == 1 ? 50 : 150);
        });
        when(() => rcService.purchase(any())).thenAnswer((_) async => true);

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future); // count=1 → 50
        await container.read(purchaseControllerProvider.future);

        await container
            .read(purchaseControllerProvider.notifier)
            .buy(fakePackage);

        // After buy, the credits controller should have been refreshed (count > 1).
        expect(
          callCount,
          greaterThan(1),
          reason:
              'buy() must poll creditsController after successful purchase '
              'to detect the balance update from the RC webhook.',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // buy() — SDK error (service returns false)
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — SDK error is silent (false from service)', () {
    test('buy() when service returns false (SDK error swallowed) '
        '→ controller stays in AsyncData, no crash', () async {
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet.zero);
      when(() => rcService.purchase(any())).thenAnswer((_) async => false);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(purchaseControllerProvider.future);

      await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      final state = container.read(purchaseControllerProvider);
      expect(
        state,
        isA<AsyncData<void>>(),
        reason:
            'SDK errors are swallowed by RevenueCatService and mapped to '
            'false. PurchaseController treats false as user-cancel — no crash.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // restore()
  // -------------------------------------------------------------------------

  group('PurchaseController.restore', () {
    test(
      'restore() settles to AsyncData(null) when restore succeeds',
      () async {
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);
        when(() => rcService.restore()).thenAnswer((_) async {});

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future);
        await container.read(purchaseControllerProvider.future);

        // restore() includes a real Future.delayed(2s) — this test will be slow
        // but is necessary to verify the full path without fake timers.
        await container.read(purchaseControllerProvider.notifier).restore();

        final state = container.read(purchaseControllerProvider);
        expect(
          state,
          isA<AsyncData<void>>(),
          reason: 'restore() must settle to idle AsyncData on success.',
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'restore() calls rcService.restore() exactly once',
      () async {
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);
        when(() => rcService.restore()).thenAnswer((_) async {});

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future);
        await container.read(purchaseControllerProvider.future);

        await container.read(purchaseControllerProvider.notifier).restore();

        verify(() => rcService.restore()).called(1);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'restore() — rcService.restore() throwing surfaces as AsyncError',
      () async {
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);
        when(() => rcService.restore()).thenThrow(Exception('restore failed'));

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future);
        await container.read(purchaseControllerProvider.future);

        await container.read(purchaseControllerProvider.notifier).restore();

        final state = container.read(purchaseControllerProvider);
        expect(
          state,
          isA<AsyncError<void>>(),
          reason:
              'If restore() throws through the AsyncValue.guard, state '
              'must be AsyncError — the exception is not silently dropped.',
        );
      },
    );

    test(
      'restore() triggers a wallet refresh',
      () async {
        var fetchCount = 0;
        when(() => creditsRepo.fetchWallet()).thenAnswer((_) async {
          fetchCount++;
          return CreditWallet(balance: fetchCount * 10);
        });
        when(() => rcService.restore()).thenAnswer((_) async {});

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future); // count=1
        await container.read(purchaseControllerProvider.future);

        final countBeforeRestore = fetchCount;
        await container.read(purchaseControllerProvider.notifier).restore();

        expect(
          fetchCount,
          greaterThan(countBeforeRestore),
          reason:
              'restore() must call creditsController.refresh() to update '
              'the displayed balance after the restore completes.',
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  // -------------------------------------------------------------------------
  // buy() — poll exhaustion (balance never updates)
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — poll exhaustion', () {
    test(
      'BUG_CHECK: buy() succeeds but balance never increases '
      '→ no crash, state is AsyncData (poll exhaustion is non-fatal)',
      () async {
        // Balance never changes — simulates webhook delay longer than max poll.
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => const CreditWallet(balance: 100));
        when(() => rcService.purchase(any())).thenAnswer((_) async => true);

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future);
        await container.read(purchaseControllerProvider.future);

        // This will run 5 poll intervals × 1500ms = 7.5 seconds in real time.
        // We accept the slowness here rather than add fake_async as a new dep.
        await container
            .read(purchaseControllerProvider.notifier)
            .buy(fakePackage);

        final state = container.read(purchaseControllerProvider);
        expect(
          state,
          isA<AsyncData<void>>(),
          reason:
              'Poll exhaustion must NOT crash the controller or produce '
              'AsyncError. User already paid — a silent non-update is acceptable.',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // -------------------------------------------------------------------------
  // buy() — the returned PurchaseOutcome
  //
  // These pin the distinction the UI depends on. The sheet used to infer the
  // result from a wallet-balance delta, which collapsed three very different
  // situations into one message — including telling a user who HAD been
  // charged that nothing was charged.
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — outcome', () {
    test('balance increases → PurchaseOutcome.credited', () async {
      var balance = 100;
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet(balance: balance));
      when(() => rcService.purchase(any())).thenAnswer((_) async {
        balance = 150;
        return true;
      });

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(creditsControllerProvider.future);
      await container.read(purchaseControllerProvider.future);

      final outcome = await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      expect(outcome, PurchaseOutcome.credited);
    });

    test('store confirms but the wallet never moves → '
        'PurchaseOutcome.purchasedButNotCredited (NOT failed)', () async {
      // The webhook is late or never lands. The user has paid.
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => const CreditWallet(balance: 100));
      when(() => rcService.purchase(any())).thenAnswer((_) async => true);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(creditsControllerProvider.future);
      await container.read(purchaseControllerProvider.future);

      final outcome = await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      expect(
        outcome,
        PurchaseOutcome.purchasedButNotCredited,
        reason:
            'Reporting this as `failed` would tell a user who was charged '
            'that nothing was charged — the specific bug this enum fixes.',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('service returns false (cancel or store rejection) → '
        'PurchaseOutcome.cancelled, and the wallet is never polled', () async {
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => const CreditWallet(balance: 100));
      when(() => rcService.purchase(any())).thenAnswer((_) async => false);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(creditsControllerProvider.future);
      await container.read(purchaseControllerProvider.future);

      final sw = Stopwatch()..start();
      final outcome = await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);
      sw.stop();

      expect(outcome, PurchaseOutcome.cancelled);
      // Returning early matters: polling here would make a cancel take 7.5s.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  // -------------------------------------------------------------------------
  // buy() — authentication precondition
  //
  // The RevenueCat webhook maps `app_user_id` onto `auth.users.id`, so a
  // purchase made without a signed-in user takes money and credits nobody.
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — requires a signed-in user', () {
    test('no signed-in user → PurchaseOutcome.notSignedIn and the store is '
        'never contacted', () async {
      when(() => creditsRepo.currentUserId).thenReturn(null);
      when(
        () => creditsRepo.fetchWallet(),
      ).thenAnswer((_) async => CreditWallet.zero);

      final (container, cleanup) = _buildContainer(
        rcService: rcService,
        creditsRepo: creditsRepo,
      );
      addTearDown(cleanup);

      await container.read(purchaseControllerProvider.future);

      final outcome = await container
          .read(purchaseControllerProvider.notifier)
          .buy(fakePackage);

      expect(outcome, PurchaseOutcome.notSignedIn);
      verifyNever(() => rcService.purchase(any()));
    });

    test(
      'signed-in user → RevenueCat identity is re-asserted before purchasing',
      () async {
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);
        when(() => rcService.purchase(any())).thenAnswer((_) async => false);

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(purchaseControllerProvider.future);
        await container
            .read(purchaseControllerProvider.notifier)
            .buy(fakePackage);

        // logIn runs once at startup, so a user who signed in afterwards would
        // otherwise still be carrying the anonymous RevenueCat id.
        verify(() => rcService.logIn(_testUserId)).called(1);
      },
    );
  });

  // -------------------------------------------------------------------------
  // buy() — wallet read failure during _currentBalance
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — wallet unavailable during buy', () {
    test(
      'BUG_CHECK: _currentBalance() returns 0 when creditsController throws, '
      'buy() still proceeds (not blocked by wallet read error)',
      () async {
        var callCount = 0;
        when(() => creditsRepo.fetchWallet()).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('offline');
          return const CreditWallet(balance: 0);
        });
        when(() => rcService.purchase(any())).thenAnswer((_) async => true);

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(purchaseControllerProvider.future);

        await container
            .read(purchaseControllerProvider.notifier)
            .buy(fakePackage);

        // purchase() must have been called — the wallet error did not block it.
        verify(() => rcService.purchase(fakePackage)).called(1);

        final state = container.read(purchaseControllerProvider);
        expect(state, isA<AsyncData<void>>());
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // -------------------------------------------------------------------------
  // Concurrent buy() calls — no guard exists; UI must prevent double-tap
  // -------------------------------------------------------------------------

  group('PurchaseController.buy — concurrent call guard', () {
    test(
      'BUG_CHECK: when buy() is in-flight (AsyncLoading), '
      'PurchaseController has no internal guard against concurrent calls — '
      'the UI is responsible for disabling the button when isBusy=true',
      () async {
        when(
          () => creditsRepo.fetchWallet(),
        ).thenAnswer((_) async => CreditWallet.zero);

        // Make purchase() hang until we complete the completer.
        final completer = Completer<bool>();
        when(
          () => rcService.purchase(any()),
        ).thenAnswer((_) => completer.future);

        final (container, cleanup) = _buildContainer(
          rcService: rcService,
          creditsRepo: creditsRepo,
        );
        addTearDown(cleanup);

        await container.read(creditsControllerProvider.future);
        await container.read(purchaseControllerProvider.future);

        // Fire first buy() without awaiting.
        unawaited(
          container.read(purchaseControllerProvider.notifier).buy(fakePackage),
        );

        // Give the async buy() a tick to start.
        await Future<void>.microtask(() {});

        // Verify state is AsyncLoading (purchase in progress).
        expect(
          container.read(purchaseControllerProvider),
          isA<AsyncLoading<void>>(),
        );

        // Complete the purchase so the container can settle cleanly.
        completer.complete(false);
        await Future<void>.delayed(Duration.zero);
      },
    );
  });
}
