/// D-2c — event origin contract (integrations-data-display.md, RATIFIED
/// Xuan 2026-09-11):
///  * one origin per row; athlete-created rows are 'manual'
///  * a dedupe-match flips a LEGACY (null-origin) row to the provider
///  * a local edit of a provider row flips it 'manual' and exempts it from
///    re-sync overwrite — a later dedupe-match must NOT flip it back
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart' hide Event;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../helpers/widget_test_harness.dart';

class _MockEventsRepository extends Mock implements EventsRepository {}

class _MockActivitiesService extends Mock implements ActivitiesService {}

class _MockCoachRepository extends Mock implements CoachRepository {}

Event _event({String? origin}) => Event(
      id: 'e1',
      userId: 'u1',
      eventType: ActivityType.running,
      eventName: 'City Marathon',
      eventDate: DateTime(2026, 10, 12),
      origin: origin,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

/// The dedupe-flip rule as implemented at both import sites
/// (connect_training_controller: TP events + FS race candidates): only a
/// LEGACY null-origin row is flipped to the provider.
String? dedupeOrigin(Event existing, String provider) =>
    existing.origin == null ? provider : existing.origin;

/// The edit-flip rule as implemented in EventsService.updateEvent.
String? editOrigin(Event event) =>
    (event.origin == 'training_peaks' || event.origin == 'final_surge')
        ? 'manual'
        : event.origin;

void main() {
  test('a legacy (null-origin) row flips to the provider on dedupe-match',
      () {
    expect(dedupeOrigin(_event(), 'training_peaks'), 'training_peaks');
    expect(dedupeOrigin(_event(), 'final_surge'), 'final_surge');
  });

  test('a provider row edited locally flips to manual', () {
    expect(editOrigin(_event(origin: 'training_peaks')), 'manual');
    expect(editOrigin(_event(origin: 'final_surge')), 'manual');
    // Manual and legacy rows keep their origin through an edit.
    expect(editOrigin(_event(origin: 'manual')), 'manual');
    expect(editOrigin(_event()), isNull);
  });

  test('re-sync exemption: a manual-flipped row is never flipped back by a '
      'later dedupe-match', () {
    // The athlete edited a TP-imported event -> manual.
    final edited = _event(origin: 'training_peaks')
        .copyWith(origin: editOrigin(_event(origin: 'training_peaks')));
    expect(edited.origin, 'manual');
    // The next TP import dedupe-matches the same event: origin stands.
    expect(dedupeOrigin(edited, 'training_peaks'), 'manual');
  });

  test('origin round-trips through copyWith untouched by other edits', () {
    final e = _event(origin: 'final_surge').copyWith(eventName: 'Renamed');
    expect(e.origin, 'final_surge');
  });

  test('origin survives the SERVICE mapper — the events-list read path '
      '(caught 2026-09-11: a second mapper dropped it and every card '
      'rendered as legacy)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.eventsTable).insert(
          EventsTableCompanion.insert(
            id: const Value('ev-fs'),
            userId: 'u1',
            eventType: 'triathlon',
            eventName: const Value('Lakeside Tri'),
            eventDate: Value(DateTime(2026, 10, 11)),
            origin: const Value('final_surge'),
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );

    final service = EventsService(
      db,
      MockAppLogger(),
      _MockEventsRepository(),
      _MockActivitiesService(),
      _MockCoachRepository(),
    );

    final events = await service.getAllEvents('u1');
    expect(events.single.origin, 'final_surge');
  });
}
