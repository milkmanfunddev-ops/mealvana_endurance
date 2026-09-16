import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../activities/data/activities_repository.dart';
import '../../activities/presentation/providers/activities_controller.dart';
import '../../events/data/events_repository.dart';
import '../../events/presentation/providers/events_controller.dart';
import '../../meal_logging/data/meal_log_repository.dart';
import '../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../domain/vana_part.dart';
import 'meal_plan_controller.dart';

part 'vana_write_refetcher.g.dart';

/// Keeps the device's offline-first stores honest after a write Vana made
/// on the server (Lee's playtest 2026-09-16 §10).
///
/// Events and meal logs are owned locally (Drift, `needs_upload`,
/// `ensureSynced`); a server-side write bypasses all of that, so a
/// `receipt` part is the cue to pull the store it names. This is the least
/// invasive hook available: the repositories already have a remote pull
/// (`syncFromRemote`, dirty rows preserved) and the coordinator already has
/// a forced entry point for it, so the refetch is one forced sync of one
/// repository plus an invalidate of the read providers that do not stream
/// from Drift. Nothing new is written locally and no screen changes how
/// it loads.
///
/// keepAlive: the chat controller reads it once per receipt, and an
/// auto-dispose provider would hand it a dead [Ref] the moment the read
/// returned.
@Riverpod(keepAlive: true)
VanaWriteRefetcher vanaWriteRefetcher(Ref ref) => VanaWriteRefetcher(ref);

class VanaWriteRefetcher {
  VanaWriteRefetcher(this._ref);

  final Ref _ref;

  /// Pull the store [part] names. Errors are the caller's to log; the
  /// receipt is already on screen either way.
  Future<void> after(VanaReceiptPart part) async {
    final userId = await _ref.read(userIdProvider.future);
    final sync = _ref.read(syncCoordinatorProvider.notifier);
    switch (part.entity) {
      case VanaReceiptEntity.event:
        await sync.forceSyncRepository(
          'events',
          userId,
          repository: _ref.read(eventsRepositoryProvider),
        );
        _ref.invalidate(eventsControllerProvider);
        _ref.invalidate(allEventsProvider);
        _ref.invalidate(nextUpcomingEventProvider);
      case VanaReceiptEntity.activity:
        // Activities are the same offline-first shape as events: a Drift
        // store with `needs_upload`, so a server-side write only lands
        // here through a forced pull. The controller and the all-list are
        // one-shot reads, not Drift streams.
        await sync.forceSyncRepository(
          'activities',
          userId,
          repository: _ref.read(activitiesRepositoryProvider),
        );
        _ref.invalidate(activitiesControllerProvider);
        _ref.invalidate(allActivitiesProvider);
      case VanaReceiptEntity.mealLog:
        // The day's log providers stream from Drift and re-emit on their
        // own; only the recents list is a one-shot read.
        await sync.forceSyncRepository(
          'meal_logs',
          userId,
          repository: _ref.read(mealLogRepositoryProvider),
        );
        _ref.invalidate(recentMealsProvider);
      case VanaReceiptEntity.plan:
        await _ref.read(mealPlanControllerProvider.notifier).refresh();
    }
  }
}
