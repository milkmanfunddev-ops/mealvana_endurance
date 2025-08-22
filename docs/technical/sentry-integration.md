# Sentry Integration for Mealvana Endurance

## Overview

Sentry is a crash reporting and performance monitoring platform that provides real-time error tracking, detailed stack traces, and performance insights for Flutter applications. It helps identify, reproduce, and fix crashes faster with comprehensive error context.

**Latest Version**: 9.6.0 (Updated 2025-08-21)  
**Official Documentation**: https://docs.sentry.io/platforms/flutter/

## Benefits for Mealvana Endurance

- **Real-time Error Tracking**: Capture full stack traces with context for critical errors
- **User Context**: Track which users experience specific issues without PII
- **Release Tracking**: Monitor error rates across different app versions and Shorebird patches
- **Performance Monitoring**: Track slow operations, Edge Function calls, and database queries
- **Session Replay**: Visual reproduction of user sessions (configurable sampling)
- **Breadcrumbs**: Automatic logging of user actions leading to errors
- **Offline Support**: Queue errors when offline, send when connected
- **Integration with Existing Stack**: Native support for Drift, Supabase, HTTP clients

## Installation

### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  sentry_flutter: ^9.6.0
  
  # Optional integrations (choose based on needs)
  sentry_drift: ^9.6.0     # For Drift database monitoring
  sentry_logging: ^9.6.0   # For capturing logs from logging package
```

### 2. Environment Variables

```yaml
# Add to flutter build commands
--dart-define=SENTRY_DSN=https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328
--dart-define=SENTRY_ENVIRONMENT=production
--dart-define=SENTRY_RELEASE=mealvana-endurance@1.1.0+8
```

### 3. Initialize Sentry (Updated for 9.6.0)

```dart
// lib/main.dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      // DSN from environment variables (secure approach)
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
      );
      
      // Environment-based configuration
      options.environment = const String.fromEnvironment(
        'SENTRY_ENVIRONMENT',
        defaultValue: kDebugMode ? 'development' : 'production',
      );
      
      // Release tracking for Shorebird patches
      options.release = const String.fromEnvironment(
        'SENTRY_RELEASE',
        defaultValue: 'mealvana-endurance@1.1.0+8',
      );
      
      // Performance monitoring (adjust for production)
      if (kDebugMode) {
        options.tracesSampleRate = 1.0; // 100% in development
        options.profilesSampleRate = 1.0; // Performance profiling
        options.debug = true;
      } else {
        options.tracesSampleRate = 0.1; // 10% in production
        options.profilesSampleRate = 0.1; // 10% profiling in production
        options.debug = false;
      }
      
      // Session Replay (NEW in 9.6.0) - Use sparingly to control bandwidth
      options.experimental.replay.sessionSampleRate = kDebugMode ? 1.0 : 0.05; // 5% in production
      options.experimental.replay.onErrorSampleRate = 0.1; // 10% on errors
      
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
        if (breadcrumb.category == 'navigation' && 
            breadcrumb.data?['to']?.contains('admin') == true) {
          return null;
        }
        return breadcrumb;
      };
    },
    appRunner: () => runApp(
      SentryWidget(
        child: MyApp(),
      ),
    ),
  );
}
```

## Integration with Existing Error Handling

### 1. Wrap Async Operations

```dart
// lib/features/auth/application/auth_service.dart
Future<UserProfile?> getCurrentUser() async {
  try {
    final userRepo = await ref.read(userRepositoryProvider.future);
    return userRepo.getCurrentUser();
  } catch (error, stackTrace) {
    // Send to Sentry with context
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('feature', 'auth');
        scope.setTag('operation', 'getCurrentUser');
      },
    );
    return null;
  }
}
```

### 2. Capture Type Cast Errors

```dart
// Safe type casting with Sentry reporting
T? safeCast<T>(dynamic value, String context) {
  try {
    return value as T;
  } catch (error, stackTrace) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('cast_context', context);
        scope.setExtra('value_type', value?.runtimeType.toString());
        scope.setExtra('expected_type', T.toString());
        scope.setExtra('value', value?.toString());
      },
    );
    return null;
  }
}

