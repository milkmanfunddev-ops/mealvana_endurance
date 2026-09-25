/// Finding 28-002: the `/barcode-scanner` route dropped `extra['context']`,
/// so a scan from meal logging logged `context: null` and went to the
/// nutrition plan's food page. These tests mount the app's own GoRoute
/// ([barcodeScannerRoute] from app_router.dart) and push it with the exact
/// extras the meal-logging callers send.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_mobile_scanner_platform.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late _MockAnalyticsTracker analytics;

  setUp(() {
    MobileScannerPlatform.instance = FakeMobileScannerPlatform();
    analytics = _MockAnalyticsTracker();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  Future<void> openScannerWith(
    WidgetTester tester,
    Map<String, dynamic> extra,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  context.pushNamed('barcode-scanner', extra: extra),
              child: const Text('open scanner'),
            ),
          ),
        ),
        barcodeScannerRoute,
      ],
    );
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('open scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Map<String, dynamic>? openedProperties() {
    final captured = verify(
      () => analytics.track(
        'barcode_scanner_opened',
        properties: captureAny(named: 'properties'),
      ),
    ).captured;
    return captured.single as Map<String, dynamic>?;
  }

  testWidgets('Log a Meal: barcode_scanner_opened logs meal_log_discover', (
    tester,
  ) async {
    // The extra log_meal_screen._onBarcodeScan pushes.
    await openScannerWith(tester, {
      'category': 'add_food',
      'context': 'meal_log_discover',
    });

    expect(openedProperties(), {
      'category': 'add_food',
      'context': 'meal_log_discover',
    });
  });

  testWidgets('Build a Meal: barcode_scanner_opened logs build_meal_add_food', (
    tester,
  ) async {
    // The extra build_meal_screen pushes from + Add food.
    await openScannerWith(tester, {
      'category': 'add_food',
      'context': 'build_meal_add_food',
    });

    expect(openedProperties(), {
      'category': 'add_food',
      'context': 'build_meal_add_food',
    });
  });

  testWidgets('a plan caller with no context still logs context null', (
    tester,
  ) async {
    await openScannerWith(tester, {'category': 'before_run'});

    expect(openedProperties(), {'category': 'before_run', 'context': null});
  });
}
