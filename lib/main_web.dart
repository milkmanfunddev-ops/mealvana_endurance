import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/services/app_config.dart';
import 'shared/services/app_external_deps.dart';
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
    final mainStopwatch = Stopwatch()..start();

    // Initialize widgets binding for Sentry frame tracking
    SentryWidgetsFlutterBinding.ensureInitialized();
    debugPrint('[STARTUP] Widget binding initialized: ${mainStopwatch.elapsedMilliseconds}ms');

    // Debug: Print dart defines to verify they're being passed
    debugPrint('[STARTUP] Checking dart defines...');
    debugPrint('[STARTUP] SUPABASE_URL: ${const String.fromEnvironment('SUPABASE_URL', defaultValue: 'NOT SET')}');
    debugPrint('[STARTUP] APP_ENVIRONMENT: ${const String.fromEnvironment('APP_ENVIRONMENT', defaultValue: 'NOT SET')}');

    // Create app configuration from dart defines (web-safe)
    late final AppConfig config;
    try {
      config = AppConfig.fromDartDefines();
      debugPrint('[STARTUP] AppConfig created (web): ${mainStopwatch.elapsedMilliseconds}ms');
    } catch (e, st) {
      debugPrint('[STARTUP] ERROR creating AppConfig: $e');
      debugPrint('[STARTUP] Stack trace: $st');
      rethrow;
    }

    // Initialize Sentry
    debugPrint('[STARTUP] Starting Sentry init...');
    await SentryFlutter.init(
      (options) {
        options.dsn = config.sentryDsn;
        options.environment = config.sentryEnvironment;

        if (config.enableDebugLogging) {
          options.tracesSampleRate = 1.0;
          options.profilesSampleRate = 0.0;
          options.debug = true;
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

    debugPrint('[STARTUP] Sentry init completed: ${mainStopwatch.elapsedMilliseconds}ms');

    debugPrint('[STARTUP] Starting Supabase and runApp...');
    await _runMealvanaApp(config, mainStopwatch);
  }, (exception, stackTrace) async {
    debugPrint('[STARTUP] UNCAUGHT ERROR: $exception');
    debugPrint('[STARTUP] Stack trace: $stackTrace');
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

Future<void> _runMealvanaApp(AppConfig config, Stopwatch mainStopwatch) async {
  debugPrint('[STARTUP] Starting Supabase.initialize...');
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );
  debugPrint('[STARTUP] Supabase.initialize completed: ${mainStopwatch.elapsedMilliseconds}ms');

  // Initialize SharedPreferences (non-recoverable, required for app startup)
  debugPrint('[STARTUP] Starting SharedPreferences.getInstance...');
  final sharedPreferences = await SharedPreferences.getInstance();
  debugPrint('[STARTUP] SharedPreferences initialized: ${mainStopwatch.elapsedMilliseconds}ms');

  debugPrint('[STARTUP] Calling runApp...');
  runApp(
    SentryWidget(
      child: ProviderScope(
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
