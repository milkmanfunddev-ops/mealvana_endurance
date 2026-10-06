import '../../shared/services/report/report.dart';

/// Legacy static logger. Every call forwards to the app's [Report] (glossary:
/// CONTEXT.md § Error reporting): `error` is a Fault, `warning` is Degraded,
/// `info` and `debug` are structured logs. Before 2026-10-05 these lines went
/// to the console only, and only with `VERBOSE_DEBUG_LOGS`; 374 catch blocks
/// were invisible for it. Deleted when the last caller is moved (ticket 10 of
/// `.scratch/sentry/`).
class DebugLogger {
  const DebugLogger._();

  static Report get _report => SentryReport.global;

  static void debug(String message) => _report.debug(message);

  static void info(String message) => _report.info(message);

  static void warning(String message) {
    _report.degraded(LoggedFault(message));
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _report.fault(
      error ?? LoggedFault(message),
      stackTrace: stackTrace,
      message: error == null ? null : message,
    );
  }
}
