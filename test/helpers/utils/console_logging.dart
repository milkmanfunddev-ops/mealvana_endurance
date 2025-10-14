/// Console logging utilities for test output consistency
///
/// All tests should use these functions to ensure readable, structured output
/// that makes debugging and verification easier.
library;

import 'package:flutter/foundation.dart';

// ANSI color codes for terminal output
const String _reset = '\x1B[0m';
const String _bold = '\x1B[1m';
const String _green = '\x1B[32m';
const String _red = '\x1B[31m';
const String _blue = '\x1B[34m';
const String _yellow = '\x1B[33m';
const String _cyan = '\x1B[36m';
const String _magenta = '\x1B[35m';

/// Log a test heading/title
///
/// Example: logTestHeading('Edge Function – Marathon Plan Generation')
void logTestHeading(String heading) {
  final divider = '=' * 80;
  debugPrint('\n$_bold$_cyan$divider$_reset');
  debugPrint('$_bold$_cyan║ $heading$_reset');
  debugPrint('$_bold$_cyan$divider$_reset\n');
}

/// Log test input data
///
/// Example:
/// ```dart
/// logTestInput({
///   'distance_miles': 26.2,
///   'gut_training': 'advanced',
///   'pace_min_per_mile': 8.5,
/// });
/// ```
void logTestInput(Map<String, dynamic> input) {
  debugPrint('$_bold$_blue📥 Test Input:$_reset');
  input.forEach((key, value) {
    final displayValue = value is double
        ? value.toStringAsFixed(2)
        : value.toString();
    debugPrint('  • $key: $_cyan$displayValue$_reset');
  });
  debugPrint('');
}

/// Log a single test result with actual value and optional expected range
///
/// Example:
/// ```dart
/// logTestResult('carbs_total_g', 285.0, expectedRange: '280-290');
/// logTestResult('hydration_ml', 1500, expected: 1500);
/// ```
void logTestResult(
  String label,
  dynamic actual, {
  dynamic expected,
  String? expectedRange,
  String? unit,
}) {
  final actualStr = _formatValue(actual, unit);

  if (expectedRange != null) {
    debugPrint('$_bold$_magenta📊 $label:$_reset $actualStr (expected: $expectedRange)');
  } else if (expected != null) {
    final expectedStr = _formatValue(expected, unit);
    final matches = actual == expected;
    final icon = matches ? '✓' : '✗';
    final color = matches ? _green : _red;
    debugPrint('$_bold$_magenta📊 $label:$_reset $actualStr (expected: $expectedStr) $color$icon$_reset');
  } else {
    debugPrint('$_bold$_magenta📊 $label:$_reset $actualStr');
  }
}

/// Log multiple test results at once
///
/// Example:
/// ```dart
/// logTestResults({
///   'carbs_g': ResultData(actual: 285, expectedRange: '280-290'),
///   'protein_g': ResultData(actual: 45, expected: 45),
///   'water_ml': ResultData(actual: 1500),
/// });
/// ```
void logTestResults(Map<String, ResultData> results) {
  debugPrint('$_bold$_magenta📊 Test Results:$_reset');
  results.forEach((label, data) {
    final actualStr = _formatValue(data.actual, data.unit);

    if (data.expectedRange != null) {
      debugPrint('  • $label: $actualStr (range: ${data.expectedRange})');
    } else if (data.expected != null) {
      final expectedStr = _formatValue(data.expected, data.unit);
      final matches = data.actual == data.expected;
      final icon = matches ? '✓' : '✗';
      final color = matches ? _green : _red;
      debugPrint('  • $label: $actualStr vs $expectedStr $color$icon$_reset');
    } else {
      debugPrint('  • $label: $actualStr');
    }
  });
  debugPrint('');
}

/// Log a test assertion/expectation
///
/// Example:
/// ```dart
/// logAssertion('Carbs should be within ±10g of target', passed: true);
/// logAssertion('No dairy products during run', passed: false, reason: 'Found milk in plan');
/// ```
void logAssertion(String assertion, {required bool passed, String? reason}) {
  final icon = passed ? '✓' : '✗';
  final color = passed ? _green : _red;
  debugPrint('$color$icon $assertion$_reset');
  if (!passed && reason != null) {
    debugPrint('  ${_red}Reason: $reason$_reset');
  }
}

