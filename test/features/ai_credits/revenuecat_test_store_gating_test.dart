/// The RevenueCat **Test Store** key must never reach a paying customer.
///
/// `AppConfig.revenueCatApiKey` prefers `revenueCatApiKeyTest` (a `test_…`
/// key) over the real store key so the purchase → webhook → wallet path can be
/// exercised on a simulator. Purchases against the Test Store complete
/// instantly and free, so if that key were ever selected in a production build
/// the app would hand out AI credits for nothing.
///
/// The guard is `isDevelopment`, which is
/// `appEnvironment == 'dev' || devModeEnabled` — note the **or**. These tests
/// pin the real shape of that gate, including the mixed case (a prod
/// environment that still ships `devModeEnabled: true`), which is the one
/// combination where a stray key is still honoured.
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

    test('still honours the Test Store key — the one hole in the gate', () {
      // This is the documented-but-real gap: the comment on
      // revenueCatApiKey says a prod build ignores the test key "even if the
      // var is set", but the guard is isDevelopment, not !isProduction. A
      // build shipped with APP_ENVIRONMENT=prod and DEV_MODE_ENABLED=true
      // routes purchases at the fake store.
      //
      // Pinned deliberately: if the gate is ever tightened to
      // `appEnvironment == 'dev'`, this expectation flips and the test tells
      // you the behaviour changed on purpose.
      expect(prodWithDevMode().revenueCatApiKey, testKey);
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
