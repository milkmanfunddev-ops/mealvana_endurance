// Ticket 80 (round develop-2026-10, Finding 69-004): an imported
// TrainingPeaks event could not be edited. The import never sets a race
// distance, and Save Changes refused with "Please select a race distance".
// Ruled (Lee 2026-10-09): an event stored without a distance keeps an empty
// distance as valid on save, while its sport stays the stored one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/calendar/presentation/widgets/event_subtype_dropdown.dart';
import 'package:mealvana_endurance/features/calendar/presentation/widgets/sport_category_selector.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

const _distanceError = 'Please select a race distance';

/// The row as the TrainingPeaks import stores it (run 69's "IM NC 70.3"):
/// no distance, no location, `startTime` = local midnight with no zone.
final _imported = Event(
  id: 'e-imnc',
  userId: 'u1',
  eventType: ActivityType.triathlon,
  eventName: 'IM NC 70.3',
  eventDate: DateTime(2026, 10, 17),
  startTime: DateTime(2026, 10, 17).toIso8601String(),
  origin: 'training_peaks',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

class _RecordingEventsController extends EventsController {
  final updates = <Event>[];
  final creates = <String?>[];

  @override
  Future<List<Event>> build() async => const [];

  @override
  Future<void> updateEvent(Event event) async => updates.add(event);

  @override
  Future<String> createEvent({
    String? activityId,
    String? forUserId,
    required ActivityType eventType,
    String? eventSubtype,
    String? eventName,
    String? location,
    String? registrationUrl,
    String? startTime,
    int? goalTimeMinutes,
    double? goalPaceMinutesPerMile,
    int? predictedFinishTimeMinutes,
    bool? hasCarbLoading,
    int? carbLoadingDays,
    DateTime? carbLoadingStartDate,
    String? bibNumber,
    String? waveStartTime,
    String? packetPickupInfo,
  }) async {
    creates.add(eventSubtype);
    return 'new-id';
  }
}

Future<_RecordingEventsController> _pump(
  WidgetTester tester, {
  Event? event,
}) async {
  tester.view.physicalSize = standardPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = _RecordingEventsController();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('host')),
        routes: [
          GoRoute(
            path: 'form',
            builder: (_, _) => EventFormScreen(event: event),
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
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/form');
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('event_create.create_button'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('an imported event with no distance saves a Location edit '
      'with the distance still empty', (tester) async {
    final controller = await _pump(tester, event: _imported);

    await tester.enterText(
      find.byKey(const ValueKey('event_create.location_field')),
      'Raleigh, North Carolina',
    );
    // Let the location search debounce run out (#110: no pending timer).
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.text(_distanceError), findsNothing);
    expect(controller.updates, hasLength(1));
    final saved = controller.updates.single;
    expect(saved.eventSubtype, isNull);
    expect(saved.location, 'Raleigh, North Carolina');
    await tester.pumpAndSettle();
  });

  testWidgets('changing the sport category preselects a distance (today\'s '
      'reset)', (tester) async {
    final controller = await _pump(tester, event: _imported);

    final run = find.descendant(
      of: find.byType(SportCategorySelector),
      matching: find.text(ActivityType.running.displayName),
    );
    await tester.ensureVisible(run);
    await tester.pumpAndSettle();
    await tester.tap(run);
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.text(_distanceError), findsNothing);
    expect(controller.updates, hasLength(1));
    expect(controller.updates.single.eventType, ActivityType.running);
    expect(controller.updates.single.eventSubtype, isNotNull);
    await tester.pumpAndSettle();
  });

  testWidgets('a stored distance still saves as stored', (tester) async {
    final controller = await _pump(
      tester,
      event: _imported.copyWith(eventSubtype: 'half_ironman'),
    );
    await _save(tester);
    expect(controller.updates.single.eventSubtype, 'half_ironman');
    await tester.pumpAndSettle();
  });

  group('EventSubtypeDropdown.isRequired', () {
    Future<String?> validate(WidgetTester tester, {bool? isRequired}) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: isRequired == null
                  ? EventSubtypeDropdown(
                      sportCategory: ActivityType.triathlon,
                      selectedSubtype: null,
                      onSubtypeChanged: (_) {},
                    )
                  : EventSubtypeDropdown(
                      sportCategory: ActivityType.triathlon,
                      selectedSubtype: null,
                      onSubtypeChanged: (_) {},
                      isRequired: isRequired,
                    ),
            ),
          ),
        ),
      );
      formKey.currentState!.validate();
      await tester.pump();
      return find.text(_distanceError).evaluate().isEmpty
          ? null
          : _distanceError;
    }

    testWidgets('create mode (the default) still refuses an empty distance',
        (tester) async {
      expect(await validate(tester), _distanceError);
    });

    testWidgets('not required: an empty distance passes', (tester) async {
      expect(await validate(tester, isRequired: false), isNull);
    });
  });
}
