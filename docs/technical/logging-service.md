# Logging Service Documentation

## Overview

The Mealvana Endurance app uses a centralized logging service built on top of the `logger` package to provide structured, contextual logging throughout the application. This service replaces scattered `print()` statements with a consistent, configurable logging solution.

## Features

- **Structured Logging**: Consistent log formatting with context and metadata
- **Multiple Log Levels**: Debug, Info, Warning, Error, Fatal
- **Contextual Logging**: Specialized methods for different contexts (API, Database, Navigation, etc.)
- **Production Filtering**: Automatically reduces log verbosity in production
- **Integration Ready**: Designed to work with Sentry and other monitoring tools
- **Riverpod Integration**: Available as a provider for dependency injection

## Quick Start

### 1. Initialize the Service

Initialize the logging service early in your app startup (typically in `main.dart`):

```dart
import 'package:mealvana_endurance/shared/services/logging_service.dart';

void main() {
  // Initialize logging service
  LoggingService().initialize(
    logLevel: Level.debug,
    enableFileOutput: false,
  );
  
  runApp(MyApp());
}
```

### 2. Use in Services and Controllers

Access via Riverpod provider:

```dart
class MyService {
  MyService(this.ref);
  final Ref ref;
  
  LoggingService get _logger => ref.read(loggingServiceProvider);
  
  void someMethod() {
    _logger.info('Method called successfully');
  }
}
```

### 3. Use in Static Contexts

For static contexts where dependency injection isn't available:

```dart
import 'package:mealvana_endurance/shared/services/logging_service.dart';

void someStaticMethod() {
  appLogger.info('Static method called');
}
```

## Log Levels

### Debug
Use for detailed diagnostic information, only visible in debug builds:
```dart
logger.debug('Processing nutrition plan calculation', 
  context: 'NutritionCalculator',
  data: {'distanceMiles': 12.0, 'pace': 9.0}
);
```

### Info
Use for general application flow information:
```dart
logger.info('User completed onboarding');
```

### Warning
Use for potentially harmful situations that don't stop execution:
```dart
logger.warning('Food preference not found, using default', 
  context: 'FoodRepository'
);
```

### Error
Use for error events that don't stop execution:
```dart
logger.error('Failed to save nutrition plan', 
  context: 'PlanRepository',
  error: exception,
  stackTrace: stackTrace
);
```

### Fatal
Use for very severe errors that might cause termination:
```dart
logger.fatal('Database corruption detected', 
  error: exception,
  stackTrace: stackTrace
);
```

## Contextual Logging Methods

The service provides specialized methods for common contexts:

### API Logging
```dart
// Success
logger.api('Generated nutrition plan successfully',
  endpoint: '/generate-ai-nutrition-plan',
  statusCode: 200,
  duration: Duration(seconds: 2),
);

// Error
logger.api('API call failed',
  endpoint: '/generate-ai-nutrition-plan',
  statusCode: 500,
  error: exception,
);
```

### Database Logging
```dart
logger.database('User profile updated',
  operation: 'UPDATE',
  table: 'users',
  data: {'weight': 150.0},
  duration: Duration(milliseconds: 50),
);
```

### Navigation Logging
```dart
logger.navigation('User navigated to plan screen',
  from: '/onboarding',
  to: '/nutrition-plan',
  parameters: {'planId': 'abc123'},
);
```

### User Action Logging
```dart
logger.userAction('User tapped generate plan button',
  action: 'tap',
  screen: 'distance_entry',
  data: {'distance': 12.0, 'pace': 9.0},
);
```

### Nutrition Plan Logging
```dart
logger.nutritionPlan('Plan section converted',
  planId: 'ai-plan-123',
  phase: 'before_run',
  data: {'itemCount': 3, 'totalCarbs': 97},
);
```

### Analytics Logging
```dart
logger.analytics('Nutrition plan generated',
  event: 'plan_generated',
  properties: {'distance': 12.0, 'duration': 108},
);
```

## Configuration

