import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/services/app_config.dart';
import 'shared/widgets/root_app_widget.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    // Initialize widgets binding for Sentry frame tracking BEFORE Sentry init
    SentryWidgetsFlutterBinding.ensureInitialized();

    // Load environment variables from .env file
    await dotenv.load(fileName: '.env');

    // Create app configuration from .env
    final config = AppConfig.fromEnv();

    // Initialize Sentry with configuration from .env
    await SentryFlutter.init(
      (options) {
        // DSN configuration from AppConfig
        options.dsn = config.sentryDsn;

        // Environment configuration from AppConfig
        options.environment = config.sentryEnvironment;
        
        // Performance monitoring (config-based)
        // NOTE: Profiling disabled in debug mode due to iOS crash
        if (config.enableDebugLogging) {
          options.tracesSampleRate = 1.0; // 100% in development
          options.profilesSampleRate = 0.0; // Disable profiling in debug mode due to crash
          options.debug = true;
        } else {
          options.tracesSampleRate = 0.1; // 10% in production
          options.profilesSampleRate = config.enableSentryProfiling ? 0.1 : 0.0;
          options.debug = false;
        }
        
        // Session Replay configuration
        // NOTE: Temporarily disabled due to iOS crash in development mode
        if (kDebugMode) {
          // Disabled in development due to profiler crash
          options.replay.sessionSampleRate = 0.0;
          options.replay.onErrorSampleRate = 0.0;
        } else {
          // Low sample rate in production (can be enabled safely)
          options.replay.sessionSampleRate = 0; // 5% of sessions
          options.replay.onErrorSampleRate = 1.0;   // 50% of error sessions
        }
        
        // Enhanced error tracking
        options.attachStacktrace = true;
        options.sendDefaultPii = false; // Privacy-first approach
        options.maxBreadcrumbs = 100; // Increased for better debugging
        
        // Filter sensitive errors
        options.beforeSend = (event, hint) {
          // Don't send debug/info logs in production
          if (!kDebugMode && (event.level == SentryLevel.debug || event.level == SentryLevel.info)) {
            return null;
          }
          
          // Filter out network timeouts (common and not actionable)
          if (event.throwable.toString().contains('TimeoutException')) {
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
      },
    );

    await _runMealvanaApp(config);
  }, (exception, stackTrace) async {
    // Capture any uncaught exceptions
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

/// App runner function called after Sentry initialization
Future<void> _runMealvanaApp(AppConfig config) async {
  // Initialize Supabase (non-recoverable initialization) using config
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  // Entry point following Andrea Bizzotto's pattern with runZonedGuarded pattern
  runApp(
    ProviderScope(
      overrides: [
        // Override appConfigProvider with loaded config
        appConfigProvider.overrideWithValue(config),
      ],
      child: RootAppWidget(),
    ),
  );
}
