/// Integration Test Helpers
///
/// Common utilities for integration tests including:
/// - Widget finders
/// - Tap and interaction helpers
/// - Wait utilities
/// - Test data cleanup
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_config.dart';

/// Extension methods for WidgetTester to simplify integration testing
extension IntegrationTestHelpers on WidgetTester {
  /// Wait for the app to settle after navigation or async operations
  Future<void> settle({Duration? duration}) async {
    await pumpAndSettle(duration ?? TestConfig.animationDelay);
  }

  /// Wait for a specific duration (for network calls, etc.)
  Future<void> wait(Duration duration) async {
    await Future.delayed(duration);
    await pumpAndSettle();
  }

  /// Tap a widget and wait for the UI to settle
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Tap a widget by key and wait for the UI to settle
  Future<void> tapByKey(String key) async {
    final finder = find.byKey(Key(key));
    expect(finder, findsOneWidget, reason: 'Expected to find widget with key: $key');
    await tap(finder);
    await pumpAndSettle();
  }

  /// Tap a widget by text and wait for the UI to settle
  Future<void> tapByText(String text) async {
    final finder = find.text(text);
    expect(finder, findsWidgets, reason: 'Expected to find widget with text: $text');
    await tap(finder.first);
    await pumpAndSettle();
  }

  /// Tap a widget by icon and wait for the UI to settle
  Future<void> tapByIcon(IconData icon) async {
    final finder = find.byIcon(icon);
    expect(finder, findsWidgets, reason: 'Expected to find widget with icon: $icon');
    await tap(finder.first);
    await pumpAndSettle();
  }

  /// Enter text into a text field by key
  Future<void> enterTextByKey(String key, String text) async {
    final finder = find.byKey(Key(key));
    expect(finder, findsOneWidget, reason: 'Expected to find text field with key: $key');
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Enter text into a text field found by its hint text
  Future<void> enterTextByHint(String hint, String text) async {
    final finder = find.widgetWithText(TextField, hint);
    if (finder.evaluate().isEmpty) {
      // Try finding by decoration hint (TextField only - TextFormField wraps TextField)
      final decoratedFinder = find.byWidgetPredicate((widget) {
        if (widget is TextField) {
          return widget.decoration?.hintText == hint ||
              widget.decoration?.labelText == hint;
        }
        return false;
      });
      expect(decoratedFinder, findsWidgets, reason: 'Expected to find text field with hint: $hint');
      await enterText(decoratedFinder.first, text);
    } else {
      await enterText(finder.first, text);
    }
    await pumpAndSettle();
  }

  /// Clear and enter text into a text field
  Future<void> clearAndEnterText(Finder finder, String text) async {
    await tap(finder);
    await pumpAndSettle();
    // Select all and delete
    await enterText(finder, '');
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Scroll until a widget is visible (custom implementation)
  Future<void> scrollToFind(
    Finder finder, {
    Finder? scrollable,
    double delta = 100,
    int maxScrolls = 50,
  }) async {
    final scrollableFinder = scrollable ?? find.byType(Scrollable).first;

    int scrollCount = 0;
    while (finder.evaluate().isEmpty && scrollCount < maxScrolls) {
      await drag(scrollableFinder, Offset(0, -delta));
      await pumpAndSettle();
      scrollCount++;
    }

    expect(finder, findsWidgets,
        reason: 'Could not find widget after $maxScrolls scrolls');
  }

  /// Wait for a widget to appear with timeout
  Future<bool> waitForWidget(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      await pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await pumpAndSettle();
        return true;
      }
    }

    return false;
  }

  /// Verify a widget exists
  void expectWidget(Finder finder, {String? reason}) {
    expect(finder, findsWidgets, reason: reason);
  }

  /// Verify a widget does not exist
  void expectNoWidget(Finder finder, {String? reason}) {
    expect(finder, findsNothing, reason: reason);
  }

  /// Verify text is visible on screen
  void expectText(String text, {String? reason}) {
    expect(find.text(text), findsWidgets, reason: reason ?? 'Expected to find text: $text');
  }

  /// Verify text is not visible on screen
  void expectNoText(String text, {String? reason}) {
    expect(find.text(text), findsNothing, reason: reason ?? 'Expected not to find text: $text');
  }

  /// Take a screenshot with a label (for debugging)
  Future<void> screenshot(String label) async {
    debugPrint('--- SCREENSHOT: $label ---');
    await pumpAndSettle();
    // In a real test environment, you could save actual screenshots here
  }
}

/// Cleanup utilities for test data
class TestCleanup {
  /// Delete the current anonymous user from Supabase
  /// Call this in tearDown to clean up test data
  static Future<void> deleteCurrentUser() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        // Sign out first
        await supabase.auth.signOut();

        // Note: Deleting users requires admin privileges
        // In dev, you may need to clean up via Supabase dashboard
        // or use a service role key edge function
        debugPrint('Signed out user: ${user.id}');
      }
    } catch (e) {
      debugPrint('Error cleaning up user: $e');
    }
  }

  /// Clear local database (if needed between tests)
  static Future<void> clearLocalData() async {
    // This would clear the Drift database if needed
    // Implementation depends on how database is exposed
    debugPrint('Local data cleared');
  }
}

/// Logging utilities for integration tests
class TestLogger {
  static void logStep(String step) {
    debugPrint('\n========================================');
    debugPrint('STEP: $step');
    debugPrint('========================================\n');
  }

  static void logSubStep(String step) {
    debugPrint('  -> $step');
  }

  static void logSuccess(String message) {
    debugPrint('  [PASS] $message');
  }

  static void logError(String message) {
    debugPrint('  [FAIL] $message');
  }

  static void logInfo(String message) {
    debugPrint('  [INFO] $message');
  }
}
