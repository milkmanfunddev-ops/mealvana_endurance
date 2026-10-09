// Ticket 81 (testing-wave develop-2026-10), Finding 69-003: on Edit Event, a
// location LocationIQ cannot match showed nothing and faulted to Sentry.
// Ruled (Lee 2026-10-09): copy that says what happened and what to do, under
// the field. The location stays free text: what was typed is saved.
//
// Seam: the real `locationServiceProvider` (real `LocationService`) over the
// real `LocationRepository` whose `client` getter answers with a mocktail
// client throwing the package's own exception types. Harness as
// `event_form_imported_without_distance_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:location_iq/location_iq.dart';
// The package exports no error or service types; the test throws the exact
// type the package throws.
// ignore: implementation_imports
import 'package:location_iq/src/core/error/exceptions.dart';
// ignore: implementation_imports
import 'package:location_iq/src/services/autocomplete/autocomplete.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';
import 'package:mealvana_endurance/shared/data/repositories/location_repository.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

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

class _RecordingEventsController extends EventsController {
  final updates = <Event>[];

  @override
  Future<List<Event>> build() async => const [];

  @override
  Future<void> updateEvent(Event event) async => updates.add(event);
}

final _event = Event(
  id: 'e-tw69',
  userId: 'u1',
  eventType: ActivityType.running,
  eventName: 'TW69 race',
  eventDate: DateTime(2026, 10, 17),
  startTime: DateTime(2026, 10, 17).toIso8601String(),
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

final _noMatchLine =
    loadDefaultContent()[ContentKeys.eventFormLocationNoMatch]!;

final _locationField = find.byKey(
  const ValueKey('event_create.location_field'),
);
final _line = find.byKey(const ValueKey('event_form.location_no_match'));

class _Harness {
  _Harness(this.controller, this.report, this.analytics);
  final _RecordingEventsController controller;
  final RecordingReport report;
  final RecordingAnalyticsTracker analytics;
}

Future<_Harness> _pump(WidgetTester tester, Object searchError) async {
  tester.view.physicalSize = standardPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = _RecordingEventsController();
  final report = RecordingReport();
  final analytics = RecordingAnalyticsTracker();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('host')),
        routes: [
          GoRoute(
            path: 'form',
            builder: (_, _) => EventFormScreen(event: _event),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        eventsControllerProvider.overrideWith(() => controller),
        contentServiceProvider.overrideWith(testContentService),
        reportProvider.overrideWithValue(report),
        analyticsTrackerProvider.overrideWithValue(analytics),
        locationRepositoryProvider.overrideWithValue(
          _ThrowingRepository(searchError),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/form');
  await tester.pumpAndSettle();
  return _Harness(controller, report, analytics);
}

/// Types [text] into Location and lets the 500 ms debounce fire.
Future<void> _typeAndSearch(WidgetTester tester, String text) async {
  await tester.ensureVisible(_locationField);
  await tester.tap(_locationField);
  await tester.enterText(_locationField, text);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

NotFoundException _noMatch() =>
    NotFoundException('No location found: {"error":"Unable to geocode"}');

void main() {
  testWidgets('a no-match shows the line under Location, and no dropdown', (
    tester,
  ) async {
    final h = await _pump(tester, _noMatch());
    // The form has its own tiles (Additional Details); a dropdown would add.
    final tilesBefore = find.byType(ListTile).evaluate().length;

    await _typeAndSearch(tester, 'tw69 unsaved');

    expect(
      _noMatchLine,
      'No matching places. Check the spelling, or keep what you typed.',
    );
    expect(_line, findsOneWidget);
    expect(find.text(_noMatchLine), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(tilesBefore));
    expect(h.report.faults.where((r) => r.area == 'location'), isEmpty);
    expect(
      h.analytics
          .findEvents(expectedFailureEvent)
          .map((e) => e.properties)
          .toList(),
      [
        {'area': 'location', 'reason': 'no_match'},
      ],
    );

    // Typing again clears the line while the next search waits.
    await tester.enterText(_locationField, 'tw69 unsaved x');
    await tester.pump();
    expect(_line, findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(_line, findsOneWidget);
  });

  testWidgets('a failed search shows no line', (tester) async {
    final h = await _pump(tester, ServerException('Internal Server Error: {}'));

    await _typeAndSearch(tester, 'Boston');

    expect(_line, findsNothing);
    expect(find.text(_noMatchLine), findsNothing);
    expect(h.report.faults.where((r) => r.area == 'location'), hasLength(1));
    expect(h.analytics.findEvents(expectedFailureEvent), isEmpty);
  });

  testWidgets('Save after a no-match keeps the typed text as the location', (
    tester,
  ) async {
    final h = await _pump(tester, _noMatch());

    await _typeAndSearch(tester, 'tw69 unsaved');
    expect(_line, findsOneWidget);

    final save = find.byKey(const ValueKey('event_create.create_button'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(h.controller.updates, hasLength(1));
    expect(h.controller.updates.single.location, 'tw69 unsaved');
  });
}
