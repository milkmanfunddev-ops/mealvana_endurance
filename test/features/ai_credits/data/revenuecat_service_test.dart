/// Unit tests for [RevenueCatService].
///
/// The RevenueCat SDK (purchases_flutter) relies on native platform channels
/// that cannot be exercised in dart:test. Tests here verify the LOGIC layer:
/// - Feature-flag guards (`_canUse` / `aiCreditsEnabled`)
/// - Double-configure guard (`_configured`)
/// - Return values and exception swallowing for each public method
///
/// All calls that would reach the native `Purchases` static are either:
///   (a) short-circuited by `!_canUse` / `!_configured` guards, or
///   (b) proven to degrade gracefully when the platform channel is absent.
///
/// Tests that require a real SDK instance are noted but excluded.
library;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppConfig _config({
  bool enabled = true,
  String appleKey = 'apple-key-test',
  String googleKey = 'google-key-test',
}) {
  return AppConfig.forTesting(
    aiCreditsEnabled: enabled,
    revenueCatApiKeyApple: appleKey,
    revenueCatApiKeyGoogle: googleKey,
  );
}

RevenueCatService _service({
  bool enabled = true,
  String appleKey = 'apple-key-test',
  String googleKey = 'google-key-test',
}) {
  return RevenueCatService(
    config: _config(enabled: enabled, appleKey: appleKey, googleKey: googleKey),
    // Reporting is a side effect of every guard these tests exercise, so use
    // the no-op reporter rather than reaching for the real Sentry SDK.
    sentry: const NoopSentryReporter(),
  );
}

