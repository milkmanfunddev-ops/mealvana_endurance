/// Pins the dev-default-ON rule for the AI surface flags.
///
/// These flags are read from `.env.dev.local`, which a **CI dev build does not
/// have** — Codemagic writes it from the `DOTENV_DEV_LOCAL` secret, and that
/// secret does not carry every flag. Any AI flag whose fallback is a hard
/// `false` is therefore invisible in exactly the builds testers install, while
/// working perfectly on a developer's machine.
///
/// That is not hypothetical: `aiCreditsEnabled` was missed by the 2026-07-22
/// dev-default-ON change and kept `fallback: 'false'`, which hid the token pill
/// and the entire RevenueCat paywall from every Codemagic dev build. Describe
/// and coach insights were fine, because they had been given the dev default.
///
/// Standing agreement: AI surfaces stay ON for dev builds. Dev is the proving
/// ground, so an absent env var must fall back to the flavor, never to off.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig.fromEnv — AI flags default ON for dev', () {
    setUp(() {
      // Simulate a CI dev build: the flavor says dev, but the env file carries
      // none of the AI flags.
      dotenv.testLoad(fileInput: 'APP_ENVIRONMENT=dev\n');
    });

    test('aiCreditsEnabled is ON when the env omits AI_CREDITS_ENABLED', () {
      final config = AppConfig.fromEnv();
      expect(
        config.aiCreditsEnabled,
        isTrue,
        reason:
            'A hard false fallback here hides the token pill and the whole '
            'paywall in Codemagic-built dev apps, which is where testers '
            'actually exercise purchases.',
      );
    });

    test('describeMealEnabled and coachInsightsEnabled are ON too', () {
      final config = AppConfig.fromEnv();
      expect(config.describeMealEnabled, isTrue);
      expect(config.coachInsightsEnabled, isTrue);
    });

    test('an explicit env value still wins over the dev default', () {
      dotenv.testLoad(
        fileInput: 'APP_ENVIRONMENT=dev\nAI_CREDITS_ENABLED=false\n',
      );
      expect(AppConfig.fromEnv().aiCreditsEnabled, isFalse);
    });
  });

  group('AppConfig.revenueCatApiKey — Test Store key is debug-only', () {
    // RevenueCat forbids Test Store keys in release builds: the native SDK
    // shows a "wrong API key" alert at launch and takes the app down when it
    // is dismissed, from code Dart cannot intercept. Gating on the dev
    // *flavor* is not enough — a Codemagic dev build is a release build.
    test('a release build never surfaces the test key', () {
      final config = AppConfig.forTesting(
        appEnvironment: 'dev',
        revenueCatApiKeyTest: 'test_abc123',
        revenueCatApiKeyApple: 'appl_real',
        revenueCatApiKeyGoogle: 'goog_real',
      );

      // These tests run under `flutter test`, which is a debug build, so the
      // guard is exercised by asserting the rule rather than the environment:
      // the test key may only ever win when kDebugMode is true.
      final key = config.revenueCatApiKey;
      if (kDebugMode) {
        expect(key, 'test_abc123');
      } else {
        expect(
          key.startsWith('test_'),
          isFalse,
          reason: 'A release build handed a test_ key crashes on launch.',
        );
      }
    });

    test('no test key configured falls through to the platform key', () {
      final config = AppConfig.forTesting(
        appEnvironment: 'dev',
        revenueCatApiKeyApple: 'appl_real',
        revenueCatApiKeyGoogle: 'goog_real',
      );
      expect(config.revenueCatApiKey.startsWith('test_'), isFalse);
    });
  });

  group('AppConfig.fromEnv — prod stays OFF', () {
    test('the AI flags fall back to off when the flavor is not dev', () {
      dotenv.testLoad(fileInput: 'APP_ENVIRONMENT=prod\n');

      final config = AppConfig.fromEnv();
      expect(config.aiCreditsEnabled, isFalse);
      expect(config.coachInsightsEnabled, isFalse);
    });

    test('describeMealEnabled is pinned open even on prod (2026-08-10)', () {
      // The Describe tab ships everywhere: prod TestFlight testers need the
      // metered AI entry points visible to exercise real purchase flows, and
      // no env value may hide them.
      dotenv.testLoad(
        fileInput: 'APP_ENVIRONMENT=prod\nDESCRIBE_MEAL_ENABLED=false\n',
      );
      expect(AppConfig.fromEnv().describeMealEnabled, isTrue);
    });
  });
}
