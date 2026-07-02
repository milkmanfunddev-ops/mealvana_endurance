import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

/// Global navigator key for Sentry feedback widget screenshot capture
/// This key is used by SentryFeedbackWidget to navigate and capture screenshots
final GlobalKey<NavigatorState> sentryNavigatorKey = GlobalKey<NavigatorState>();

/// Development flavor entry point
/// Loads .env.dev.local configuration
Future<void> main() async {
  runZonedGuarded(() async {
    // Initialize widgets binding for Sentry frame tracking BEFORE Sentry init
    SentryWidgetsFlutterBinding.ensureInitialized();

    // Load development environment variables
    await dotenv.load(fileName: '.env.dev.local');

    // Create app configuration from loaded env
    final config = AppConfig.fromEnv();

    // Fetch package info before Sentry init so release/dist are available.
    final packageInfo = await PackageInfo.fromPlatform();
    final sentryRelease =
        'mealvana_endurance@${packageInfo.version}+${packageInfo.buildNumber}';
    final sentryDist = packageInfo.buildNumber;

    // Initialize Sentry with configuration from .env
    await SentryFlutter.init(
      (options) {
        // DSN configuration from AppConfig
        options.dsn = config.sentryDsn;

        // Environment configuration from AppConfig
        options.environment = config.sentryEnvironment;

        // Release and dist — must match symbols uploaded by sentry_dart_plugin.
        // Format: <app-id>@<version>+<build> e.g. mealvana_endurance@1.20.0+42
        options.release = sentryRelease;
        options.dist = sentryDist;

        // Performance monitoring (config-based)
        // NOTE: Profiling disabled in debug mode due to iOS crash
        if (config.enableDebugLogging) {
          options.tracesSampleRate = 1.0; // 100% in development
          options.profilesSampleRate = 0.0; // Disable profiling in debug mode due to crash
          options.debug = true;
          // Suppress Sentry's warning-level diagnostic chatter (notably the
          // per-query "[sentry_drift] Active Sentry transaction does not exist"
          // spam, emitted for every Drift op that runs outside a transaction).
          // Real errors (error/fatal) still print.
          options.diagnosticLevel = SentryLevel.error;
        } else {
          options.tracesSampleRate = 0.1; // 10% in production
          options.profilesSampleRate = config.enableSentryProfiling ? 0.1 : 0.0;
          options.debug = false;
        }

        // Session Replay configuration
        // Captures video-like replay of user sessions for debugging
        // Disabled in debug mode to avoid verbose codec initialization logs
        // Only capture replays when errors occur in production (not regular sessions)
        if (kDebugMode) {
          // Completely disable replay in debug to avoid 200+ lines of codec logs
          options.replay.sessionSampleRate = 0.0;
          options.replay.onErrorSampleRate = 0.0;
        } else {
          options.replay.sessionSampleRate = 0.0;   // Don't capture regular sessions
          options.replay.onErrorSampleRate = 1.0;   // 100% of error sessions get replay
        }

        // Enhanced error tracking
        options.attachStacktrace = true;
        options.sendDefaultPii = false; // Privacy-first approach
        options.maxBreadcrumbs = 100; // Increased for better debugging

        // App-hang detection is only meaningful for release builds on real
        // devices. In debug/simulator the debugger, hot reload and JIT GC
        // pauses routinely trip the 2s threshold (Sentry DEV-53/DEV-4D/DEV-4Y
        // are all simulator GC pauses), so disable it there.
        options.enableAppHangTracking = !kDebugMode;

        // Filter sensitive errors
        options.beforeSend = (event, hint) {
          // Don't send debug/info logs in production
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

        // Enhanced breadcrumb filtering
        options.beforeBreadcrumb = (breadcrumb, hint) {
          // Don't log sensitive navigation paths
          if (breadcrumb?.category == 'navigation' &&
              breadcrumb?.data?['to']?.contains('admin') == true) {
            return null;
          }
          return breadcrumb;
        };

        // Navigator key for Sentry feedback widget screenshot capture
        // Required for SentryFeedbackWidget to capture screenshots from any screen
        options.navigatorKey = sentryNavigatorKey;

        // Enable screenshot capture for feedback
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

    await _runMealvanaApp(config);
  }, (exception, stackTrace) async {
    // Capture any uncaught exceptions
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

/// App runner function called after Sentry initialization
Future<void> _runMealvanaApp(AppConfig config) async {
  // Initialize Supabase with SentryHttpClient to instrument network calls.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseClientKey,
    httpClient: SentryHttpClient(),
  );

  // Initialize SharedPreferences (non-recoverable, required for app startup)
  final sharedPreferences = await SharedPreferences.getInstance();

  // Entry point following Andrea Bizzotto's pattern with runZonedGuarded pattern
  // Widget hierarchy:
  // 1. SentryWidget - Wraps app to enable screenshot capture and session replay
  // 2. ProviderScope - Riverpod state management
  // 3. RootAppWidget - MaterialApp.router with Wiredash and AppStartupWidget
  runApp(
    SentryWidget(
      child: ProviderScope(
        observers: const [SentryProviderObserver()],
        overrides: [
          // Override appConfigProvider with loaded config
          appConfigProvider.overrideWithValue(config),
          // Override sharedPreferencesProvider with initialized instance
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const RootAppWidget(),
      ),
    ),
  );
}
