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
import 'package:mealvana_endurance/features/events/domain/event_origin.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Event;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';


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

/// TrainingPeaks' import as it stores the row (provider_event_import_service):
/// `startTime` is `eventDate.toIso8601String()`, local midnight with no `Z`.
Event _tpImport() => Event(
  id: 'e-tp',
  userId: 'u1',
  eventType: ActivityType.triathlon,
  eventName: 'IM NC 70.3',
  eventDate: DateTime(2026, 10, 17),
  startTime: DateTime(2026, 10, 17).toIso8601String(),
  goalTimeMinutes: 330,
  origin: 'training_peaks',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

/// What the edit form sends back for [stored]: it parses `startTime` and
/// re-serialises it (`_startTime!.toIso8601String()`) and trims the name.
Event _formRoundTrip(Event stored) => stored.copyWith(
  eventName: stored.eventName!.trim(),
  startTime: DateTime.parse(stored.startTime!).toIso8601String(),
);

/// The real rule (EventsService.updateEvent -> originAfterEdit) for an edit
/// made through the form.
String? _editOrigin(Event stored, Event Function(Event) edit) =>
    originAfterEdit(before: stored, after: edit(_formRoundTrip(stored)));

void main() {
  test('a legacy (null-origin) row flips to the provider on dedupe-match', () {
    expect(dedupeOrigin(_event(), 'training_peaks'), 'training_peaks');
    expect(dedupeOrigin(_event(), 'final_surge'), 'final_surge');
  });

  test('ticket 80: an edit of fields the athlete owns keeps the provider '
      'origin', () {
    final tp = _tpImport();
    expect(_editOrigin(tp, (e) => e), 'training_peaks',
        reason: 'the form round trip alone changes nothing');
    expect(
      _editOrigin(tp, (e) => e.copyWith(location: 'Raleigh, North Carolina')),
      'training_peaks',
    );
    expect(_editOrigin(tp, (e) => e.copyWith(bibNumber: '1234')),
        'training_peaks');
    expect(_editOrigin(tp, (e) => e.copyWith(eventSubtype: 'half_ironman')),
        'training_peaks');
  });

  test('ticket 80: an edit of a field the sync owns flips to manual', () {
    final tp = _tpImport();
    expect(_editOrigin(tp, (e) => e.copyWith(eventName: 'IM NC')), 'manual');
    expect(
      _editOrigin(
        tp,
        (e) => e.copyWith(startTime: DateTime(2026, 10, 18).toIso8601String()),
      ),
      'manual',
      reason: 'date',
    );
    expect(
      _editOrigin(
        tp,
        (e) => e.copyWith(
          startTime: DateTime(2026, 10, 17, 7).toIso8601String(),
        ),
      ),
      'manual',
      reason: 'start time on the same day',
    );
    expect(
      _editOrigin(tp, (e) => e.copyWith(eventType: ActivityType.running)),
      'manual',
    );
    expect(_editOrigin(tp, (e) => e.copyWith(goalTimeMinutes: 320)), 'manual');
    // TrainingPeaks does not own goal pace.
    expect(
      _editOrigin(tp, (e) => e.copyWith(goalPaceMinutesPerMile: 9.0)),
      'training_peaks',
    );
  });

  test('ticket 80: Final Surge also owns goal pace and the linked activity',
      () {
    final fs = _tpImport().copyWith(
      origin: 'final_surge',
      activityId: 'act-fs',
      goalPaceMinutesPerMile: 8.123,
    );
    expect(_editOrigin(fs, (e) => e.copyWith(location: 'Raleigh')),
        'final_surge');
    // The form stores pace as minutes + whole seconds / 60: 8.123 comes back
    // as 8 min 7 s, the same pace to the second.
    expect(
      _editOrigin(fs, (e) => e.copyWith(goalPaceMinutesPerMile: 8 + 7 / 60)),
      'final_surge',
    );
    expect(
      _editOrigin(fs, (e) => e.copyWith(goalPaceMinutesPerMile: 8.5)),
      'manual',
    );
    expect(_editOrigin(fs, (e) => e.copyWith(activityId: 'act-other')),
        'manual');
  });

  test('manual and legacy rows keep their origin through any edit', () {
    final manual = _tpImport().copyWith(origin: 'manual');
    expect(_editOrigin(manual, (e) => e.copyWith(eventName: 'X')), 'manual');
    final legacy = _event();
    expect(
      originAfterEdit(before: legacy, after: legacy.copyWith(eventName: 'X')),
      isNull,
    );
  });

  test('re-sync exemption: a manual-flipped row is never flipped back by a '
      'later dedupe-match', () {
    // The athlete renamed a TP-imported event -> manual.
    final stored = _tpImport();
    final edited = stored.copyWith(
      eventName: 'Renamed',
      origin: _editOrigin(stored, (e) => e.copyWith(eventName: 'Renamed')),
    );
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

    await db
        .into(db.eventsTable)
        .insert(
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
      _MockEventsRepository(),
      _MockActivitiesService(),
      _MockCoachRepository(),
    );

    final events = await service.getAllEvents('u1');
    expect(events.single.origin, 'final_surge');
  });
}
