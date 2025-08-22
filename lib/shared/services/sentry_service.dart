import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry service following Andrea Bizzotto's FOA patterns
/// Centralizes all Sentry operations and error reporting
/// 
/// Usage:
/// - initializeSentry(): Initialize Sentry with proper configuration
/// - reportCriticalError(): For errors that should always be tracked
/// - reportEdgeFunctionError(): For Supabase Edge Function failures
/// - reportDatabaseError(): For Drift database operation failures
/// - setUserContext(): Set user identification without PII
/// - addBreadcrumb(): Add debugging breadcrumbs
/// - startTransaction(): Start performance monitoring
class SentryService {
  SentryService();

  /// Initialize Sentry with proper configuration
  /// Should be called from main() before the app starts
  static Future<void> initializeSentry({
    required VoidCallback appRunner,
    String? customDsn,
    String? customEnvironment,
    String? customRelease,
  }) async {
    await SentryFlutter.init(
      (options) {
        // DSN configuration
        options.dsn = customDsn ?? 
          const String.fromEnvironment(
            'SENTRY_DSN',
            defaultValue: 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
          );
        
        // Environment-based configuration
        options.environment = customEnvironment ?? 
          const String.fromEnvironment(
            'SENTRY_ENVIRONMENT',
            defaultValue: kDebugMode ? 'development' : 'production',
          );
        
        // Release tracking for Shorebird patches
        options.release = customRelease ?? 
          const String.fromEnvironment(
            'SENTRY_RELEASE',
            defaultValue: 'mealvana-endurance@1.1.0+8',
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
        // Will be re-enabled once Sentry releases a fix for the profiler crash
        if (kDebugMode) {
          // Disabled in development due to profiler crash
          options.replay.sessionSampleRate = 0.0;
          options.replay.onErrorSampleRate = 0.0;
        } else {
          // Low sample rate in production (can be enabled safely)
          options.replay.sessionSampleRate = 0.05; // 5% of sessions
          options.replay.onErrorSampleRate = 0.5;   // 50% of error sessions
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
      appRunner: appRunner,
    );
  }

  /// Report critical errors (always sent, regardless of sample rate)
  /// Use for: App crashes, authentication failures, data corruption
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = SentryLevel.error;
        scope.setTag('severity', 'critical');
        if (context != null) scope.setTag('context', context);
        if (tags != null) {
          tags.forEach((key, value) => scope.setTag(key, value));
        }
      },
    );
  }

  /// Report Edge Function errors with performance context
  /// Use for: Supabase Edge Function failures (create-nutrition-plan, create-user, etc.)
  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'edge_function');
        scope.setTag('function_name', functionName);
        scope.level = SentryLevel.error;
        
        // Add performance context
        if (responseTime != null) {
          scope.setTag('response_time_ms', responseTime.inMilliseconds.toString());
        }
        if (statusCode != null) {
          scope.setTag('status_code', statusCode.toString());
        }
      },
    );
  }

  /// Report database errors with Drift context
  /// Use for: Database operation failures, migration errors, query issues
  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'database');
        scope.setTag('operation', operation ?? 'unknown');
        scope.setTag('table', table ?? 'unknown');
        scope.level = SentryLevel.error;
      },
    );
  }

  /// Report network/HTTP errors with request context
  /// Use for: HTTP request failures, API timeouts, connectivity issues
  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'network');
        scope.level = SentryLevel.warning; // Network errors often less critical
        
        if (url != null) scope.setTag('url', url);
        if (method != null) scope.setTag('method', method);
        if (statusCode != null) scope.setTag('status_code', statusCode.toString());
        if (timeout != null) scope.setTag('timeout_ms', timeout.inMilliseconds.toString());
      },
    );
  }

  /// Set user context without PII
  /// Use during app startup after getting device ID
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: deviceId, // Device ID, not email or name
        data: {
          if (appVersion != null) 'app_version': appVersion,
          if (onboardingCompleted != null) 
            'onboarding_completed': onboardingCompleted.toString(),
          if (gutTrainingLevel != null) 'gut_training': gutTrainingLevel,
        },
      ));
    });
  }

  /// Add breadcrumb for debugging flow
  /// Use for: Tracking user actions, app state changes, important events
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      level: level,
      data: data,
    ));
  }

  /// Start performance transaction
  /// Use for: Monitoring slow operations, Edge Function calls, database queries
  ISentrySpan startTransaction(String operation, String description) {
    return Sentry.startTransaction(operation, description, bindToScope: true);
  }

  /// Add performance span to existing transaction
  /// Use within transactions to track sub-operations
  ISentrySpan? startSpan(String operation, {String? description}) {
    final transaction = Sentry.getSpan();
    if (transaction != null) {
      return transaction.startChild(operation, description: description);
    }
    return null;
  }

  /// Report performance metric as breadcrumb
  /// Use for: Custom timing metrics, success rates, business metrics
  void reportMetric({
    required String name,
    required double value,
    String? unit,
    Map<String, String>? tags,
  }) {
    addBreadcrumb(
      message: 'Metric: $name = $value${unit ?? ''}',
      category: 'metric',
      level: SentryLevel.info,
      data: {
        'metric_name': name,
        'metric_value': value,
        'metric_unit': unit ?? 'count',
        if (tags != null) ...tags,
      },
    );
  }

  /// Capture a simple message for debugging
  /// Use for: Important app events, state changes, debugging info
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (tags != null) {
          tags.forEach((key, value) => scope.setTag(key, value));
        }
      },
    );
  }

  /// Check if Sentry is enabled and configured
  bool get isEnabled => Sentry.isEnabled;

  /// Track app startup completion
  Future<void> trackAppStartupCompleted() async {
    addBreadcrumb(
      message: 'App startup completed successfully',
      category: 'app_lifecycle',
      data: {
        'startup_time': DateTime.now().toIso8601String(),
        'sentry_enabled': isEnabled.toString(),
      },
    );
    
    await captureMessage(
      'App startup completed',
      level: SentryLevel.info,
      tags: {
        'lifecycle': 'startup_complete',
        'app_phase': 'ready',
      },
    );
  }

  /// Clear user context (e.g., on logout)
  Future<void> clearUserContext() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

}

/// Provider for SentryService
/// Use: ref.read(sentryServiceProvider)
final sentryServiceProvider = Provider<SentryService>((ref) {
  return SentryService();
});