import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/services/app_config.dart';
import 'shared/services/app_external_deps.dart';
import 'shared/services/sentry/sentry_event_filter.dart';
import 'shared/services/sentry/sentry_provider_observer.dart';
import 'shared/widgets/root_app_widget.dart';
import 'shared/services/privacy/analytics_consent.dart';

/// Global navigator key for Sentry feedback widget screenshot capture
final GlobalKey<NavigatorState> sentryNavigatorKey = GlobalKey<NavigatorState>();

/// Web entry point
/// Uses --dart-define for environment variables (required for web security)
///
/// Build command (development):
/// flutter run -d chrome -t lib/main_web.dart \
///   --dart-define=SUPABASE_URL=your_url \
///   --dart-define=SUPABASE_ANON_KEY=your_key \
///   --dart-define=APP_ENVIRONMENT=dev
///
/// Build command (production via Vercel):
/// flutter build web --release --wasm -t lib/main_web.dart \
///   --dart-define=SUPABASE_URL=$SUPABASE_URL \
///   --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
///   --dart-define=SENTRY_DSN=$SENTRY_DSN \
///   --dart-define=APP_ENVIRONMENT=prod
Future<void> main() async {
  runZonedGuarded(() async {
    // Initialize widgets binding for Sentry frame tracking
    SentryWidgetsFlutterBinding.ensureInitialized();

    // Create app configuration from dart defines (web-safe)
    final config = AppConfig.fromDartDefines();

    // Fetch package info before Sentry init so release/dist are available.
    final packageInfo = await PackageInfo.fromPlatform();
    final sentryRelease =
        'mealvana_endurance@${packageInfo.version}+${packageInfo.buildNumber}';
    final sentryDist = packageInfo.buildNumber;

    // Consent must be resolved BEFORE Sentry is configured: session replay is
    // armed at init and cannot be disarmed for the rest of the session.
    final sharedPreferences = await SharedPreferences.getInstance();
    final analyticsConsented =
        analyticsConsentGrantedFromPrefs(sharedPreferences);

    // Initialize Sentry
    await SentryFlutter.init(
      (options) {
        options.dsn = config.sentryDsn;
        options.environment = config.sentryEnvironment;

        // Release and dist — must match symbols uploaded by sentry_dart_plugin.
        // Format: <app-id>@<version>+<build> e.g. mealvana_endurance@1.20.0+42
        options.release = sentryRelease;
        options.dist = sentryDist;

        if (config.enableDebugLogging) {
          options.tracesSampleRate = 1.0;
          options.profilesSampleRate = 0.0;
          options.debug = true;
          // Suppress Sentry's warning-level diagnostic chatter (notably the
          // per-query "[sentry_drift] Active Sentry transaction does not exist"
          // spam, emitted for every Drift op that runs outside a transaction).
          // Real errors (error/fatal) still print.
          options.diagnosticLevel = SentryLevel.error;
        } else {
          options.tracesSampleRate = 0.1;
          options.profilesSampleRate = 0.0;
          options.debug = false;
        }

        // Session Replay - disabled on web for performance
        options.replay.sessionSampleRate = 0.0;
        // Session replay rides on the SAME consent flag as Mixpanel: a rolling
        // recording of the user's session is non-essential "usage data" under
        // Apple 5.1.1(ii) and under ePrivacy, so it needs consent.
        //
        // Crash + performance reporting are deliberately NOT gated. They are
        // necessary to keep the app working (legitimate interest), run with
        // sendDefaultPii = false, and the SDK masks all text and images by
        // default. Going blind on crashes for users who decline analytics would
        // cost real stability for no privacy gain.
        //
        // Read once, at init: a user who withdraws mid-session stops Mixpanel
        // immediately, but replay stays armed until the next launch.
        options.replay.onErrorSampleRate =
            (kDebugMode || !analyticsConsented) ? 0.0 : 1.0;

        options.attachStacktrace = true;
        options.sendDefaultPii = false;
        options.maxBreadcrumbs = 100;

        options.beforeSend = (event, hint) {
          if (!kDebugMode && (event.level == SentryLevel.debug || event.level == SentryLevel.info)) {
            return null;
          }
          // Drop known low-signal noise (offline/DNS, transient TLS resets,
          // cancelled sign-ins, debug assertions, test-runner failures).
          if (isSentryNoise(event)) {
            return null;
          }
          return event;
        };

        options.navigatorKey = sentryNavigatorKey;
        options.attachScreenshot = true;
      },
    );

    // Explicit uncaught-error handlers — installed AFTER SentryFlutter.init so
    // the SDK is ready to receive events and won't clobber these assignments.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      Sentry.captureException(details.exception, stackTrace: details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      Sentry.captureException(error, stackTrace: stack);
      return true;
    };

    await _runMealvanaApp(config, sharedPreferences);
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

Future<void> _runMealvanaApp(
  AppConfig config,
  SharedPreferences sharedPreferences,
) async {
  // Initialize Supabase with SentryHttpClient to instrument network calls.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseClientKey,
    httpClient: SentryHttpClient(),
  );

  runApp(
    SentryWidget(
      child: ProviderScope(
        observers: const [SentryProviderObserver()],
        overrides: [
          appConfigProvider.overrideWithValue(config),
          // Override sharedPreferencesProvider with initialized instance
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const RootAppWidget(),
      ),
    ),
  );
}
