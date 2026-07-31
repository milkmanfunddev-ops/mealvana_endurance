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

  group('AppConfig.fromEnv — prod stays OFF', () {
    test('the AI flags fall back to off when the flavor is not dev', () {
      dotenv.testLoad(fileInput: 'APP_ENVIRONMENT=prod\n');

      final config = AppConfig.fromEnv();
      expect(config.aiCreditsEnabled, isFalse);
      expect(config.describeMealEnabled, isFalse);
      expect(config.coachInsightsEnabled, isFalse);
    });
  });
}
