/// Console logging utilities for test output
/// Provides structured, colored console output for test debugging
library;

/// ANSI color codes for console output
class _Colors {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String green = '\x1B[32m';
  static const String red = '\x1B[31m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String cyan = '\x1B[36m';
  static const String gray = '\x1B[90m';
}

/// Log a test heading with colored divider
void logTestHeading(String title) {
  final divider = '=' * 80;
  print('${_Colors.bold}${_Colors.blue}$divider${_Colors.reset}');
  print('${_Colors.bold}${_Colors.blue}TEST: $title${_Colors.reset}');
  print('${_Colors.bold}${_Colors.blue}$divider${_Colors.reset}');
}

/// Log test setup/configuration details
void logTestSetup(Map<String, dynamic> config) {
  print('${_Colors.cyan}SETUP:${_Colors.reset}');
  config.forEach((key, value) {
    print('  ${_Colors.gray}$key: ${_Colors.reset}$value');
  });
}

/// Log test input parameters
void logTestInput(Map<String, dynamic> inputs) {
  print('${_Colors.cyan}INPUT:${_Colors.reset}');
  inputs.forEach((key, value) {
    print('  ${_Colors.gray}$key: ${_Colors.reset}$value');
  });
}

/// Log a single test result
void logTestResult(
  String label,
  dynamic actual, {
  dynamic expected,
  String? expectedRange,
  String? unit,
}) {
  final unitStr = unit != null ? ' $unit' : '';
  final expectedStr = expected != null
      ? ' (expected: $expected$unitStr)'
      : (expectedRange != null ? ' (expected range: $expectedRange$unitStr)' : '');

  print(
      '${_Colors.cyan}RESULT:${_Colors.reset} $label = ${_Colors.bold}$actual$unitStr${_Colors.reset}$expectedStr');
}

/// Log multiple test results at once
void logTestResults(Map<String, ResultData> results) {
  print('${_Colors.cyan}RESULTS:${_Colors.reset}');
  results.forEach((label, data) {
    final unitStr = data.unit != null ? ' ${data.unit}' : '';
    final expectedStr = data.expected != null
        ? ' (expected: ${data.expected}$unitStr)'
        : (data.expectedRange != null
            ? ' (expected range: ${data.expectedRange}$unitStr)'
            : '');

    print(
        '  $label: ${_Colors.bold}${data.actual}$unitStr${_Colors.reset}$expectedStr');
  });
}

/// Log an assertion/validation check
void logAssertion(String description, {required bool passed, String? reason}) {
  final status = passed
      ? '${_Colors.green}PASS${_Colors.reset}'
      : '${_Colors.red}FAIL${_Colors.reset}';
  final reasonStr = reason != null ? ' - $reason' : '';
  print('${_Colors.yellow}ASSERT:${_Colors.reset} $description [$status]$reasonStr');
}

/// Log test pass status
void logTestPass([String? message]) {
  final msg = message ?? 'Test passed';
  print('${_Colors.bold}${_Colors.green}✓ $msg${_Colors.reset}');
}

/// Log test fail status
void logTestFail(String reason) {
  print('${_Colors.bold}${_Colors.red}✗ Test failed: $reason${_Colors.reset}');
}

/// Log a section divider
void logSection(String title) {
  print('\n${_Colors.bold}${_Colors.cyan}--- $title ---${_Colors.reset}');
}

/// Log an API call
void logApiCall(String endpoint, {Map<String, dynamic>? params}) {
  print('${_Colors.yellow}API CALL:${_Colors.reset} $endpoint');
  if (params != null && params.isNotEmpty) {
    params.forEach((key, value) {
      print('  ${_Colors.gray}$key: ${_Colors.reset}$value');
    });
  }
}

/// Log a database operation
void logDatabaseOp(String operation, {String? details}) {
  final detailStr = details != null ? ' - $details' : '';
  print('${_Colors.cyan}DB:${_Colors.reset} $operation$detailStr');
}

/// Log an analytics event
void logAnalyticsEvent(String eventName, {Map<String, dynamic>? properties}) {
  print('${_Colors.yellow}ANALYTICS:${_Colors.reset} $eventName');
  if (properties != null && properties.isNotEmpty) {
    properties.forEach((key, value) {
      print('  ${_Colors.gray}$key: ${_Colors.reset}$value');
    });
  }
}

/// Data class for test results
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
