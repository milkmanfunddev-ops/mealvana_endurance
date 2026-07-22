import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extension methods for WidgetTester to simplify pumping in integration tests
extension PumpHelpers on WidgetTester {
  /// Pumps the app and waits for initial frame to settle
  /// Use this instead of pumpWidget for integration tests
  Future<void> pumpApp(Widget app) async {
    await pumpWidget(app);
    await pump(); // Initial frame
    await pump(const Duration(milliseconds: 100)); // Allow animations to start
  }

  /// Pumps until a widget matching the finder is found
  /// Useful for waiting for async operations to complete
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      // Pump and settle
      await pump(interval);

      // Check if widget is found
      if (any(finder)) {
        return;
      }
    }

    throw TimeoutException(
      'Widget not found after ${timeout.inSeconds} seconds',
      timeout,
    );
  }

  /// Pumps until a condition is true
  /// More flexible than pumpUntilFound
  Future<void> pumpUntilCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      // Pump and settle
      await pump(interval);

      // Check condition
      if (condition()) {
        return;
      }
    }

    throw TimeoutException(
      'Condition not met after ${timeout.inSeconds} seconds',
      timeout,
    );
  }

  /// Pumps a specific number of frames
  /// Useful for animations or waiting for multiple rebuilds
  Future<void> pumpFrames(
    int count, {
    Duration interval = const Duration(milliseconds: 16),
  }) async {
    for (var i = 0; i < count; i++) {
      await pump(interval);
    }
  }

  /// Pumps and waits for all animations and async operations to complete
  /// with a custom timeout
  Future<void> pumpAndSettleWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await pumpAndSettle(timeout);
  }

  /// Taps a widget and waits for the tap to complete
  /// Convenience method that combines tap + pump
  Future<void> tapAndPump(Finder finder, {Duration? settleDuration}) async {
    await tap(finder);
    if (settleDuration != null) {
      await pump(settleDuration);
    } else {
      await pump();
    }
  }

  /// Enters text and pumps to see the result
  Future<void> enterTextAndPump(Finder finder, String text) async {
    await enterText(finder, text);
    await pump();
  }

  /// Scrolls until a widget is visible
  Future<void> scrollUntilVisible(
    Finder finder,
    Finder scrollable, {
    double delta = 100.0,
    int maxScrolls = 50,
  }) async {
    for (var i = 0; i < maxScrolls; i++) {
      if (any(finder)) {
        return;
      }
      await drag(scrollable, Offset(0, -delta));
      await pump();
    }

    throw Exception('Widget not found after $maxScrolls scrolls');
  }
}

/// Custom exception for pump timeout errors
class TimeoutException implements Exception {
  TimeoutException(this.message, this.timeout);

  final String message;
  final Duration timeout;

  @override
  String toString() => message;
}
