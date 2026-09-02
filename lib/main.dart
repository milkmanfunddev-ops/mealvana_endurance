import 'dart:async';
import 'package:flutter/material.dart';
import 'features/content/application/content_service.dart' show ContentDefaultsCache;
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
import 'shared/services/sentry/sentry_replay_sampling.dart';
import 'shared/services/sentry/sentry_provider_observer.dart';
import 'shared/widgets/root_app_widget.dart';
import 'shared/services/privacy/analytics_consent.dart';

/// Default entry point (Production fallback)
///
/// IMPORTANT: This file is a fallback and should NOT be used directly.
/// Instead, use flavor-specific entry points:
/// - Development: lib/main_dev.dart (loads .env.dev.local)
/// - Production: lib/main_prod.dart (loads .env.prod.local)
///
/// Run commands:
/// - Dev: flutter run --flavor dev -t lib/main_dev.dart
/// - Prod: flutter run --flavor prod -t lib/main_prod.dart
///
/// This file defaults to production environment for safety.

/// Global navigator key for Sentry feedback widget screenshot capture
/// This key is used by SentryFeedbackWidget to navigate and capture screenshots
final GlobalKey<NavigatorState> sentryNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  runZonedGuarded(
    () async {
      // Initialize widgets binding for Sentry frame tracking BEFORE Sentry init
      SentryWidgetsFlutterBinding.ensureInitialized();

      // Load production environment variables by default
      // NOTE: Use main_dev.dart or main_prod.dart with flavors for environment-specific builds
      await dotenv.load(fileName: '.env.prod.local');

      // Create app configuration from loaded env
      final config = AppConfig.fromEnv();

      // Fetch package info before Sentry init so release/dist are available.
      final packageInfo = await PackageInfo.fromPlatform();
      final sentryRelease =
          'mealvana_endurance@${packageInfo.version}+${packageInfo.buildNumber}';
      final sentryDist = packageInfo.buildNumber;

      // Consent must be resolved BEFORE Sentry is configured: session replay is
      // armed at init and cannot be disarmed for the rest of the session.
      final sharedPreferences = await SharedPreferences.getInstance();
      final analyticsConsented = analyticsConsentGrantedFromPrefs(
        sharedPreferences,
      );

      // Resolved before init because the options callback below is synchronous,
      // and because the cohort roll has to be persisted exactly once per install.
      final replayOnErrorSampleRate = await resolveReplayOnErrorSampleRate(
        sharedPreferences,
        analyticsConsented: analyticsConsented,
      );

      // Initialize Sentry with configuration from .env
      await SentryFlutter.init((options) {
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
          options.profilesSampleRate =
              0.0; // Disable profiling in debug mode due to crash
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
        options.replay.sessionSampleRate =
            0.0; // Don't capture regular sessions
        // Armed for a persisted ~10% cohort, not everyone: a non-zero rate runs
        // the native recorder CONTINUOUSLY for the whole session, which was
        // cooking testers' phones (measured 2026-07-16: ~1.9x idle CPU, and a
        // CADisplayLink -> takeScreenshot() stack on a completely idle app).
        // An armed install behaves exactly as before
        // (every error ships its 30s video); an unarmed one never starts the
        // recorder. 0.1 here would be the worst of both worlds — full battery
        // cost, 90% of replays discarded. Debug stays off outright (200+ lines
        // of codec logs). Full reasoning: sentry_replay_sampling.dart.
        options.replay.onErrorSampleRate = kDebugMode
            ? kReplayOff
            : replayOnErrorSampleRate;

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
          // Device diagnostics (MetricKit hangs/CPU exceptions) are captured at
          // info level by design and must not be swept up by this drop.
          if (!kDebugMode &&
              !isDiagnosticEvent(event) &&
              (event.level == SentryLevel.debug ||
                  event.level == SentryLevel.info)) {
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
      });

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
    },
    (exception, stackTrace) async {
      // Capture any uncaught exceptions
      await Sentry.captureException(exception, stackTrace: stackTrace);
    },
  );
}

/// App runner function called after Sentry initialization
Future<void> _runMealvanaApp(
  AppConfig config,
  SharedPreferences sharedPreferences,
) async {
  // Initialize Supabase with SentryHttpClient to instrument network calls.
  // SentryHttpClient wraps the Dart http.Client to capture failed requests and
  // add tracing breadcrumbs — replaces the sentry_supabase package which has
  // no 9.6.x release compatible with this project's sentry_flutter version.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseClientKey,
    httpClient: SentryHttpClient(),
  );

  // Entry point following Andrea Bizzotto's pattern with runZonedGuarded pattern
  // Widget hierarchy:
  // 1. SentryWidget - Wraps app to enable screenshot capture and session replay
  // 2. ProviderScope - Riverpod state management
  // 3. RootAppWidget - MaterialApp.router with Wiredash and AppStartupWidget
  // Bundled content defaults must be in memory before the first frame —
  // widgets that read a content key in their one synchronous build never
  // re-render on their own (CLAUDE.md: non-recoverable bootstrap lives in main).
  await ContentDefaultsCache.preload();

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
