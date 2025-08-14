# Error Tracking Implementation - Mealvana Endurance

## Overview

Sentry error tracking and performance monitoring implementation for the Mealvana Endurance nutrition planning app. The monitoring system captures crashes, tracks performance issues, and provides insights into app health to ensure reliable nutrition plan generation and user experience.

## Critical Monitoring Areas

### Nutrition Plan Generation Errors

The app's core functionality depends on reliable nutrition calculations and plan generation:

**Calculation Errors**: Monitor mathematical operations for carbohydrate, sodium, and fluid requirements. Track errors in macro calculations that could provide incorrect nutrition advice to endurance athletes.

**API Integration Failures**: Track errors when communicating with Supabase for user data retrieval and plan storage. Ensure offline-first architecture handles network failures gracefully without data loss.

**Food Preference Processing**: Monitor errors in food preference filtering and recommendation engines. Track cases where user preferences aren't properly applied during plan generation.

**Data Sync Issues**: Monitor synchronization errors between local Hive storage and Supabase backend. Track conflicts and resolution failures that could lead to data inconsistency.

```dart
// lib/shared/services/sentry_service.dart
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  static Future<void> initialize() async {
    await SentryFlutter.init(
      (options) {
        options.dsn = 'YOUR_SENTRY_DSN';
        options.environment = const String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production');
        options.tracesSampleRate = 0.2; // 20% of transactions for performance monitoring
        options.profilesSampleRate = 0.1; // 10% for profiling data
        
        // Custom error filtering
        options.beforeSend = (SentryEvent event, {dynamic hint}) {
          // Filter out low-priority errors
          if (event.level == SentryLevel.info) return null;
          
          // Add nutrition-specific context
          return event.copyWith(
            contexts: {
              ...event.contexts ?? {},
              'nutrition_context': {
                'feature': 'plan_generation',
                'user_has_preferences': _userHasPreferences(),
                'offline_mode': _isOffline(),
              },
            },
          );
        };
      },
      appRunner: () => runApp(MyApp()),
    );
  }
  
  static void reportNutritionError(
    Exception error,
    String feature, {
    Map<String, dynamic>? additionalContext,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Nutrition error in $feature',
      level: SentryLevel.error,
      data: additionalContext,
    ));
    
    Sentry.captureException(
      error,
      withScope: (scope) {
        scope.setTag('feature', feature);
        scope.setTag('category', 'nutrition');
        if (additionalContext != null) {
          for (final entry in additionalContext.entries) {
            scope.setContext(entry.key, entry.value);
          }
        }
      },
    );
  }
}
```

### Performance Monitoring

Track performance metrics critical to user experience:

**App Startup Time**: Monitor cold start performance to ensure users can quickly access their nutrition plans. Target startup times under 2 seconds for optimal user experience.

**Plan Generation Duration**: Track the time required to generate personalized nutrition plans. Alert if generation takes longer than 5 seconds, indicating potential optimization needs.

**Database Operation Latency**: Monitor Hive read/write operations and Supabase sync performance. Identify bottlenecks in data access patterns.

**UI Responsiveness**: Track frame rendering performance and identify UI freezes during navigation or data loading operations.

## Error Categorization

### Onboarding Flow Monitoring

Track errors in the critical user onboarding process:

**Profile Creation Failures**: Monitor errors when users create profiles with biometric information. Track validation failures and data persistence issues.

**Food Preference Errors**: Track failures in food preference collection and storage. Monitor incomplete preference sets that could affect plan quality.

**Onboarding Completion**: Track users who don't complete onboarding and identify specific failure points in the multi-step process.

### Data Integrity Monitoring

Ensure nutrition data accuracy and consistency:

**Sync Conflict Resolution**: Monitor conflicts between local and remote data during synchronization. Track resolution success rates and data corruption incidents.

**Offline Data Protection**: Monitor data loss during offline operations and ensure pending operations queue properly for later sync.

**User Data Privacy**: Track any potential privacy violations or unintended data exposure during error conditions.

