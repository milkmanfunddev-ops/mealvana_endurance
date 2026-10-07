// DEV-99 (round-up 2026-10): "Exception: Failed to retrieve updated carb
// loading day" from CarbLoadingController.updateDayTarget.
//
// The event's trail (1.27.1+4, 2026-09-25): a 2-day plan created, then a
// re-pick (`DELETE carb_loading_days id=in.(9a6c0a0f…)`, plan + days
// upserted), then 8 s later the Edit Target dialog saved, and the update
// found no local row. The plan summary had kept the days list it read
// BEFORE the re-pick and offered the dropped day for editing.
//
// applyRepickProtocol invalidated only itself and the range family; the
// summary's plan and days-for-plan families refreshed only when the
// controller's rebuild finished a background sync and called
// `_invalidateCarbSurfaces`. Any sync still on the network left the summary
// stale for exactly that long. The G24 test passes because its sync settles
// inside the same pump; here the sync is held in flight, as on a phone.
//
// Real controller, real service and repository, in-memory Drift. The only
// fake is the sync coordinator, held mid-sync.
import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockCoachRepository extends Mock implements CoachRepository {}

class _MockEventsRepository extends Mock implements EventsRepository {}

/// A background sync that is still on the network.
class _InFlightSync extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) => Completer<void>().future;
}

const _userId = 'user-dev99';
const _eventId = 'event-dev99';
const _weightLb = 149.9;

void main() {
  test('after a re-pick drops a day, the plan summary no longer offers it, '
      'so every day it offers can be edited (DEV-99)', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final report = RecordingReport();
    final eventsRepo = _MockEventsRepository();
    when(
      () => eventsRepo.uploadDirtyRecords(any()),
    ).thenAnswer((_) async => UploadResult.nothingToUpload());
    final repository = CarbLoadingRepository(
      supabase: _MockSupabaseClient(),
      database: db,
      report: report,
    );
    final service = CarbLoadingService(
      db,
      report,
      repository,
      _MockCoachRepository(),
      eventsRepo,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Same shape as G24: a 2-day plan, race tomorrow, re-picked to 1 day.
    final race = today.add(const Duration(days: 1));
    await db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            id: const Value(_eventId),
            userId: _userId,
            eventType: 'running',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await service.createCarbLoadingPlan(
      deviceId: _userId,
      userId: _userId,
      eventId: _eventId,
      protocolDays: 2,
      raceDate: race,
      bodyWeightPounds: _weightLb,
    );

    final container = ProviderContainer(
      overrides: [
        carbLoadingServiceProvider.overrideWithValue(service),
        carbLoadingRepositoryProvider.overrideWithValue(repository),
        userIdProvider.overrideWith((ref) async => _userId),
        syncCoordinatorProvider.overrideWith(_InFlightSync.new),
        reportProvider.overrideWithValue(report),
      ],
    );
    addTearDown(container.dispose);

    // The plan summary is open: it watches the plan and its days.
    final plan = await service.getCarbLoadingPlan(_eventId);
    final planId = (plan as dynamic).id as String;
    container.listen(carbLoadingPlanProvider(_eventId), (_, _) {});
    container.listen(carbLoadingDaysForPlanProvider(planId), (_, _) {});
    final before = await container.read(
      carbLoadingDaysForPlanProvider(planId).future,
    );
    expect(before, hasLength(2));

    await container
        .read(carbLoadingControllerProvider.notifier)
        .applyRepickProtocol(
          eventId: _eventId,
          targetProtocolDays: 1,
          raceDate: race,
          bodyWeightPounds: _weightLb,
          keepEdits: false,
        );

    final offered = await container.read(
      carbLoadingDaysForPlanProvider(planId).future,
    );
    expect(
      offered,
      hasLength(1),
      reason: 'the dropped day must leave the summary with the re-pick',
    );

    // The athlete edits every day the summary offers: each one exists.
    for (final day in offered) {
      await container
          .read(carbLoadingControllerProvider.notifier)
          .updateDayTarget(
            carbLoadingDayId: (day as dynamic).id as String,
            carbsPerKg: 9.2,
            dailyTargetG: 626,
          );
    }
    expect(report.faults, isEmpty);
  });
}
