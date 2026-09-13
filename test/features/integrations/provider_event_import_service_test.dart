/// ProviderEventImportService — the ONE application-layer save site for
/// provider-imported events (TP events + FS race candidates), extracted
/// 2026-09-13 after the live probe showed the coordinator's background sync
/// fetching TP events and discarding them (ops bug
/// tp-background-sync-discards-imported-events): the only save code lived
/// in the presentation controller.
///
/// Runs against the REAL EventsRepository + Drift, pinning the dedupe and
/// D-2c origin rules on the shared path both sync routes now use.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/provider_event_import_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/widget_test_harness.dart';

class _MockCarbLoadingRepository extends Mock
    implements CarbLoadingRepository {}

void main() {
  const userId = 'u1';
  late AppDatabase db;
  late EventsRepository repo;
  late ProviderEventImportService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EventsRepository(
      supabase: fakeSupabaseClient(),
      database: db,
      logger: MockAppLogger(),
      carbLoadingRepository: _MockCarbLoadingRepository(),
      sentry: mockSentryReporter(),
    );
    service = ProviderEventImportService(
      eventsRepository: repo,
      logger: MockAppLogger(),
    );
  });

  tearDown(() async => db.close());

  TrainingPeaksEventResult tpEvent({String name = 'IM NC 70.3'}) =>
      TrainingPeaksEventResult(
        eventId: 'tp-1',
        eventDate: DateTime(2026, 10, 17),
        eventType: 'Triathlon',
        eventName: name,
      );

  Future<List<Event>> rows() => db.select(db.eventsTable).get();

  group('TrainingPeaks events', () {
    test('creates the event with origin training_peaks (the background-sync '
        'path the coordinator dropped)', () async {
      final saved = await service.importTrainingPeaksEvents(userId, [
        tpEvent(),
      ]);
      expect(saved, 1);

      final row = (await rows()).single;
      expect(row.eventName, 'IM NC 70.3');
      expect(row.origin, 'training_peaks');
      expect(row.startTime, isNotNull,
          reason: 'the events list buckets on start_time');
    });

    test('re-import dedupes — never a duplicate beside the first', () async {
      await service.importTrainingPeaksEvents(userId, [tpEvent()]);
      final second = await service.importTrainingPeaksEvents(userId, [
        tpEvent(),
      ]);
      expect(second, 0);
      expect((await rows()).length, 1);
    });

    test('D-2c: a LEGACY (null-origin) match flips to the provider; a '
        'manual match is exempt', () async {
      final now = DateTime(2026, 9, 1);
      await db.into(db.eventsTable).insert(
            EventsTableCompanion.insert(
              id: const Value('legacy'),
              userId: userId,
              eventType: 'triathlon',
              eventName: const Value('IM NC 70.3'),
              eventDate: Value(DateTime(2026, 10, 17)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.eventsTable).insert(
            EventsTableCompanion.insert(
              id: const Value('mine'),
              userId: userId,
              eventType: 'running',
              eventName: const Value('City Marathon'),
              eventDate: Value(DateTime(2026, 10, 12)),
              origin: const Value('manual'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await service.importTrainingPeaksEvents(userId, [
        tpEvent(),
        TrainingPeaksEventResult(
          eventId: 'tp-2',
          eventDate: DateTime(2026, 10, 12),
          eventType: 'Marathon',
          eventName: 'City Marathon',
        ),
      ]);

      final byId = {for (final r in await rows()) r.id: r};
      expect(byId['legacy']!.origin, 'training_peaks',
          reason: 'legacy row flips on dedupe-match');
      expect(byId['mine']!.origin, 'manual',
          reason: 'manual rows are athlete-owned — never flipped back');
      expect(byId.length, 2, reason: 'no duplicates created');
    });
  });

  group('Final Surge race candidates', () {
    test('creates with origin final_surge and dedupes on re-import',
        () async {
      final candidate = FinalSurgeRaceCandidate(
        providerWorkoutId: 'fs-w1',
        activityId: 'act-1',
        eventName: 'Lakeside Tri',
        scheduledAt: DateTime(2026, 10, 12),
        eventType: ActivityType.triathlon,
      );

      final first = await service.importFinalSurgeRaceCandidates(userId, [
        candidate,
      ]);
      expect(first, 1);
      final row = (await rows()).single;
      expect(row.origin, 'final_surge');
      expect(row.activityId, 'act-1');

      final second = await service.importFinalSurgeRaceCandidates(userId, [
        candidate,
      ]);
      expect(second, 0);
      expect((await rows()).length, 1);
    });
  });
}