// Usage in UserProfile.fromJson
onboardingCompleted: safeCast<bool>(
  json['onboarding_completed'], 
  'UserProfile.onboardingCompleted'
) ?? false,
```

### 3. Navigation Tracking

```dart
// lib/shared/widgets/root_app_widget.dart
MaterialApp.router(
  navigatorObservers: [
    SentryNavigatorObserver(),  // Tracks navigation breadcrumbs
  ],
  // ... rest of configuration
)
```

### 4. Drift Integration

```dart
// lib/shared/services/app_startup_service.dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> _initializeDrift() async {
  try {
    // Initialize app database
    final appDatabase = AppDatabase();
    
    // Ensure database is ready with error tracking
    await Sentry.captureMessage('Database initialization started');
    await appDatabase.ensureOpen();
    await Sentry.captureMessage('Database initialization completed');
    
    return appDatabase;
  } catch (error, stackTrace) {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'database');
        scope.setTag('operation', 'initialization');
      },
    );
    rethrow;
  }
}
```

## User Privacy Configuration

```dart
// Identify user without PII
await Sentry.configureScope((scope) {
  scope.setUser(SentryUser(
    id: deviceId,  // Use device ID, not email
    data: {
      'app_version': appVersion,
      'onboarding_completed': user.onboardingCompleted.toString(),
      'gut_training': user.gutTraining.name,
    },
  ));
});
```

## Capturing Specific Error Types

### Type Cast Errors (Current Issue)

```dart
// Enhanced error capture for debugging type cast issues
class TypeCastErrorHandler {
  static Future<void> captureTypeCastError({
    required dynamic value,
    required String expectedType,
    required String fieldName,
    required String className,
    Map<String, dynamic>? additionalContext,
  }) async {
    await Sentry.captureException(
      TypeError(),
      withScope: (scope) {
        scope.setTag('error_type', 'type_cast');
        scope.setTag('class', className);
        scope.setTag('field', fieldName);
        
        scope.setExtra('value', value?.toString() ?? 'null');
        scope.setExtra('value_type', value?.runtimeType.toString() ?? 'null');
        scope.setExtra('expected_type', expectedType);
        
        if (additionalContext != null) {
          additionalContext.forEach((key, value) {
            scope.setExtra(key, value);
          });
        }
        
        // Add breadcrumb for debugging
        scope.addBreadcrumb(Breadcrumb(
          message: 'Type cast failed: $fieldName in $className',
          category: 'type_error',
          level: SentryLevel.error,
          data: {
            'field': fieldName,
            'expected': expectedType,
            'actual': value?.runtimeType.toString() ?? 'null',
          },
        ));
      },
    );
  }
}
```

## Performance Monitoring

```dart
// Track slow operations
final transaction = Sentry.startTransaction(
  'nutrition-plan-generation',
  'task',
);

try {
  final span = transaction.startChild('edge-function-call');
  final result = await createNutritionPlan();
  span.finish();
  
  transaction.finish();
  return result;
} catch (error) {
  transaction.throwable = error;
  transaction.finish(status: SpanStatus.internalError());
  rethrow;
}
```

## Debug vs Production Configuration

```dart
class SentryConfig {
  static Future<void> initialize() async {
    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue: '',
        );
        
        if (kDebugMode) {
          // Development settings
          options.environment = 'development';
          options.tracesSampleRate = 1.0;  // Capture all
          options.debug = true;
          options.diagnosticLevel = SentryLevel.debug;
        } else {
          // Production settings
          options.environment = 'production';
          options.tracesSampleRate = 0.1;  // Sample 10%
          options.debug = false;
          
          // Only capture errors and above in production
          options.beforeSend = (event, hint) {
            if (event.level == SentryLevel.debug || 
                event.level == SentryLevel.info) {
              return null;
            }
            return event;
          };
        }
      },
      appRunner: () => runApp(MyApp()),
    );
  }
}
```

## Implementation Checklist

- [ ] Create Sentry account and project
- [ ] Add sentry_flutter dependency to pubspec.yaml
- [ ] Initialize Sentry in main.dart
- [ ] Add navigation observer to router
- [ ] Wrap critical async operations with try-catch and Sentry reporting
- [ ] Add user context (device ID) without PII
- [ ] Configure release tracking for Shorebird patches
- [ ] Add Sentry monitoring for database operations
- [ ] Test error reporting in development
- [ ] Configure production sample rates
- [ ] Add environment variables for DSN
- [ ] Document error codes and meanings

## Benefits for Current Issues

### Debugging the Bool Type Cast Error

With Sentry integrated, the current error would provide:

1. **Full Stack Trace**: Exact line where the cast fails
2. **Device Context**: iOS/Android version, device model
3. **User Context**: Which users are affected
4. **App Version**: Whether it's specific to certain builds
5. **Breadcrumbs**: User actions leading to the error
6. **Local Variables**: Values being cast (with proper configuration)

### Example Error Report

```
TypeError: type 'Null' is not a subtype of type 'bool' in type cast

