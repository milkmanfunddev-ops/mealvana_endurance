/// Testing-wave 28-004 (ticket 98, parts 2 and 3): a scanner with no camera
/// was a dead end. The no-camera and permission-denied states now say so in
/// the app's own words (content system) with a link back to search, and an
/// "Enter" control takes a typed barcode down the same lookup → confirm →
/// pop path a scan takes. The typed path is also what a simulator run can
/// drive end to end.
///
/// The screen is mounted through the app's own GoRoute
/// ([barcodeScannerRoute]) so `context.pop(food)` reaches the caller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/barcode_scanner_service.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../meal_planning/presentation/helpers/test_content.dart';
import '../fake_mobile_scanner_platform.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockBarcodeScannerService extends Mock
    implements BarcodeScannerService {}

const _nutella = Food(id: 'nutella', name: 'Nutella');

void main() {
  late FakeMobileScannerPlatform platform;
  late _MockAnalyticsTracker analytics;
  late _MockBarcodeScannerService scanner;
  late Map<String, String> content;

  /// What the scanner popped back to its caller, once it has.
  late List<Object?> popped;

  setUpAll(() => content = loadDefaultContent());

  setUp(() {
    platform = FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = platform;
    analytics = _MockAnalyticsTracker();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    scanner = _MockBarcodeScannerService();
    popped = [];
  });

  Future<void> openScanner(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await context.pushNamed<dynamic>(
                  'barcode-scanner',
                  extra: {
                    'category': 'add_food',
                    'context': 'meal_log_discover',
                  },
                );
                popped.add(result);
              },
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
          contentServiceProvider.overrideWith(testContentService),
          barcodeScannerServiceProvider.overrideWithValue(scanner),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('open scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The simulator's answer: the native start fails with no camera.
  Future<void> noCamera(WidgetTester tester) async {
    platform.failStartNoCamera();
    await tester.pump();
    await tester.pump();
  }

  group('no camera', () {
    testWidgets('the message is the app\'s own, with a link back to search', (
      tester,
    ) async {
      await openScanner(tester);
      await noCamera(tester);

      expect(find.text(content['barcode_scanner.no_camera']!), findsOneWidget);
      expect(find.textContaining('not supported'), findsNothing);
      expect(find.textContaining('No cameras available'), findsNothing);

      final link = find.byKey(const ValueKey('barcode.search_link'));
      expect(link, findsOneWidget);
      expect(
        find.descendant(
          of: link,
          matching: find.text(content['barcode_scanner.search_instead']!),
        ),
        findsOneWidget,
      );

      await tester.tap(link);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Back on the caller's search, with nothing to log.
      expect(find.text('open scanner'), findsOneWidget);
      expect(find.byKey(const ValueKey('barcode.title')), findsNothing);
      expect(popped, [null]);
    });

    testWidgets('a denied permission also says so in the app\'s words', (
      tester,
    ) async {
      await openScanner(tester);
      platform.failStart(
        const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
          errorDetails: MobileScannerErrorDetails(
            code: 'MOBILE_SCANNER_CAMERA_PERMISSION_DENIED',
            message: 'Camera permission denied.',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(content['barcode_scanner.permission_denied']!),
        findsOneWidget,
      );
      expect(find.textContaining('permission denied'), findsNothing);
      expect(find.byKey(const ValueKey('barcode.search_link')), findsOneWidget);
    });
  });

  group('Enter barcode', () {
    testWidgets('is a labelled control that is there without a camera', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openScanner(tester);
      await noCamera(tester);

      expect(
        tester.getSemantics(find.byKey(const ValueKey('barcode.enter_button'))),
        isSemantics(
          label: content['barcode_scanner.enter_label'],
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'a typed barcode runs the scan lookup and pops the food to the caller',
      (tester) async {
        when(() => scanner.scanBarcode('3017620422003')).thenAnswer(
          (_) async => const BarcodeScanResult.success(
            barcode: '3017620422003',
            food: _nutella,
            apiProduct: null,
          ),
        );
        await openScanner(tester);
        await noCamera(tester);

        await tester.tap(find.byKey(const ValueKey('barcode.enter_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          find.text(content['barcode_scanner.enter_title']!),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('barcode.enter_field')),
          '3017620422003',
        );
        await tester.tap(find.byKey(const ValueKey('barcode.enter_submit')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        verify(() => scanner.scanBarcode('3017620422003')).called(1);
        verify(
          () => analytics.track(
            'barcode_entered',
            properties: {
              'code': '3017620422003',
              'category': 'add_food',
              'context': 'meal_log_discover',
            },
          ),
        ).called(1);

        // Meal-log context: the same pop a scan does, straight to the caller.
        expect(popped, [_nutella]);
        expect(find.text('open scanner'), findsOneWidget);
      },
    );

    testWidgets('keeps only digits and ignores an empty entry', (tester) async {
      await openScanner(tester);
      await noCamera(tester);

      await tester.tap(find.byKey(const ValueKey('barcode.enter_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byKey(const ValueKey('barcode.enter_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Nothing looked up, sheet still open.
      verifyNever(() => scanner.scanBarcode(any()));
      expect(
        find.text(content['barcode_scanner.enter_title']!),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('barcode.enter_field')),
        '30 17-620 4220 03',
      );
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('barcode.enter_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '3017620422003');
    });
  });
}