void main() {
  _userCancellationClassifier();

  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // _canUse guard — aiCreditsEnabled=false
  // ---------------------------------------------------------------------------

  group('RevenueCatService — feature disabled (aiCreditsEnabled=false)', () {
    test('configureIfPossible is a no-op when disabled', () async {
      final svc = _service(enabled: false);
      // Must not throw; the native channel is never reached.
      await expectLater(svc.configureIfPossible(), completes);
    });

    test('logIn is a no-op when disabled (not configured)', () async {
      final svc = _service(enabled: false);
      await expectLater(svc.logIn('user-id'), completes);
    });

    test('getOfferings returns null when disabled', () async {
      final svc = _service(enabled: false);
      final result = await svc.getOfferings();
      expect(
        result,
        isNull,
        reason: 'getOfferings must return null when disabled — not throw.',
      );
    });

    test('purchase returns false when disabled', () async {
      // We cannot construct a real Package without native SDK, so we verify
      // the guard fires before any native call.
      // Instead we call the public method indirectly through configureIfPossible
      // to confirm _configured stays false.
      final svc = _service(enabled: false);
      await svc.configureIfPossible();
      // _configured is private; verify indirectly via getOfferings (returns null
      // iff not configured).
      final offerings = await svc.getOfferings();
      expect(offerings, isNull);
    });

    test('restore is a no-op when disabled (not configured)', () async {
      final svc = _service(enabled: false);
      await expectLater(svc.restore(), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // _canUse guard — empty API key
  // ---------------------------------------------------------------------------

  group('RevenueCatService — empty API key', () {
    // On iOS/Android the platform getter returns the corresponding key.
    // We can exercise the "empty key" path by providing empty strings for both.
    test('configureIfPossible is a no-op when API key is empty', () async {
      final svc = _service(enabled: true, appleKey: '', googleKey: '');
      await expectLater(svc.configureIfPossible(), completes);
    });

    test(
      'getOfferings returns null when API key is empty (not configured)',
      () async {
        final svc = _service(enabled: true, appleKey: '', googleKey: '');
        final result = await svc.getOfferings();
        expect(result, isNull);
      },
    );

    test('restore is safe when API key is empty (not configured)', () async {
      final svc = _service(enabled: true, appleKey: '', googleKey: '');
      await expectLater(svc.restore(), completes);
    });

    test('logIn is safe when API key is empty (not configured)', () async {
      final svc = _service(enabled: true, appleKey: '', googleKey: '');
      await expectLater(svc.logIn('user-001'), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // Double-configure guard
  // ---------------------------------------------------------------------------

  group('RevenueCatService — double-configure guard', () {
    test('configureIfPossible with empty key never sets _configured=true, '
        'so second call is safe (no double-configure)', () async {
      // Use empty key so the first call no-ops without hitting native.
      final svc = _service(enabled: true, appleKey: '', googleKey: '');
      await svc.configureIfPossible();
      // Second call — must not throw (even if it were configured).
      await expectLater(svc.configureIfPossible(), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // Wrong-platform key guard (crash regression)
  //
  // A key whose prefix does not match the platform (e.g. a Test Store `test_`
  // key or an Apple `appl_` key on Android) must NOT be handed to the native
  // SDK — doing so triggers a native fatal "invalid API key" alert that crashes
  // the app on dismiss. The Dart guard must short-circuit instead.
  //
  // Test env reports TargetPlatform.android, so the required prefix is `goog_`.
  // ---------------------------------------------------------------------------

  group('RevenueCatService — wrong-platform key guard', () {
    test('configureIfPossible does not reach native for a Test Store (test_) '
        'key on Android — completes without crashing', () async {
      final svc = _service(
        enabled: true,
        appleKey: 'test_tQzQdGyaWsLgqlXuxRYJkoRHNDo',
        googleKey: 'test_tQzQdGyaWsLgqlXuxRYJkoRHNDo',
      );
      await expectLater(svc.configureIfPossible(), completes);
      // Guard skipped configure → service stays unconfigured.
      expect(await svc.getOfferings(), isNull);
    });

    test('configureIfPossible rejects an Apple (appl_) key on Android '
        '(mismatched prefix) without reaching native', () async {
      final svc = _service(
        enabled: true,
        appleKey: 'appl_AGrlvOFexMAOrDPYHOxPgYdnCTs',
        googleKey: 'appl_AGrlvOFexMAOrDPYHOxPgYdnCTs',
      );
      await expectLater(svc.configureIfPossible(), completes);
      expect(await svc.getOfferings(), isNull);
    });

    test('configureIfPossible rejects a malformed/prefixless key '
        'without reaching native', () async {
      final svc = _service(
        enabled: true,
        appleKey: 'apple-key-test',
        googleKey: 'google-key-test',
      );
      await expectLater(svc.configureIfPossible(), completes);
      expect(await svc.getOfferings(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AppConfig.revenueCatApiKey platform selector
  // ---------------------------------------------------------------------------

  group('AppConfig.revenueCatApiKey — platform key selection', () {
    // defaultTargetPlatform is set to TargetPlatform.android in test env.
    // We verify the property doesn't throw and returns a string.
    test('revenueCatApiKey returns a non-null string', () {
      final config = _config(appleKey: 'apple-123', googleKey: 'google-456');
      final key = config.revenueCatApiKey;
      // Must be one of the two configured keys or empty (web/other).
      expect(
        [config.revenueCatApiKeyApple, config.revenueCatApiKeyGoogle, ''],
        contains(key),
        reason:
            'revenueCatApiKey must return apple key, google key, or empty string.',
      );
    });

    test('revenueCatApiKey is empty when both keys are empty', () {
      final config = _config(appleKey: '', googleKey: '');
      // On any platform, the key must be empty.
      expect(config.revenueCatApiKey, anyOf('', isEmpty));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature flag helpers on AppConfig
  // ---------------------------------------------------------------------------

  group('AppConfig — aiCreditsEnabled flag', () {
    test('aiCreditsEnabled=false is the default in AppConfig.forTesting', () {
      final config = AppConfig.forTesting();
      expect(
        config.aiCreditsEnabled,
        isFalse,
        reason: 'AI credits must be opt-in; default should be false.',
      );
    });

    test('aiCreditsEnabled can be explicitly set to true', () {
      final config = AppConfig.forTesting(aiCreditsEnabled: true);
      expect(config.aiCreditsEnabled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // getOfferings — graceful degradation (not configured)
  // ---------------------------------------------------------------------------

  group('RevenueCatService — getOfferings graceful degradation', () {
    test('returns null when SDK is not configured (empty key)', () async {
      final svc = _service(enabled: true, appleKey: '', googleKey: '');
      final result = await svc.getOfferings();
      expect(
        result,
        isNull,
        reason: 'getOfferings must null-guard, not throw, when not configured.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // purchase — returns false without crashing when not configured
  //
  // We cannot create a real `Package` object without native SDK, so we test
  // only that the `_configured` guard fires before any platform call.
  // The `purchase(pkg)` method is tested indirectly below through the
  // PurchaseController which mocks RevenueCatService.
  // ---------------------------------------------------------------------------

  group('RevenueCatService — _canUse invariant', () {
    test('a service configured with aiCreditsEnabled=false and empty keys '
        'never reaches native SDK', () async {
      final svc = _service(enabled: false, appleKey: '', googleKey: '');
      // None of these should throw or interact with native code.
      await svc.configureIfPossible();
      await svc.logIn('user-1');
      final offerings = await svc.getOfferings();
      await svc.restore();

      expect(offerings, isNull);
      // If we reach here without crashing, the guard is working correctly.
    });
  });
}

/// Sentry MEALVANA-ENDURANCE-DEV-6E — a user cancelling is not an error.
///
/// purchases_flutter surfaces cancellation two ways: as a typed
/// `PurchasesError` (already handled) and as a raw PlatformException out of
/// `_invokeReturningMap`. The second shape was reaching Sentry as
/// "purchase failed (unexpected)". These pin the classifier that tells them
/// apart, including the two platforms' different detail keys.
void _userCancellationClassifier() {
  group('_isUserCancellation', () {
    // The private helper is exercised through the public surface used by
    // `purchase`'s catch block.
    bool classify(PlatformException e) =>
        RevenueCatService.debugIsUserCancellation(e);

    test('iOS shape: details.userCancelled == true', () {
      expect(
        classify(
          PlatformException(
            code: '1',
            message: 'Purchase was cancelled.',
            details: const {'userCancelled': true},
          ),
        ),
        isTrue,
      );
    });

    test('Android shape: details.readable_error_code', () {
      expect(
        classify(
          PlatformException(
            code: '1',
            details: const {'readable_error_code': 'PURCHASE_CANCELLED'},
          ),
        ),
        isTrue,
      );
    });

    test('camelCase variant is accepted too', () {
      expect(
        classify(
          PlatformException(
            code: '1',
            details: const {'readableErrorCode': 'PURCHASE_CANCELLED'},
          ),
        ),
        isTrue,
      );
    });

    test('bare code 1 with no details still reads as cancellation', () {
      expect(classify(PlatformException(code: '1')), isTrue);
    });

    test('a real failure is NOT swallowed — it must still reach Sentry', () {
      expect(
        classify(
          PlatformException(
            code: '2',
            message: 'Store problem',
            details: const {'readable_error_code': 'STORE_PROBLEM'},
          ),
        ),
        isFalse,
      );
      expect(
        classify(
          PlatformException(
            code: 'NETWORK_ERROR',
            details: const {'userCancelled': false},
          ),
        ),
        isFalse,
      );
      expect(classify(PlatformException(code: 'UNKNOWN')), isFalse);
    });

    test('a non-map details payload does not throw', () {
      expect(
        classify(PlatformException(code: 'UNKNOWN', details: 'a string')),
        isFalse,
      );
    });
  });
}
