/// The typed-barcode event (testing-wave 28-004) lives in the scanner
/// service, not the screen (CLAUDE.md: analytics in controllers/services).
/// Same event name and payload the screen used to send; a failing tracker
/// is reported (D9) and never thrown at the lookup.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/barcode_scanner_service.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/food_mapping_service.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/supabase_barcode_service.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockReport extends Mock implements Report {}

class _MockSupabaseBarcodeService extends Mock
    implements SupabaseBarcodeService {}

class _MockFoodMappingService extends Mock implements FoodMappingService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late _MockAnalyticsTracker analytics;
  late _MockReport report;
  late BarcodeScannerService service;

  setUpAll(() => registerFallbackValue(StackTrace.empty));

  setUp(() {
    analytics = _MockAnalyticsTracker();
    report = _MockReport();
    when(
      () => report.degraded(
        any(),
        stackTrace: any(named: 'stackTrace'),
        area: any(named: 'area'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async {});
    service = BarcodeScannerService(
      barcodeService: _MockSupabaseBarcodeService(),
      mappingService: _MockFoodMappingService(),
      database: _MockAppDatabase(),
      report: report,
      analytics: analytics,
    );
  });

  test('sends barcode_entered with the code, category and context', () async {
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    await service.trackBarcodeEntered(
      '3017620422003',
      category: 'add_food',
      context: 'meal_log_discover',
    );

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
    verifyNever(
      () => report.degraded(
        any(),
        stackTrace: any(named: 'stackTrace'),
        area: any(named: 'area'),
        message: any(named: 'message'),
      ),
    );
  });

  test('a failing tracker is reported, not thrown', () async {
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenThrow(StateError('mixpanel down'));

    await service.trackBarcodeEntered('12345678', category: 'add_food');

    verify(
      () => report.degraded(
        any(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        area: 'barcode_scanning',
        message: 'barcode_entered analytics event failed',
      ),
    ).called(1);
  });
}