Stack Trace:
  UserProfile.fromJson (user_preferences.dart:103)
  UserRepository.getCurrentUser (user_repository.dart:45)
  AuthService.getCurrentUser (auth_service.dart:78)
  OnboardingController.createUserProfile (onboarding_controller.dart:38)
  
Tags:
  - environment: production
  - release: mealvana-endurance@1.1.0+7
  - device: iPhone 14 Pro
  - os: iOS 17.2
  
Extra Context:
  - field: onboarding_completed
  - value: null
  - expected_type: bool
  - user_id: 6EF39511-0321-4081-B47C-33ECECAD5B60
  
Breadcrumbs:
  1. Navigation to /onboarding/user-profile
  2. Form filled with valid data
  3. Continue button pressed
  4. Type cast error occurred
```

## Cost Considerations

- **Free Tier**: 5,000 errors/month
- **Team Plan**: $26/month for 50,000 errors
- **Business Plan**: Custom pricing for higher volumes

For Mealvana Endurance's current user base, the free tier should be sufficient initially.

## Sentry Service (FOA Pattern Implementation)

### Service Architecture

Following Andrea Bizzotto's FOA patterns, create a dedicated Sentry service:

```dart
// lib/shared/services/sentry_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry service following Andrea Bizzotto's FOA patterns
/// Centralizes all Sentry operations and error reporting
class SentryService {
  SentryService();

  /// Report critical errors (always sent, regardless of sample rate)
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setLevel(SentryLevel.error);
        scope.setTag('severity', 'critical');
        if (context != null) scope.setTag('context', context);
        if (extra != null) {
          extra.forEach((key, value) => scope.setExtra(key, value));
        }
      },
    );
  }

  /// Report Edge Function errors with performance context
  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    Map<String, dynamic>? requestData,
  }) async {
    await Sentry.captureException(
      error,
      withScope: (scope) {
        scope.setTag('component', 'edge_function');
        scope.setTag('function_name', functionName);
        scope.setExtra('response_time_ms', responseTime?.inMilliseconds);
        scope.setExtra('status_code', statusCode);
        scope.setExtra('request_data', requestData);
      },
    );
  }

  /// Report database errors with Drift context
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
      },
    );
  }

  /// Set user context without PII
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: deviceId,
        data: {
          if (appVersion != null) 'app_version': appVersion,
          if (onboardingCompleted != null) 'onboarding_completed': onboardingCompleted.toString(),
          if (gutTrainingLevel != null) 'gut_training': gutTrainingLevel,
        },
      ));
    });
  }

  /// Add breadcrumb for debugging flow
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
  ISentryTransaction startTransaction(String operation, String description) {
    return Sentry.startTransaction(operation, description, bindToScope: true);
  }
}

/// Provider for SentryService
final sentryServiceProvider = Provider<SentryService>((ref) {
  return SentryService();
});
```

### Integration with App Startup Service

```dart
// lib/features/app_startup/application/app_startup_service.dart
class AppStartupService {
  AppStartupService(this.ref);
  final Ref ref;
  
  SentryService get _sentryService => ref.read(sentryServiceProvider);

  /// Initialize Sentry during app startup
  Future<void> initializeSentry() async {
    try {
      // Sentry is already initialized in main.dart
      // Here we just set user context
      final deviceId = await getOrCreateDeviceId();
      
      await _sentryService.setUserContext(
        deviceId: deviceId,
        appVersion: '1.1.0+8',
      );
      
      _sentryService.addBreadcrumb(
        message: 'App startup completed',
        category: 'app_lifecycle',
        level: SentryLevel.info,
      );
      
      print('📊 Sentry initialized with device ID: $deviceId');
    } catch (e, stackTrace) {
      // Don't use Sentry to report Sentry initialization errors
      print('❌ Sentry initialization error: $e');
    }
  }
}
```

## Session Replay Configuration

Session Replay provides visual reproduction of user sessions but should be used carefully to control bandwidth and privacy:

### Recommended Settings

```dart
// Production settings for session replay
options.experimental.replay.sessionSampleRate = 0.05; // 5% of all sessions
options.experimental.replay.onErrorSampleRate = 0.10; // 10% of error sessions

