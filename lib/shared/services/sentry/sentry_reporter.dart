import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;

import '../report/report.dart';

/// Legacy reporting surface. Every method is a thin alias onto [Report]
/// (glossary: CONTEXT.md § Error reporting) so existing call sites compile
/// unchanged while the migration tickets move them to `Report` directly.
/// Deleted when the last caller is moved (ticket 10 of `.scratch/sentry/`).
abstract class SentryReporter {
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  });

  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  });

  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  });

  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  });

  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  });

  Future<void> clearUserContext();

  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level,
    Map<String, dynamic>? data,
  });

  Future<void> captureMessage(
    String message, {
    SentryLevel level,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
  });

  bool get isEnabled;
}

/// The legacy surface, forwarding to [Report].
///
/// Mapping: critical, edge-function and database errors are Faults (Report
/// downgrades the expected ones itself); network errors are Degraded, as they
/// were already warnings; `captureMessage` picks the rung from its level.
class SentrySdkReporter implements SentryReporter {
  SentrySdkReporter([Report? report]) : _report = report;

  final Report? _report;

  Report get _r => _report ?? SentryReport.global;

  @override
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) => _r.fault(
    _asError(error),
    stackTrace: stackTrace,
    area: context,
    tags: tags,
  );

  @override
  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  }) => _r.fault(
    _asError(error),
    stackTrace: stackTrace,
    area: 'edge_function',
    tags: {
      'component': 'edge_function',
      'function_name': functionName,
      if (responseTime != null)
        'response_time_ms': responseTime.inMilliseconds.toString(),
      if (statusCode != null) 'status_code': statusCode.toString(),
    },
  );

  @override
  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) => _r.fault(
    _asError(error),
    stackTrace: stackTrace,
    area: 'database',
    tags: {
      'component': 'database',
      'operation': operation ?? 'unknown',
      'table': table ?? 'unknown',
    },
  );

  @override
  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  }) => _r.degraded(
    _asError(error),
    stackTrace: stackTrace,
    area: 'network',
    tags: {
      'component': 'network',
      if (url != null) 'url': url,
      if (method != null) 'method': method,
      if (statusCode != null) 'status_code': statusCode.toString(),
      if (timeout != null) 'timeout_ms': timeout.inMilliseconds.toString(),
    },
  );

  /// Legacy identity: the device id as the Sentry user id. Ticket 02 moves
  /// identity to the Supabase user id plus role; the profile fields passed
  /// here were never searchable and are not forwarded.
  @override
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) => _r.setUser(deviceId);

  @override
  Future<void> clearUserContext() => _r.clearUser();

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) => _r.breadcrumb(message, category: category, data: data);

  @override
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
  }) async {
    switch (level) {
      case SentryLevel.fatal:
      case SentryLevel.error:
        await _r.fault(
          LoggedFault(message),
          tags: tags,
          extra: extra,
          fingerprint: fingerprint,
        );
      case SentryLevel.warning:
        await _r.degraded(
          LoggedFault(message),
          tags: tags,
          extra: extra,
          fingerprint: fingerprint,
        );
      case SentryLevel.info:
        _r.info(message, data: {...?tags, ...?extra});
      case SentryLevel.debug:
        _r.debug(message, data: {...?tags, ...?extra});
    }
  }

  @override
  bool get isEnabled => _r.isEnabled;

  static Object _asError(dynamic error) =>
      error ?? const LoggedFault('null error reported');
}

/// Emits nothing. Kept for the tests that inject it; new tests use
/// [NoopReport].
class NoopSentryReporter implements SentryReporter {
  const NoopSentryReporter();

  @override
  Future<void> reportCriticalError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) async {}

  @override
  Future<void> reportEdgeFunctionError(
    String functionName,
    dynamic error, {
    Duration? responseTime,
    int? statusCode,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> reportDatabaseError(
    dynamic error, {
    String? operation,
    String? table,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> reportNetworkError(
    dynamic error, {
    String? url,
    String? method,
    int? statusCode,
    Duration? timeout,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> setUserContext({
    required String deviceId,
    String? appVersion,
    bool? onboardingCompleted,
    String? gutTrainingLevel,
  }) async {}

  @override
  Future<void> clearUserContext() async {}

  @override
  void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {}

  @override
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
  }) async {}

  @override
  bool get isEnabled => false;
}

final sentryReporterProvider = Provider<SentryReporter>((ref) {
  return SentrySdkReporter(ref.watch(reportProvider));
});
