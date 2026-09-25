/// Finding 28-001: granting camera access on the scanner's first open left
/// mobile_scanner's raw "The MobileScannerController is already running"
/// error on screen, and Reset could not clear it.
///
/// The permission alert makes the app inactive and then resumed; the resume
/// started the scanner a second time. On a device without a camera (the
/// simulator) the first native start fails but leaves its capture session
/// open, so the second start answers "already started" and that replaces the
/// first error. [FakeMobileScannerPlatform] behaves like that native side.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fake_mobile_scanner_platform.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late FakeMobileScannerPlatform platform;

  setUp(() {
    platform = FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = platform;
  });

  Future<void> pumpScanner(WidgetTester tester) async {
    final analytics = _MockAnalyticsTracker();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: _MockSupabaseClient(),
              sentry: _MockSentryReporter(),
              logger: _MockAppLogger(),
              sharedPreferences: _MockSharedPreferences(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: BarcodeScannerScreen(
            category: 'add_food',
            context: 'meal_log_discover',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The camera-permission alert: iOS makes the app inactive while it shows,
  /// then resumed after the athlete taps Allow.
  Future<void> permissionAlertComesAndGoes(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  Finder rawPackageText() => find.textContaining('MobileScannerController');
  Finder rawNativeText() => find.textContaining('already started');

  testWidgets('a resume during the first start waits for it: one native start, '
      'no raw controller error', (tester) async {
    await pumpScanner(tester);
    expect(platform.startCalls, 1);

    // Alert shows and is answered while the first start is still waiting.
    await permissionAlertComesAndGoes(tester);
    platform.finishStart();
    await tester.pump();
    await tester.pump();

    expect(platform.startCalls, 1);
    expect(rawPackageText(), findsNothing);
    expect(rawNativeText(), findsNothing);
  });

  testWidgets(
    'no camera (simulator): the resume after a failed first start does not '
    'start again, and the screen says so in plain words',
    (tester) async {
      await pumpScanner(tester);

      // The first start ends with no camera before the resume arrives.
      platform.failStartNoCamera();
      await tester.pump();
      await permissionAlertComesAndGoes(tester);
      await tester.pump();

      expect(platform.startCalls, 1);
      expect(rawPackageText(), findsNothing);
      expect(rawNativeText(), findsNothing);
      expect(find.byKey(const ValueKey('barcode.error')), findsOneWidget);
      expect(find.textContaining("camera we can use"), findsOneWidget);

      // Reset used to hit "already started" too.
      await tester.tap(find.byKey(const ValueKey('barcode.reset_button')));
      await tester.pump();
      await tester.pump();

      expect(platform.startCalls, 1);
      expect(rawPackageText(), findsNothing);
      expect(rawNativeText(), findsNothing);
    },
  );

  testWidgets(
    'the camera stopped for the app going inactive starts again on resume',
    (tester) async {
      await pumpScanner(tester);
      platform.finishStart();
      await tester.pump();
      expect(platform.sessionOpen, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(platform.sessionOpen, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(platform.startCalls, 2);
      platform.finishStart();
      await tester.pump();

      expect(rawPackageText(), findsNothing);
      expect(find.byKey(const ValueKey('barcode.error')), findsNothing);
    },
  );

  testWidgets(
    'if the platform still reports "already running", the athlete sees '
    'plain words, not the package text',
    (tester) async {
      // A native session left open from somewhere else.
      platform.sessionOpen = true;
      await pumpScanner(tester);
      await tester.pump();

      expect(rawPackageText(), findsNothing);
      expect(rawNativeText(), findsNothing);
      expect(find.byKey(const ValueKey('barcode.error')), findsOneWidget);
    },
  );

  /// Testing-wave 28-006: flash, Reset and Switch were not exposed as
  /// buttons; only the "Reset" and "Switch" captions read, as text.
  testWidgets('flash, Reset and Switch are labelled buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScanner(tester);
    platform.finishStart();
    await tester.pump();

    for (final (key, label) in [
      ('barcode.flash_button', 'Flash'),
      ('barcode.reset_button', 'Reset'),
      ('barcode.switch_button', 'Switch'),
    ]) {
      expect(
        tester.getSemantics(find.byKey(ValueKey(key))),
        isSemantics(label: label, isButton: true, hasTapAction: true),
        reason: key,
      );
    }
    handle.dispose();
  });
}