// Development settings
options.experimental.replay.sessionSampleRate = 1.0; // All sessions in dev
options.experimental.replay.onErrorSampleRate = 1.0; // All error sessions
```

### Privacy Considerations

- Session replay masks sensitive input fields by default
- Consider disabling for screens with health/payment data
- Monitor bandwidth usage in production

## Enhanced Error Handling Patterns

### 1. Repository Pattern Error Handling

```dart
// lib/features/auth/data/user_repository.dart
Future<UserProfile?> getCurrentUser() async {
  final transaction = ref.read(sentryServiceProvider).startTransaction(
    'user_repository',
    'get_current_user',
  );
  
  try {
    final user = await database.getCurrentUserProfile();
    transaction.finish(status: SpanStatus.ok());
    return user;
  } catch (error, stackTrace) {
    await ref.read(sentryServiceProvider).reportCriticalError(
      error,
      stackTrace: stackTrace,
      context: 'user_repository_get_current',
    );
    transaction.throwable = error;
    transaction.finish(status: SpanStatus.internalError());
    return null;
  }
}
```

### 2. Edge Function Error Tracking

```dart
// lib/features/nutrition_plan/data/nutrition_plan_repository.dart
Future<CreateNutritionPlanResult> createNutritionPlan({...}) async {
  final startTime = DateTime.now();
  
  try {
    final response = await supabase.functions.invoke('create-nutrition-plan', body: requestBody);
    final responseTime = DateTime.now().difference(startTime);
    
    if (response.status >= 200 && response.status < 300) {
      // Success - add performance breadcrumb
      ref.read(sentryServiceProvider).addBreadcrumb(
        message: 'Edge function success',
        category: 'edge_function',
        data: {'function': 'create-nutrition-plan', 'response_time_ms': responseTime.inMilliseconds},
      );
    }
    
    // ... rest of success handling
  } catch (error, stackTrace) {
    final responseTime = DateTime.now().difference(startTime);
    
    await ref.read(sentryServiceProvider).reportEdgeFunctionError(
      'create-nutrition-plan',
      error,
      responseTime: responseTime,
      requestData: requestBody,
    );
    
    throw error;
  }
}
```

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Add Sentry dependency to pubspec.yaml
- [ ] Create SentryService following FOA patterns
- [ ] Initialize Sentry in main.dart with production-ready config
- [ ] Integrate SentryService into AppStartupService
- [ ] Add navigation observer to router
- [ ] Test basic error reporting in development

### Phase 2: Critical Error Tracking (Week 2)
- [ ] Wrap all repository methods with Sentry error handling
- [ ] Add Edge Function error tracking
- [ ] Implement database error reporting with Drift context
- [ ] Add user context (device ID) without PII
- [ ] Configure release tracking for Shorebird patches

### Phase 3: Performance Monitoring (Week 3)
- [ ] Add performance transactions for critical operations
- [ ] Monitor Edge Function response times
- [ ] Track database query performance
- [ ] Set up alerts for performance regressions

### Phase 4: Session Replay & Advanced Features (Week 4)
- [ ] Configure Session Replay with privacy controls
- [ ] Set up performance monitoring dashboards
- [ ] Configure production sample rates
- [ ] Add custom error filtering rules
- [ ] Document error codes and meanings

### Phase 5: Production Optimization (Ongoing)
- [ ] Monitor error budgets and alerts
- [ ] Tune sampling rates based on usage
- [ ] Regular review of error patterns
- [ ] Performance optimization based on data

## Next Steps

1. **Immediate Actions**:
   - Add `sentry_flutter: ^9.6.0` to pubspec.yaml
   - Create SentryService following provided patterns
   - Initialize Sentry in app startup process

2. **Week 1 Goals**:
   - Basic error reporting working in development
   - Navigation tracking enabled
   - User context set without PII

3. **Production Deployment**:
   - Deploy to TestFlight with Sentry enabled
   - Monitor incoming error reports
   - Tune sampling rates based on initial data

4. **Monitoring Setup**:
   - Set up Sentry alerts for critical errors
   - Create performance monitoring dashboards
   - Establish error budget targets