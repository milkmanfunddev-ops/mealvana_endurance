// Seam: the per-flavor Sentry table (spec: `.scratch/sentry/spec.md`
// § Bootstrap). Pure data, no SDK: each flavor's DSN source, environment,
// trace rate, replay rate and debug flag, and the rule that a missing DSN
// disables Sentry instead of falling back to the prod project.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/core/bootstrap/sentry_flavor_settings.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

void main() {
  AppConfig config({
    String dsn = 'https://k@o1.ingest.sentry.io/1',
    String appEnvironment = 'prod',
  }) => AppConfig.forTesting(
    sentryDsn: dsn,
    sentryEnvironment: 'development',
    appEnvironment: appEnvironment,
    devModeEnabled: appEnvironment == 'dev',
  );

  group('SentryFlavorSettings.resolve', () {
    test('dev samples every trace, never records replay, logs SDK debug', () {
      final s = SentryFlavorSettings.resolve(
        AppFlavor.dev,
        config: config(),
        replayOnErrorCohortRate: 1.0,
      );
      expect(s.tracesSampleRate, 1.0);
      expect(s.replaySessionSampleRate, 0.0);
      expect(s.replayOnErrorSampleRate, 0.0);
      expect(s.debug, isTrue);
      expect(s.environment, 'development');
      expect(s.isEnabled, isTrue);
    });

    test('prod samples a tenth of traces and arms replay for the cohort', () {
      final s = SentryFlavorSettings.resolve(
        AppFlavor.prod,
        config: config(),
        replayOnErrorCohortRate: 1.0,
        debugBuild: false,
      );
      expect(s.tracesSampleRate, 0.1);
      expect(s.replaySessionSampleRate, 0.0);
      expect(s.replayOnErrorSampleRate, 1.0);
      expect(s.debug, isFalse);
    });

    test('prod outside the cohort never records replay', () {
      final s = SentryFlavorSettings.resolve(
        AppFlavor.prod,
        config: config(),
        replayOnErrorCohortRate: 0.0,
        debugBuild: false,
      );
      expect(s.replayOnErrorSampleRate, 0.0);
    });

    test('a debug build of prod never records replay, cohort or not', () {
      final s = SentryFlavorSettings.resolve(
        AppFlavor.prod,
        config: config(),
        replayOnErrorCohortRate: 1.0,
        debugBuild: true,
      );
      expect(s.replayOnErrorSampleRate, 0.0);
    });

    test('web prod samples a tenth of traces, replay off (unsupported)', () {
      final s = SentryFlavorSettings.resolve(
        AppFlavor.web,
        config: config(appEnvironment: 'prod'),
        replayOnErrorCohortRate: 1.0,
      );
      expect(s.tracesSampleRate, 0.1);
      expect(s.replayOnErrorSampleRate, 0.0);
      expect(s.debug, isFalse);
    });

    test('web dev samples every trace, replay still off', () {
      final s = SentryFlavorSettings.resolve(
        AppFlavor.web,
        config: config(appEnvironment: 'dev'),
        replayOnErrorCohortRate: 1.0,
      );
      expect(s.tracesSampleRate, 1.0);
      expect(s.replayOnErrorSampleRate, 0.0);
    });

    test('a missing DSN disables Sentry rather than reporting anywhere', () {
      for (final flavor in AppFlavor.values) {
        final s = SentryFlavorSettings.resolve(
          flavor,
          config: config(dsn: ''),
          replayOnErrorCohortRate: 1.0,
        );
        expect(s.isEnabled, isFalse, reason: flavor.name);
        expect(s.dsn, isEmpty, reason: flavor.name);
      }
    });

    test('shorebird_patch tag reads "none" with no patch', () {
      expect(shorebirdPatchTag(null), 'none');
      expect(shorebirdPatchTag(7), '7');
    });
  });
}
