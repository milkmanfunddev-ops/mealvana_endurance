/// RevenueCat identity on a cold launch (testing-wave ticket 85, Finding
/// 09-013): `logIn` runs once, and only after `Purchases.configure` has
/// completed.
///
/// The app asks for the identity from two places at startup: the router's
/// gate reads the subscription status the moment the router exists, before
/// the startup flow has configured the SDK, and the startup flow then
/// configures and logs in itself. Before this ticket the early ask was
/// dropped ("logIn skipped: SDK not configured", twice) and only the
/// startup's own call did the work. Now the early ask waits for configure,
/// and the SDK sees one `logIn` for the signed-in account.
///
/// The SDK is a fake behind [RevenueCatSdk]; it records the order of calls
/// and can hold `configure` open so a test controls the interleaving.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _userId = '45a54f25-47c6-4730-8b21-78ea1df36bea';
const _anonymousId = r'$RCAnonymousID:0123456789abcdef';

class _FakeSdk implements RevenueCatSdk {
  final calls = <String>[];
  String appUserId = _anonymousId;

  /// When set, `configure` does not return until it completes.
  Completer<void>? configureGate;

  @override
  Future<void> configure(PurchasesConfiguration configuration) async {
    calls.add('configure');
    final gate = configureGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<String> get appUserID async => appUserId;

  @override
  Future<void> logIn(String appUserID) async {
    calls.add('logIn:$appUserID');
    appUserId = appUserID;
  }

  @override
  Future<bool> get isAnonymous async => appUserId.startsWith(r'$RCAnonymousID');

  @override
  Future<void> logOut() async {
    calls.add('logOut');
    appUserId = _anonymousId;
  }

  @override
  Future<Offerings> getOfferings() => throw UnimplementedError();

  @override
  Future<void> purchase(PurchaseParams params) => throw UnimplementedError();

  @override
  Future<void> restorePurchases() => throw UnimplementedError();
}

RevenueCatService _service(
  _FakeSdk sdk, {
  Duration configureWait = const Duration(milliseconds: 200),
}) {
  return RevenueCatService(
    // The test platform reports Android, so the Google key is the one the
    // platform guard must accept.
    config: AppConfig.forTesting(
      aiCreditsEnabled: true,
      revenueCatApiKeyApple: 'appl_test',
      revenueCatApiKeyGoogle: 'goog_test',
    ),
    sentry: const NoopSentryReporter(),
    sdk: sdk,
    configureWait: configureWait,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSdk sdk;

  setUp(() {
    RevenueCatService.debugResetForTesting();
    sdk = _FakeSdk();
  });

  tearDown(RevenueCatService.debugResetForTesting);

  group('a cold launch with a signed-in account', () {
    test('the gate asks first, the startup flow configures and logs in: '
        'one logIn, after configure', () async {
      final svc = _service(sdk);

      // The router's gate reads the status before startup reaches configure.
      final early = svc.logIn(_userId);
      await Future<void>.delayed(Duration.zero);
      expect(sdk.calls, isEmpty, reason: 'nothing reaches the SDK yet');

      // The startup flow: configure, then logIn for the signed-in user.
      await svc.configureIfPossible();
      await svc.logIn(_userId);
      await early;

      expect(sdk.calls, ['configure', 'logIn:$_userId']);
      expect(RevenueCatService.isConfigured, isTrue);
    });

    test('the early ask is still one logIn when configure is slow', () async {
      final svc = _service(sdk);
      sdk.configureGate = Completer<void>();

      final early = svc.logIn(_userId);
      final configuring = svc.configureIfPossible();
      final startupLogIn = svc.logIn(_userId);
      await Future<void>.delayed(Duration.zero);
      expect(sdk.calls, ['configure'], reason: 'logIn waits for configure');

      sdk.configureGate!.complete();
      await Future.wait([configuring, early, startupLogIn]);

      expect(sdk.calls, ['configure', 'logIn:$_userId']);
    });

    test('two configure calls in flight reach the SDK once', () async {
      final svc = _service(sdk);
      sdk.configureGate = Completer<void>();

      final a = svc.configureIfPossible();
      final b = svc.configureIfPossible();
      sdk.configureGate!.complete();
      await Future.wait([a, b]);

      expect(sdk.calls.where((c) => c == 'configure'), hasLength(1));
    });
  });

  group('logIn after configure', () {
    test('the identity the SDK already holds is not logged in again', () async {
      final svc = _service(sdk);
      await svc.configureIfPossible();
      await svc.logIn(_userId);
      await svc.logIn(_userId); // the purchase path re-asserts identity
      expect(sdk.calls, ['configure', 'logIn:$_userId']);
    });

    test('a different account is logged in', () async {
      final svc = _service(sdk);
      await svc.configureIfPossible();
      await svc.logIn(_userId);
      await svc.logIn('other-user');
      expect(sdk.calls, ['configure', 'logIn:$_userId', 'logIn:other-user']);
    });
  });

  group('no configure ever comes', () {
    test('logIn gives up after the wait and reaches nothing', () async {
      final svc = _service(sdk, configureWait: const Duration(milliseconds: 20));
      await svc.logIn(_userId);
      expect(sdk.calls, isEmpty);
      expect(RevenueCatService.isConfigured, isFalse);
    });

    test('once a configure attempt has settled without configuring, '
        'logIn returns at once', () async {
      final svc = RevenueCatService(
        config: AppConfig.forTesting(
          aiCreditsEnabled: true,
          // Wrong-platform key on Android: the attempt settles, unconfigured.
          revenueCatApiKeyApple: 'appl_test',
          revenueCatApiKeyGoogle: 'appl_wrong',
        ),
        sentry: const NoopSentryReporter(),
        sdk: sdk,
        configureWait: const Duration(seconds: 30),
      );
      await svc.configureIfPossible();
      await svc.logIn(_userId).timeout(const Duration(milliseconds: 100));
      expect(sdk.calls, isEmpty);
    });
  });
}
