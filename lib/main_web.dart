import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/services/app_config.dart';
import 'shared/services/app_external_deps.dart';
import 'shared/services/sentry/sentry_provider_observer.dart';
import 'shared/widgets/root_app_widget.dart';

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

    // Initialize Sentry
    await SentryFlutter.init(
      (options) {
        options.dsn = config.sentryDsn;
        options.environment = config.sentryEnvironment;

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
        options.replay.onErrorSampleRate = kDebugMode ? 0.0 : 1.0;

        options.attachStacktrace = true;
        options.sendDefaultPii = false;
        options.maxBreadcrumbs = 100;

        options.beforeSend = (event, hint) {
          if (!kDebugMode && (event.level == SentryLevel.debug || event.level == SentryLevel.info)) {
            return null;
          }
          if (event.throwable.toString().contains('TimeoutException')) {
            return null;
          }
          return event;
        };

        options.navigatorKey = sentryNavigatorKey;
        options.attachScreenshot = true;
      },
    );

    await _runMealvanaApp(config);
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

Future<void> _runMealvanaApp(AppConfig config) async {
  // Initialize Supabase with SentryHttpClient to instrument network calls.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    httpClient: SentryHttpClient(),
  );

  // Initialize SharedPreferences (non-recoverable, required for app startup)
  final sharedPreferences = await SharedPreferences.getInstance();
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