```dart
// lib/features/nutrition_plan/application/nutrition_plan_service.dart
@riverpod
class NutritionPlanService extends _$NutritionPlanService {
  @override
  void build() {}

  Future<NutritionPlan> generatePlan({
    required double distanceMiles,
    required Duration averagePace,
  }) async {
    return await Sentry.traceAsyncFunction<NutritionPlan>(
      'nutrition_plan_generation',
      () async {
        final transaction = Sentry.getSpan()?.startChild(
          'plan_generation',
          description: 'Generate nutrition plan for ${distanceMiles}mi',
        );
        
        transaction?.setData('distance_miles', distanceMiles);
        transaction?.setData('average_pace_minutes', averagePace.inMinutes);
        
        try {
          final startTime = DateTime.now();
          
          // Add breadcrumb for debugging
          Sentry.addBreadcrumb(Breadcrumb(
            message: 'Starting nutrition plan generation',
            data: {
              'distance_miles': distanceMiles,
              'pace_minutes': averagePace.inMinutes,
            },
          ));
          
          final userProfile = await ref.read(userProfileProvider.future);
          if (userProfile == null) {
            throw NutritionPlanError('User profile not found');
          }
          
          final preferences = await ref.read(foodPreferencesProvider.future);
          final plan = await _generatePlanInternal(userProfile, preferences, distanceMiles, averagePace);
          
          final duration = DateTime.now().difference(startTime);
          transaction?.setData('generation_time_ms', duration.inMilliseconds);
          transaction?.setStatus(const SpanStatus.ok());
          
          // Track successful generation
          Sentry.addBreadcrumb(Breadcrumb(
            message: 'Plan generation completed',
            data: {
              'duration_ms': duration.inMilliseconds,
              'total_carbs': plan.macros.carbs,
              'total_items': plan.allItems.length,
            },
          ));
          
          return plan;
          
        } catch (error) {
          transaction?.throwable = error;
          transaction?.setStatus(const SpanStatus.internalError());
          
          SentryService.reportNutritionError(
            error is Exception ? error : Exception(error.toString()),
            'plan_generation',
            additionalContext: {
              'distance_miles': distanceMiles,
              'pace_minutes': averagePace.inMinutes,
              'user_id': userProfile?.id,
            },
          );
          
          rethrow;
        } finally {
          transaction?.finish();
        }
      },
    );
  }
}
```

## Alert Configuration

### Critical Alerts

Configure immediate alerts for issues that directly impact user safety or app functionality:

**Nutrition Calculation Errors**: Immediate alerts for errors in macro calculations or food recommendations that could provide harmful nutrition advice.

**Data Loss Events**: Immediate alerts when user data fails to persist or sync operations result in data loss.

**Authentication Failures**: Alert when users cannot access their profiles or when authentication tokens expire unexpectedly.

**Crash Rate Spikes**: Alert when crash rates exceed 2% of active users, indicating potential critical issues.

### Performance Degradation Alerts

Track performance metrics and alert on degradation:

**Slow Plan Generation**: Alert when plan generation exceeds 10 seconds, indicating performance issues.

**High Memory Usage**: Monitor memory consumption and alert on memory leaks that could cause crashes.

**Network Timeout Increases**: Alert when Supabase API calls consistently exceed timeout thresholds.

## Privacy and Data Protection

### Sensitive Data Handling

Protect user health information in error reports:

**Data Scrubbing**: Automatically remove personal health data, biometric information, and nutrition details from error reports while preserving debugging context.

**User Consent**: Respect user privacy preferences and only collect error data when users have consented to crash reporting.

**Regional Compliance**: Ensure error data storage complies with regional privacy laws including GDPR and CCPA requirements.

```dart
// lib/shared/services/error_context_service.dart
class ErrorContextService {
  static Map<String, dynamic> createSafeContext({
    required String feature,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) {
    final context = <String, dynamic>{
      'feature': feature,
      'app_version': PackageInfo.fromPlatform().version,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Add anonymized user identifier
    if (userId != null) {
      context['user_hash'] = _hashUserId(userId);
    }
    
    // Scrub sensitive data from additional context
    if (additionalData != null) {
      context.addAll(_scrubSensitiveData(additionalData));
    }
    
    return context;
  }
  
  static Map<String, dynamic> _scrubSensitiveData(Map<String, dynamic> data) {
    final scrubbed = <String, dynamic>{};
    
    for (final entry in data.entries) {
      if (_isSensitiveKey(entry.key)) {
        scrubbed[entry.key] = '[REDACTED]';
      } else {
        scrubbed[entry.key] = entry.value;
      }
    }
    
    return scrubbed;
  }
  
  static bool _isSensitiveKey(String key) {
    const sensitiveKeys = [
      'email', 'phone', 'address', 'weight', 'height', 'birthday',
      'medical_condition', 'dietary_restriction'
    ];
    return sensitiveKeys.any((sensitive) => key.toLowerCase().contains(sensitive));
  }
}
```

## Release Health Tracking

### Deployment Monitoring

Track app health across releases to identify regression issues:

**Crash-Free Session Rate**: Monitor the percentage of sessions without crashes for each release. Target 99.5% crash-free sessions.

**Performance Regression Detection**: Compare performance metrics between releases to identify performance regressions before they affect all users.

**Feature Adoption Monitoring**: Track how new features perform in production and identify usage patterns that may cause issues.

### User Experience Metrics

Track metrics that directly impact user satisfaction:

**Onboarding Completion Rate**: Monitor what percentage of users successfully complete the onboarding flow.

**Plan Generation Success Rate**: Track successful nutrition plan generations versus failures or timeouts.

**Sync Success Rate**: Monitor successful data synchronization between local and remote storage.

This error tracking implementation ensures the Mealvana Endurance app maintains high reliability and performance while protecting user privacy and providing actionable insights for continuous improvement.