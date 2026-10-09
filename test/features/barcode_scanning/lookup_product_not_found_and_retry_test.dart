/// Ticket 79 (testing-wave develop-2026-10), Findings 68-007 and 68-018.
///
/// 68-007: lookup-product's 404 for an unknown code fell into
/// [ProductDetailService]'s catch-all: a fault, then a second degraded in
/// [SupabaseBarcodeService], and the "Unable to connect" dialog. Now it is
/// [ProductNotFoundException], one `expected_failure {barcode_scanning,
/// barcode_not_found}`, and `BarcodeResultNotFound` with nothing more
/// reported.
///
/// 68-018: the first lookup hung ~30 s on the OS connect timeout. Each
/// attempt is now bounded at [ProductDetailService.lookupTimeout] (10 s), and
/// a transport failure (no answer) is tried once more. An HTTP answer is
/// never retried.
///
/// Seam: the real services over a mocktail [FunctionsClient]. The 404 body is
/// copied from `supabase/functions/lookup-product/index.ts` (the
/// `!productData` branch), as the supabase client raises it.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mealvana_endurance/features/barcode_scanning/application/product_detail_service.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/supabase_barcode_service.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/barcode_result.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

const _unknown = '98765432109871';

/// lookup-product/index.ts, no product found, as FunctionException.
const _notFound404 = FunctionException(
  status: 404,
  details: {
    'success': false,
    'error': 'Product not found in Open Food Facts database',
    'message':
        'Unable to find product details. Please try a different product or '
        'scan a barcode.',
  },
  reasonPhrase: 'Not Found',
);

const _server500 = FunctionException(
  status: 500,
  details: {'success': false, 'error': 'boom'},
  reasonPhrase: 'Internal Server Error',
);

final _ok = FunctionResponse(
  status: 200,
  data: {
    'success': true,
    'source': 'cache',
    'product': {
      'barcode': '12345670',
      'product_name': 'McEnnedy Double burger',
      'api_source': 'open_food_facts',
    },
  },
);

void main() {
  late _MockFunctionsClient functions;
  late RecordingReport report;
  late RecordingAnalyticsTracker analytics;
  late ProductDetailService service;
  late SupabaseBarcodeService barcodeService;

  setUp(() {
    functions = _MockFunctionsClient();
    final client = _MockSupabaseClient();
    when(() => client.functions).thenReturn(functions);
    report = RecordingReport();
    analytics = RecordingAnalyticsTracker();
    service = ProductDetailService(
      client,
      report: report,
      analytics: analytics,
    );
    barcodeService = SupabaseBarcodeService(
      productDetailService: service,
      report: report,
    );
  });

  void answer(List<Future<FunctionResponse> Function()> attempts) {
    var i = 0;
    when(
      () => functions.invoke('lookup-product', body: any(named: 'body')),
    ).thenAnswer((_) => attempts[i++]());
  }

  int invokeCalls() => verify(
    () => functions.invoke('lookup-product', body: any(named: 'body')),
  ).callCount;

  List<RecordedReport> breadcrumbs() =>
      report.calls.where((c) => c.severity == 'breadcrumb').toList();

  group('404 not found', () {
    test('ProductNotFoundException, one expected_failure, no fault', () async {
      answer([() async => throw _notFound404]);

      await expectLater(
        () => service.getProductDetails(barcode: _unknown),
        throwsA(isA<ProductNotFoundException>()),
      );
      expect(invokeCalls(), 1, reason: 'an HTTP answer is final');
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(report.notes.single.area, 'barcode_scanning');
      expect(report.notes.single.data, {
        'expected_failure': 'barcode_not_found',
        'status': 404,
      });
      expect(analytics.findEvents(expectedFailureEvent).single.properties, {
        'area': 'barcode_scanning',
        'reason': 'barcode_not_found',
      });
    });

    test('lookupBarcode returns BarcodeResultNotFound and reports nothing '
        'more', () async {
      answer([() async => throw _notFound404]);

      final result = await barcodeService.lookupBarcode(_unknown);

      expect(result, isA<BarcodeResultNotFound>());
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(report.notes, hasLength(1));
      expect(analytics.findEvents(expectedFailureEvent), hasLength(1));
    });

    test(
      'isNotFoundAnswer keys on 404 and success: false (a gateway 404 is not one)',
      () {
        expect(ProductDetailService.isNotFoundAnswer(_notFound404), isTrue);
        expect(
          ProductDetailService.isNotFoundAnswer(
            const FunctionException(status: 404, details: 'Not Found'),
          ),
          isFalse,
        );
      },
    );
  });

  group('bounded wait, one retry', () {
    testWidgets('first attempt never answers, the second answers 200: two '
        'calls, a product, one retry breadcrumb, no report', (tester) async {
      final hung = Completer<FunctionResponse>();
      answer([() => hung.future, () async => _ok]);

      final pending = service.getProductDetails(barcode: '12345670');
      await tester.pump(ProductDetailService.lookupTimeout);
      final product = await pending;

      expect(product!.productName, 'McEnnedy Double burger');
      expect(invokeCalls(), 2);
      expect(breadcrumbs().single.message, contains('retrying once'));
      expect(breadcrumbs().single.data, {'error': 'TimeoutException'});
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(report.notes, isEmpty);
      expect(analytics.findEvents(expectedFailureEvent), isEmpty);
      // The first attempt's timer fired at 10 s and the second's was
      // cancelled when it answered; nothing is left pending (#110).
      hung.complete(_ok);
    });

    test('two SocketExceptions: exactly two calls, '
        'ProductLookupUnavailableException, weather breadcrumb and a count, '
        'no fault', () async {
      answer([
        () async => throw const SocketException('Network is unreachable'),
        () async => throw const SocketException('Network is unreachable'),
      ]);

      await expectLater(
        () => service.getProductDetails(barcode: '12345670'),
        throwsA(isA<ProductLookupUnavailableException>()),
      );
      expect(invokeCalls(), 2);
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      final weather = breadcrumbs()
          .where((c) => c.area == 'barcode_scanning.weather')
          .toList();
      expect(weather, hasLength(1));
      expect(weather.single.data!['expected_failure'], 'offline');
      expect(analytics.findEvents(expectedFailureEvent).single.properties, {
        'area': 'barcode_scanning',
        'reason': 'offline',
      });
    });

    test('lookupBarcode on two transport failures: BarcodeResultError, no '
        'second degraded', () async {
      // As run 68's console had it: the socket error wrapped by package:http.
      final wrapped = http.ClientException(
        'SocketException: Operation timed out (errno = 60)',
        Uri.parse('https://example.supabase.co/functions/v1/lookup-product'),
      );
      answer([() async => throw wrapped, () async => throw wrapped]);

      final result = await barcodeService.lookupBarcode('12345670');

      expect(result, isA<BarcodeResultError>());
      expect(invokeCalls(), 2);
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(analytics.findEvents(expectedFailureEvent), hasLength(1));
    });

    test('a 500 is not retried and faults as before', () async {
      answer([() async => throw _server500]);

      await expectLater(
        () => service.getProductDetails(barcode: '12345670'),
        throwsA(
          isA<ProductDetailException>()
              .having(
                (e) => e,
                'not a subclass',
                isNot(isA<ProductNotFoundException>()),
              )
              .having(
                (e) => e,
                'not unavailable',
                isNot(isA<ProductLookupUnavailableException>()),
              ),
        ),
      );
      expect(invokeCalls(), 1);
      expect(report.faults, hasLength(1));
      expect(report.faults.single.area, 'barcode_scanning');
      expect(analytics.findEvents(expectedFailureEvent), isEmpty);
    });
  });
}