### Log Levels
Control what gets logged based on build type:
- **Debug builds**: All levels (Debug, Info, Warning, Error, Fatal)
- **Release builds**: Info and above (Info, Warning, Error, Fatal)

### Custom Configuration
```dart
LoggingService().initialize(
  logLevel: kDebugMode ? Level.debug : Level.info,
  enableFileOutput: false, // Future: save logs to file
);
```

## Integration with Existing Services

### Replacing Print Statements

**Before:**
```dart
print('🔍 DEBUG: User weight: $weight');
print('Error saving plan: $error');
```

**After:**
```dart
logger.debug('User weight loaded', 
  context: 'UserService',
  data: {'weight': weight}
);
logger.error('Failed to save plan', 
  context: 'PlanRepository',
  error: error
);
```

### Integration with Sentry
The logging service is designed to work with Sentry. Error-level logs can be automatically reported:

```dart
logger.error('Critical nutrition calculation failed',
  context: 'NutritionCalculator',
  data: {'distance': distance, 'weight': weight},
  error: exception,
  stackTrace: stackTrace,
);
// This can automatically trigger Sentry.captureException()
```

## Best Practices

### 1. Use Appropriate Log Levels
- **Debug**: Detailed diagnostic info (calculations, data transformations)
- **Info**: Important business events (plan generated, user actions)
- **Warning**: Recoverable issues (fallbacks, missing optional data)
- **Error**: Failures that don't crash the app (API failures, data corruption)
- **Fatal**: Critical failures that might crash the app

### 2. Provide Context
Always include relevant context and data:
```dart
// Good
logger.debug('Food items converted',
  context: 'LLMService',
  data: {'beforeItems': 3, 'duringItems': 2, 'afterItems': 2}
);

// Less helpful
logger.debug('Conversion complete');
```

### 3. Use Structured Data
Pass data as maps rather than interpolating into strings:
```dart
// Good
logger.info('Plan generated',
  data: {'planId': planId, 'itemCount': items.length}
);

// Less structured
logger.info('Plan $planId generated with ${items.length} items');
```

### 4. Include Error Context
When logging errors, include both the error and relevant context:
```dart
logger.error('Database operation failed',
  context: 'NutritionPlanRepository',
  data: {'operation': 'INSERT', 'planId': planId},
  error: exception,
  stackTrace: stackTrace,
);
```

### 5. Avoid Logging Sensitive Information
Never log passwords, API keys, personal data, or other sensitive information:
```dart
// Bad - logs sensitive data
logger.debug('User login', data: {'password': password});

// Good - logs only non-sensitive data
logger.info('User login attempt', data: {'email': email});
```

## Migration Guide

### Step 1: Replace Print Statements
Find all `print()` statements and replace with appropriate logging calls:

```bash
# Find all print statements
grep -r "print(" lib/
```

### Step 2: Add Context
Group related logs by adding appropriate context:
- API calls: Use `logger.api()`
- Database operations: Use `logger.database()`
- User interactions: Use `logger.userAction()`
- Navigation: Use `logger.navigation()`

### Step 3: Add Structured Data
Convert string interpolations to structured data:
```dart
// Before
print('Processing ${foods.length} foods for user $userId');

// After
logger.debug('Processing foods for user',
  context: 'FoodProcessor',
  data: {'foodCount': foods.length, 'userId': userId}
);
```

## File Structure

```
lib/shared/services/logging_service.dart  # Main logging service
docs/technical/logging-service.md         # This documentation
```

## Dependencies

- `logger: ^2.4.0` - Core logging functionality
- `flutter/foundation.dart` - For `kDebugMode` and `kReleaseMode`

## Future Enhancements

1. **File Output**: Save logs to local files for offline debugging
2. **Remote Logging**: Send logs to remote monitoring services
3. **Log Rotation**: Manage log file sizes
4. **Custom Filters**: More sophisticated filtering options
5. **Performance Metrics**: Automatic performance logging
6. **Crash Reporting Integration**: Automatic Sentry integration

## Examples

See `lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart` for examples of the logging service in action, replacing the previous `print()` statements with structured logging calls.