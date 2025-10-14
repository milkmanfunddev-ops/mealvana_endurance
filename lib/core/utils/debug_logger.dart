import 'package:flutter/foundation.dart';

/// Centralized logging helper to keep analyzer output clean in production code.
class DebugLogger {
  const DebugLogger._();

  static void debug(String message) {
    debugPrint(message);
  }

  static void info(String message) {
    debugPrint(message);
  }

  static void warning(String message) {
    debugPrint(message);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
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
