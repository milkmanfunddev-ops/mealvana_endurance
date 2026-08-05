/// The RevenueCat **Test Store** key must never reach a paying customer.
///
/// `AppConfig.revenueCatApiKey` prefers `revenueCatApiKeyTest` (a `test_…`
/// key) over the real store key so the purchase → webhook → wallet path can be
/// exercised on a simulator. Purchases against the Test Store complete
/// instantly and free, so if that key were ever selected in a production build
/// the app would hand out AI credits for nothing.
///
/// The guard is `isDevelopment && kDebugMode`. The `kDebugMode` half was added
/// in 6804d5b6 after a real launch crash: RevenueCat forbids Test Store keys in
/// release binaries and enforces it at runtime, so a Codemagic dev build (a
/// *release* build shipped to TestFlight) handed a `test_` key raised a native
/// "wrong API key" alert and terminated. The dev *flavor* is not the same thing
/// as a debug *build*.
///
/// That second condition also all but closes the hole this suite originally
/// documented. `isDevelopment` is `appEnvironment == 'dev' || devModeEnabled`
/// — note the **or** — so a build shipped with `APP_ENVIRONMENT=prod` AND
/// `DEV_MODE_ENABLED=true` still satisfies the first half. It can now only
/// reach the Test Store in a debug build, which never ships.
///
/// These tests run under `flutter test`, where `kDebugMode` is true, so they
/// exercise the `isDevelopment` half directly. The release-build half is
/// asserted separately below against the compile-time constant.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

void main() {
  const testKey = 'test_abc123';
  const appleKey = 'appl_realkey';
  const googleKey = 'goog_realkey';

  AppConfig config({
    required String appEnvironment,
    required bool devModeEnabled,
    String testStoreKey = testKey,
  }) => AppConfig.forTesting(
    appEnvironment: appEnvironment,
    devModeEnabled: devModeEnabled,
    revenueCatApiKeyApple: appleKey,
    revenueCatApiKeyGoogle: googleKey,
    revenueCatApiKeyTest: testStoreKey,
    aiCreditsEnabled: true,
  );

  // revenueCatApiKey consults defaultTargetPlatform for the real-store branch.
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('a real production build', () {
    final prod = () => config(appEnvironment: 'prod', devModeEnabled: false);

    test('is not development', () {
      expect(prod().isDevelopment, isFalse);
      expect(prod().isProduction, isTrue);
    });

    test('ignores a stray Test Store key entirely', () {
      expect(prod().revenueCatApiKey, appleKey);
      expect(prod().revenueCatApiKey, isNot(startsWith('test_')));
    });

    test('does not report itself as talking to the Test Store', () {
      expect(prod().revenueCatApiKey.startsWith('test_'), isFalse);
    });
  });

  group('a dev build', () {
    final dev = () => config(appEnvironment: 'dev', devModeEnabled: true);

    test('prefers the Test Store key when one is set', () {
      expect(dev().revenueCatApiKey, testKey);
    });

    test('falls back to the real platform key when no test key is set', () {
      final noTestKey = config(
        appEnvironment: 'dev',
        devModeEnabled: true,
        testStoreKey: '',
      );
      expect(noTestKey.revenueCatApiKey, appleKey);
    });

    test('the Test Store key is platform-agnostic', () {
      // The Test Store is not a native store, so the same key applies on
      // Android — the platform branch must not run at all when it is selected.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(dev().revenueCatApiKey, testKey);
    });
  });

  group('the mixed case: prod environment with devModeEnabled', () {
    final prodWithDevMode = () =>
        config(appEnvironment: 'prod', devModeEnabled: true);

    test('counts as development, because isDevelopment is an OR', () {
      expect(prodWithDevMode().isDevelopment, isTrue);
    });

    test('is NOT reported as production', () {
      // isProduction requires `!devModeEnabled`, so this build is neither a
      // clean prod build nor a clean dev one.
      expect(prodWithDevMode().isProduction, isFalse);
    });

    test('satisfies the isDevelopment half of the gate', () {
      // A build shipped with APP_ENVIRONMENT=prod and DEV_MODE_ENABLED=true
      // still clears `isDevelopment`, because that getter is an OR. Under
      // `flutter test` kDebugMode is true, so the test key wins here.
      //
      // What stops this reaching a customer is the kDebugMode half (6804d5b6):
      // the binaries that actually ship are release builds. Pinned so that
      // tightening the first half to `appEnvironment == 'dev'` flips this
      // expectation and says so out loud.
      expect(prodWithDevMode().revenueCatApiKey, testKey);
    });
  });

  group('the kDebugMode half of the gate', () {
    test('a release build can never select a Test Store key', () {
      // Not reachable from a unit test — kDebugMode is a compile-time constant
      // and is true under `flutter test`. Assert the constant instead, so this
      // test states the precondition the suite above relies on rather than
      // pretending to cover the release path.
      expect(
        kDebugMode,
        isTrue,
        reason:
            'These tests assume a debug test binary. If this ever runs in '
            'release mode, every dev-flavor expectation below changes: the '
            'gate falls through to the platform key.',
      );

      // The invariant that matters in a shipped binary, stated explicitly:
      // release + any environment => the platform key, never `test_`.
      // Enforced by revenueCatApiKey's `kDebugMode` conjunct.
    });
  });

  group('the guard cannot be bypassed by an empty key', () {
    test('an empty test key never wins, in any environment', () {
      for (final env in ['dev', 'prod']) {
        for (final devMode in [true, false]) {
          final c = config(
            appEnvironment: env,
            devModeEnabled: devMode,
            testStoreKey: '',
          );
          expect(
            c.revenueCatApiKey,
            appleKey,
            reason: 'env=$env devMode=$devMode should fall through to Apple.',
          );
        }
      }
    });
  });

  group('unsupported platforms', () {
    test('web gets no key at all in a prod build', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final prod = config(appEnvironment: 'prod', devModeEnabled: false);
      expect(prod.revenueCatApiKey, isEmpty);
    });
  });
}
