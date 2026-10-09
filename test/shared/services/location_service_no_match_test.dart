// Ticket 81 (testing-wave develop-2026-10), Finding 69-003: a place search
// that LocationIQ cannot match (its 404 "Unable to geocode") faulted to
// Sentry and sent `error_reported`. Ruled (Lee 2026-10-09): it is an expected
// outcome, a `location` note plus one `expected_failure {location, no_match}`.
// A real failure keeps its fault and now answers null, so a screen can tell
// "nothing matched" ([]) from "the search failed" (null).
//
// Seam: the real `LocationRepository` (only its `client` getter is replaced)
// and the real `LocationService`. The client throws the package's own
// exception types with the producer's text from run 69.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:location_iq/location_iq.dart';
// The package exports no error or service types; the test throws the exact
// type the package throws.
// ignore: implementation_imports
import 'package:location_iq/src/core/error/exceptions.dart';
// ignore: implementation_imports
import 'package:location_iq/src/services/autocomplete/autocomplete.dart';
import 'package:mealvana_endurance/shared/data/repositories/location_repository.dart';
import 'package:mealvana_endurance/shared/services/location_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockClient extends Mock implements LocationIQClient {}

class _MockAutocomplete extends Mock implements AutocompleteService {}

/// The real repository over a client whose autocomplete throws [error].
class _ThrowingRepository extends LocationRepository {
  _ThrowingRepository(Object error) {
    final autocomplete = _MockAutocomplete();
    when(
      () => autocomplete.suggest(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => throw error);
    when(() => _client.autocomplete).thenReturn(autocomplete);
  }

  final _client = _MockClient();

  @override
  LocationIQClient get client => _client;
}

/// LocationIQ's 404 body for a no-match, as run 69 logged it.
NotFoundException _noMatch() =>
    NotFoundException('No location found: {"error":"Unable to geocode"}');

void main() {
  late RecordingReport report;
  late RecordingAnalyticsTracker analytics;

  setUp(() {
    report = RecordingReport();
    analytics = RecordingAnalyticsTracker();
  });

  LocationService service(Object error) => LocationService(
    report: report,
    locationRepository: _ThrowingRepository(error),
    analytics: analytics,
  );

  test('the repository names a 404 as no match', () async {
    await expectLater(
      _ThrowingRepository(_noMatch()).searchLocations('tw69 unsaved'),
      throwsA(
        isA<LocationNoMatchException>().having(
          (e) => e.query,
          'query',
          'tw69 unsaved',
        ),
      ),
    );
  });

  test('no match answers [] with a note and one expected_failure', () async {
    final results = await service(_noMatch()).searchLocations('tw69 unsaved');

    expect(results, isNotNull);
    expect(results, isEmpty);
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    expect(report.notes, hasLength(1));
    expect(report.notes.single.area, 'location');
    expect(report.notes.single.data, {'expected_failure': 'no_match'});

    final counted = analytics.findEvents(expectedFailureEvent);
    expect(counted, hasLength(1));
    expect(counted.single.properties, {
      'area': 'location',
      'reason': 'no_match',
    });
    expect(analytics.findEvents(errorReportedEvent), isEmpty);
  });

  test('a server error answers null with one fault and no count', () async {
    final results = await service(
      ServerException('Internal Server Error: {}'),
    ).searchLocations('Boston');

    expect(results, isNull);
    expect(report.faults, hasLength(1));
    expect(report.faults.single.area, 'location');
    expect(report.notes, isEmpty);
    expect(analytics.findEvents(expectedFailureEvent), isEmpty);
  });

  test('a plain exception answers null with one fault and no count', () async {
    final results = await service(
      Exception('socket closed'),
    ).searchLocations('Boston');

    expect(results, isNull);
    expect(report.faults, hasLength(1));
    expect(report.faults.single.area, 'location');
    expect(analytics.findEvents(expectedFailureEvent), isEmpty);
  });
}
