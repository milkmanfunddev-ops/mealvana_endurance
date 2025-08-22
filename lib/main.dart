import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/widgets/root_app_widget.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    // Initialize Sentry with our configuration
    await SentryFlutter.init(
      (options) {
        // DSN configuration
        options.dsn = const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue: 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
        );
        
        // Environment-based configuration
        options.environment = const String.fromEnvironment(
          'SENTRY_ENVIRONMENT',
          defaultValue: kDebugMode ? 'development' : 'production',
        );
        
        // Performance monitoring (environment-based)
        // NOTE: Profiling disabled in debug mode due to iOS crash
        if (kDebugMode) {
          options.tracesSampleRate = 1.0; // 100% in development
          options.profilesSampleRate = 0.0; // Disable profiling in debug mode due to crash
          options.debug = true;
        } else {
          options.tracesSampleRate = 0.1; // 10% in production
          options.profilesSampleRate = 0.1; // 10% profiling in production  
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

    await _runMealvanaApp();
  }, (exception, stackTrace) async {
    // Capture any uncaught exceptions
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

/// App runner function called after Sentry initialization
Future<void> _runMealvanaApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (non-recoverable initialization)
  await Supabase.initialize(
    url: 'https://wvmvsodrvbkxfydabqed.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk',
  );
  
  // Entry point following Andrea Bizzotto's pattern with runZonedGuarded pattern
  runApp(
    ProviderScope(
      child: RootAppWidget(),
    ),
  );
}

