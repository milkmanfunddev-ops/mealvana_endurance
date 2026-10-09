/// Ticket 79 (testing-wave develop-2026-10), Finding 68-007: a typed unknown
/// barcode showed "Error / Unable to connect to product lookup service". The
/// service now answers lookup-product's 404 with a not-found result, and the
/// not-found dialog's title and body come from content
/// (`barcode_scanner.not_found_title`, `barcode_scanner.not_found_body`), not
/// from the service's message.
///
/// Also 79 Q1 (Lee, 2026-10-09): Try Again on the "Error" dialog looks the
/// same code up again instead of sending the athlete back to the scanner.
///
/// Harness: barcode_scanner_manual_entry_test.dart's (the app's own GoRoute,
/// a mocked [BarcodeScannerService], the real content JSON).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/barcode_scanner_service.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/test_content.dart';
import '../fake_mobile_scanner_platform.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockBarcodeScannerService extends Mock
    implements BarcodeScannerService {}

const _unknown = '98765432109871';

void main() {
  late FakeMobileScannerPlatform platform;
  late _MockAnalyticsTracker analytics;
  late _MockBarcodeScannerService scanner;
  late Map<String, String> content;

  setUpAll(() => content = loadDefaultContent());

  setUp(() {
    platform = FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = platform;
    analytics = _MockAnalyticsTracker();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    scanner = _MockBarcodeScannerService();
    when(
      () => scanner.trackBarcodeEntered(
        any(),
        category: any(named: 'category'),
        context: any(named: 'context'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> openScanner(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushNamed<dynamic>(
                'barcode-scanner',
                extra: {'category': 'add_food', 'context': 'meal_log_discover'},
              ),
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
              sharedPreferences: _MockSharedPreferences(),
            ),
          ),
          contentServiceProvider.overrideWith(testContentService),
          barcodeScannerServiceProvider.overrideWithValue(scanner),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('open scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // No camera (the simulator): the native start fails.
    platform.failStartNoCamera();
    await tester.pump();
    await tester.pump();
  }

  Future<void> enterAndLookUp(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(const ValueKey('barcode.enter_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(
      find.byKey(const ValueKey('barcode.enter_field')),
      code,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('barcode.enter_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('an unknown typed code: the not-found dialog in content words, '
      'with Try Another / Cancel / Create Manually, tracked not_found', (
    tester,
  ) async {
    when(() => scanner.scanBarcode(_unknown)).thenAnswer(
      (_) async => const BarcodeScanResult.notFound(
        barcode: _unknown,
        message: 'service debug text',
      ),
    );
    await openScanner(tester);
    await enterAndLookUp(tester, _unknown);

    expect(content['barcode_scanner.not_found_title'], 'Product Not Found');
    expect(
      find.text(content['barcode_scanner.not_found_title']!),
      findsOneWidget,
    );
    expect(
      find.text(content['barcode_scanner.not_found_body']!),
      findsOneWidget,
    );
    expect(find.text('service debug text'), findsNothing);
    expect(find.textContaining('Unable to connect'), findsNothing);
    expect(find.text('Try Another'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create Manually'), findsOneWidget);
    verify(
      () => analytics.track(
        'barcode_lookup_failed',
        properties: {
          'reason': 'not_found',
          'code': _unknown,
          'category': 'add_food',
          'context': 'meal_log_discover',
        },
      ),
    ).called(1);
  });

  testWidgets('Try Again on the error dialog looks the same code up again '
      '(79 Q1)', (tester) async {
    var calls = 0;
    when(() => scanner.scanBarcode('12345670')).thenAnswer((_) async {
      calls++;
      return const BarcodeScanResult.error(
        barcode: '12345670',
        message: 'Unable to connect to product lookup service',
      );
    });
    await openScanner(tester);
    await enterAndLookUp(tester, '12345670');

    expect(calls, 1);
    expect(
      find.text('Unable to connect to product lookup service'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(calls, 2, reason: 'no retyping: the same code is looked up');
    // The second answer shows the dialog again, once.
    expect(
      find.text('Unable to connect to product lookup service'),
      findsOneWidget,
    );
  });
}
