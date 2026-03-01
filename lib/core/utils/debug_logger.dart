import 'package:flutter/foundation.dart';

/// Centralized logging helper to keep analyzer output clean in production code.
class DebugLogger {
  const DebugLogger._();

  static bool get _enabled =>
      kDebugMode && const bool.fromEnvironment('VERBOSE_DEBUG_LOGS');

  static void debug(String message) {
    if (_enabled) debugPrint(message);
  }

  static void info(String message) {
    if (_enabled) debugPrint(message);
  }

  static void warning(String message) {
    if (_enabled) debugPrint(message);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' -> $error');
    }
    debugPrint(buffer.toString());
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
