// Seam: `options.beforeCaptureScreenshot` (ticket 21). Prod crash
// MEALVANA-ENDURANCE-CR was the Sentry screenshot recorder's
// `Picture.toImage` running while the Android activity was stopped, which
// forces an offscreen Impeller GLES snapshot surface (flutter/flutter#193899).
// The gate must refuse every non-resumed state, allow resumed and the
// pre-lifecycle startup window, keep the SDK's debounce, and be the callback
// the bootstrap actually installs.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/core/bootstrap/sentry_screenshot_gate.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  bool ask(AppLifecycleState? state, {bool debounce = false}) {
    final gate = foregroundOnlyScreenshots(lifecycleState: () => state);
    return gate(SentryEvent(), Hint(), debounce) as bool;
  }

  test('captures while resumed', () {
    expect(ask(AppLifecycleState.resumed), isTrue);
  });

  test('captures before the first lifecycle message (startup)', () {
    expect(ask(null), isTrue);
  });

  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    test('skips the capture when the app is ${state.name}', () {
      expect(ask(state), isFalse);
    });
  }

  test('keeps the SDK debounce: a debounced request is skipped', () {
    expect(ask(AppLifecycleState.resumed, debounce: true), isFalse);
  });

  test('reads the lifecycle state at capture time, not at build time', () {
    AppLifecycleState? state = AppLifecycleState.resumed;
    final gate = foregroundOnlyScreenshots(lifecycleState: () => state);
    expect(gate(SentryEvent(), Hint(), false), isTrue);
    state = AppLifecycleState.paused;
    expect(gate(SentryEvent(), Hint(), false), isFalse);
  });

  test('the bootstrap installs the gate next to attachScreenshot', () {
    final source = File(
      'lib/shared/core/bootstrap/bootstrap.dart',
    ).readAsStringSync();
    expect(source, contains('options.attachScreenshot = true;'));
    expect(
      source,
      contains('options.beforeCaptureScreenshot = foregroundOnlyScreenshots();'),
    );
  });
}