/// Log test pass status
///
/// Example: logTestPass()
void logTestPass([String? message]) {
  final msg = message ?? 'Test PASSED';
  debugPrint('$_bold$_green✅ $msg$_reset\n');
}

/// Log test failure status
///
/// Example: logTestFail('Expected carbs to be 280-290g but got 150g')
void logTestFail(String reason) {
  debugPrint('$_bold$_red❌ Test FAILED: $reason$_reset\n');
}

/// Log a warning during test execution
///
/// Example: logTestWarning('Using fallback algorithm instead of AI')
void logTestWarning(String warning) {
  debugPrint('$_yellow⚠️  Warning: $warning$_reset');
}

/// Log test setup information
///
/// Example:
/// ```dart
/// logTestSetup({
///   'database': 'In-memory Drift v1',
///   'supabase': 'Mock client',
///   'analytics': 'Recording fake',
/// });
/// ```
void logTestSetup(Map<String, String> setup) {
  debugPrint('$_bold$_blue🔧 Test Setup:$_reset');
  setup.forEach((component, description) {
    debugPrint('  • $component: $_cyan$description$_reset');
  });
  debugPrint('');
}

/// Log section divider
///
/// Example: logSection('Phase 1: Before Run Foods')
void logSection(String title) {
  debugPrint('\n$_bold$_blue─── $title ───$_reset\n');
}

/// Log API/Edge Function call
///
/// Example:
/// ```dart
/// logApiCall(
///   method: 'POST',
///   endpoint: '/functions/v1/generate-ai-nutrition-plan',
///   duration: Duration(milliseconds: 850),
/// );
/// ```
void logApiCall({
  required String method,
  required String endpoint,
  int? statusCode,
  Duration? duration,
  dynamic error,
}) {
  final status = statusCode != null ? ' ($statusCode)' : '';
  final timing = duration != null ? ' [${duration.inMilliseconds}ms]' : '';

  if (error != null) {
    debugPrint('$_red🌐 $method $endpoint$status$timing - ERROR: $error$_reset');
  } else {
    debugPrint('$_blue🌐 $method $endpoint$status$timing$_reset');
  }
}

/// Log database operation
///
/// Example:
/// ```dart
/// logDatabaseOp(
///   operation: 'INSERT',
///   table: 'nutrition_plans',
///   duration: Duration(milliseconds: 12),
/// );
/// ```
void logDatabaseOp({
  required String operation,
  required String table,
  Duration? duration,
  int? rowsAffected,
}) {
  final timing = duration != null ? ' [${duration.inMilliseconds}ms]' : '';
  final rows = rowsAffected != null ? ' ($rowsAffected rows)' : '';
  debugPrint('$_cyan💾 $operation $table$rows$timing$_reset');
}

/// Log analytics event tracking
///
/// Example:
/// ```dart
/// logAnalyticsEvent('plan_generated', properties: {'type': 'ai', 'distance': 26.2});
/// ```
void logAnalyticsEvent(String eventName, {Map<String, dynamic>? properties}) {
  final props = properties != null
      ? ' ${properties.entries.map((e) => '${e.key}:${e.value}').join(', ')}'
      : '';
  debugPrint('$_magenta📈 Analytics: $eventName$props$_reset');
}

/// Format a value for display with optional unit
String _formatValue(dynamic value, String? unit) {
  String valueStr;
  if (value is double) {
    valueStr = value.toStringAsFixed(2);
  } else if (value is int) {
    valueStr = value.toString();
  } else {
    valueStr = value.toString();
  }

  return unit != null ? '$valueStr$unit' : valueStr;
}

/// Data class for structured test results
class ResultData {
  const ResultData({
    required this.actual,
    this.expected,
    this.expectedRange,
    this.unit,
  });

  final dynamic actual;
  final dynamic expected;
  final String? expectedRange;
  final String? unit;
}
