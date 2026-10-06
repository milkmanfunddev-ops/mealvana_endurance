/// The per-flavor Sentry table (spec: `.scratch/sentry/spec.md` § Bootstrap).
///
/// Pure data so a test can read the whole table without the SDK. The
/// bootstrap turns one row into `SentryFlutterOptions`.
///
/// | Flavor | DSN source          | Traces | Replay on error      | SDK debug |
/// |--------|---------------------|--------|----------------------|-----------|
/// | dev    | `.env.dev.local`    | 1.0    | 0 (never)            | on        |
/// | prod   | `.env.prod.local`   | 0.1    | per-install cohort   | off       |
/// | web    | `--dart-define`     | 1.0 dev / 0.1 prod | 0 (unsupported) | off  |
///
/// Session replay (recording every session) is 0 everywhere. A missing DSN
/// disables Sentry for that run; there is no fallback DSN anywhere, so dev
/// noise can never land in the prod project.
library;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../services/app_config.dart';

/// Which entry point booted the app.
enum AppFlavor { dev, prod, web }

/// The `shorebird_patch` tag value: the patch number, or `none` for the base
/// build (and on web, where Shorebird does not run).
String shorebirdPatchTag(int? patchNumber) =>
    patchNumber == null ? 'none' : '$patchNumber';

class SentryFlavorSettings {
  const SentryFlavorSettings({
    required this.dsn,
    required this.environment,
    required this.tracesSampleRate,
    required this.replaySessionSampleRate,
    required this.replayOnErrorSampleRate,
    required this.debug,
  });

  final String dsn;
  final String environment;
  final double tracesSampleRate;
  final double replaySessionSampleRate;
  final double replayOnErrorSampleRate;
  final bool debug;

  /// False when the DSN is empty: the SDK is not initialised at all.
  bool get isEnabled => dsn.trim().isNotEmpty;

  /// [replayOnErrorCohortRate] is the per-install cohort roll
  /// (`sentry_replay_sampling.dart`), already gated on consent. It only
  /// applies to prod release builds; a debug build of any flavor never
  /// records (the codec logs drown the console).
  static SentryFlavorSettings resolve(
    AppFlavor flavor, {
    required AppConfig config,
    required double replayOnErrorCohortRate,
    bool debugBuild = kDebugMode,
  }) {
    final dsn = config.sentryDsn.trim();
    final environment = config.sentryEnvironment;
    switch (flavor) {
      case AppFlavor.dev:
        return SentryFlavorSettings(
          dsn: dsn,
          environment: environment,
          tracesSampleRate: 1.0,
          replaySessionSampleRate: 0.0,
          replayOnErrorSampleRate: 0.0,
          debug: true,
        );
      case AppFlavor.prod:
        return SentryFlavorSettings(
          dsn: dsn,
          environment: environment,
          tracesSampleRate: 0.1,
          replaySessionSampleRate: 0.0,
          replayOnErrorSampleRate: debugBuild ? 0.0 : replayOnErrorCohortRate,
          debug: false,
        );
      case AppFlavor.web:
        // One web entry point serves both environments; APP_ENVIRONMENT
        // picks the row.
        return SentryFlavorSettings(
          dsn: dsn,
          environment: environment,
          tracesSampleRate: config.isDevelopment ? 1.0 : 0.1,
          replaySessionSampleRate: 0.0,
          replayOnErrorSampleRate: 0.0,
          debug: false,
        );
    }
  }
}
