import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/carb_load_nudge_service.dart';
import '../../application/carb_loading_service.dart';
import '../../domain/carb_loading_entryway_engine.dart';
import '../../data/carb_loading_repository.dart';
import '../../../macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'carb_nudge_coordinator.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../../shared/providers/user_id_provider.dart';

part 'carb_loading_controller.g.dart';

/// Controller for managing carb loading plans
/// Handles carb loading protocol creation, updates, and queries
@Riverpod(keepAlive: true)
class CarbLoadingController extends _$CarbLoadingController {
  CarbLoadingService get _service => ref.read(carbLoadingServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<void> build() async {
    // Background sync (fire-and-forget) - syncs if stale, then refreshes UI
    final userId = await ref.read(userIdProvider.future);
    unawaited(_backgroundSync(userId));
  }

  /// G24 (Xuan, 2026-09-25): EVERY plan-shape write invalidates EVERY
  /// provider family a carb surface watches — not just the range family.
  /// The bug: repick invalidated self + daysForRange only, while the plan
  /// summary watches [carbLoadingPlanProvider] + [carbLoadingDaysForPlanProvider]
  /// and every loading-day dashboard surface watches
  /// [carbDashboardForDateProvider]; those rendered stale until unrelated
  /// navigation happened to rebuild them (E-3 instant-propagation violation).
  void _invalidateCarbSurfaces() {
    ref.invalidateSelf();
    ref.invalidate(carbLoadingPlanProvider);
    ref.invalidate(carbLoadingDaysForPlanProvider);
    ref.invalidate(carbLoadingDaysForRangeProvider);
    ref.invalidate(carbDashboardForDateProvider);
  }

  /// Background sync: ensures data is fresh, then refreshes UI
  Future<void> _backgroundSync(String userId) async {
    final repository = ref.read(carbLoadingRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final logger = ref.read(appLoggerProvider);

    try {
      await syncCoordinator.ensureSynced(
        'carb_loading_plans',
        userId,
        repository: repository,
      );
      if (!ref.mounted) return;
      _invalidateCarbSurfaces();
    } catch (e, stackTrace) {
      logger.error(
        'Background sync failed',
        context: 'CARB_LOADING_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create a carb loading plan for an event
  /// If [forUserId] is provided, creates the plan for that user (coach creating for athlete)
  Future<void> createCarbLoadingPlan({
    required String eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
    String? forUserId,
  }) async {
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);
      final userId = deviceIdValue; // Device ID is used as user ID

      await _service.createCarbLoadingPlan(
        deviceId: deviceIdValue,
        userId: userId,
        forUserId: forUserId,
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      _invalidateCarbSurfaces();
      // G27: a plan now exists — every remaining race-window nudge for this
      // event stands down (plan-existence is the truth). Fail-soft.
      unawaited(
        ref
            .read(carbLoadNudgeServiceProvider)
            .disarmEvent(eventId)
            .catchError((_) {}),
      );
    } catch (e) {
      _logger.error('Error creating carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete carb loading plan and associated days
  Future<void> deleteCarbLoadingPlan(String eventId) async {
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await _service.deleteCarbLoadingPlan(
        deviceId: deviceIdValue,
        eventId: eventId,
      );

      _invalidateCarbSurfaces();
      // G27: the plan is gone — the sweep re-arms the remainder of the
      // window from plan-existence truth. Fail-soft.
      unawaited(ref.read(carbNudgeCoordinatorProvider.notifier).run());
    } catch (e) {
      _logger.error('Error deleting carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete a single carb loading day
  Future<void> deleteCarbLoadingDay(String carbLoadingDayId) async {
    try {
      await _service.deleteCarbLoadingDay(carbLoadingDayId);

      _invalidateCarbSurfaces();
    } catch (e) {
      _logger.error('Error deleting carb loading day', error: e);
      rethrow;
    }
  }

  /// CE-10 (G17): persist an edited day target from the plan summary.
  /// Stores BOTH the grams and the resulting g/kg (Q-CL10: the stored value
  /// drives slots/checkpoints/copy; the rate copy shows the stored rate).
  Future<void> updateDayTarget({
    required String carbLoadingDayId,
    required double carbsPerKg,
    required int dailyTargetG,
  }) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final repository = ref.read(carbLoadingRepositoryProvider);
      await repository.updateCarbLoadingDay(
        deviceId: userId,
        carbLoadingDayId: carbLoadingDayId,
        updates: {
          'carbTargetGrams': dailyTargetG,
          'carbProtocolGPerKg': carbsPerKg,
        },
      );
      _invalidateCarbSurfaces();
    } catch (e) {
      _logger.error('Error updating carb day target', error: e);
      rethrow;
    }
  }

  /// CE-4 preview: what selecting [targetProtocolDays] would do — dialog
  /// type, F3 listed-edit data, dropped dates, both outcome plans. Pure
  /// read; nothing changes.
  Future<RepickDecision> previewRepickProtocol({
    required String eventId,
    required int targetProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) => _service.previewRepickProtocol(
    eventId: eventId,
    targetProtocolDays: targetProtocolDays,
    raceDate: raceDate,
    bodyWeightPounds: bodyWeightPounds,
  );

  /// CE-4/CE-4a apply: writes the athlete's choice through the in-place
  /// repick. Replaces the retired delete+recreate protocol update.
  Future<void> applyRepickProtocol({
    required String eventId,
    required int targetProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
    required bool keepEdits,
  }) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      await _service.applyRepickProtocol(
        deviceId: userId,
        userId: userId,
        eventId: eventId,
        targetProtocolDays: targetProtocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
        keepEdits: keepEdits,
      );
      ref.invalidateSelf();
      ref.invalidate(carbLoadingDaysForRangeProvider);
    } catch (e) {
      _logger.error('Error re-picking carb loading protocol', error: e);
      rethrow;
    }
  }

  /// Force refresh carb loading data from Supabase (bypasses staleness check).
  ///
  /// Use this for pull-to-refresh when user explicitly wants fresh data,
  /// or when athlete needs to see coach-made changes immediately.
  Future<void> forceRefresh() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final repository = ref.read(carbLoadingRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);

      // Force sync from Supabase (bypasses 24h staleness check)
      await syncCoordinator.forceSyncRepository(
        'carb_loading_plans',
        userId,
        repository: repository,
      );

      // Invalidate to reload with fresh data
      _invalidateCarbSurfaces();
    } catch (e, stackTrace) {
      _logger.error(
        'Error during force refresh',
        context: 'CARB_LOADING_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      // Still invalidate to show whatever data we have
      ref.invalidateSelf();
    }
  }
}

/// Provider for getting carb loading plan for a specific event
/// Returns CarbLoadingPlan? from the database
@riverpod
Future<dynamic> carbLoadingPlan(Ref ref, String eventId) async {
  final service = ref.read(carbLoadingServiceProvider);
  return await service.getCarbLoadingPlan(eventId);
}

/// Provider for getting carb loading days for a plan
/// Returns `List<CarbLoadingDay>` from the database.
@riverpod
Future<List<dynamic>> carbLoadingDaysForPlan(Ref ref, String planId) async {
  final service = ref.read(carbLoadingServiceProvider);
  return await service.getCarbLoadingDays(planId);
}

/// Provider for getting carb loading days in a date range
/// Returns `List<CarbLoadingDay>` from the database.
/// IMPORTANT: Scopes query to current user to prevent cross-user data leakage
@riverpod
Future<List<dynamic>> carbLoadingDaysForRange(
  Ref ref,
  DateTime startDate,
  DateTime endDate,
) async {
  final service = ref.read(carbLoadingServiceProvider);
  final userId = await ref.read(userIdProvider.future);
  final days = await service.getCarbLoadingDaysForRange(
    userId: userId,
    startDate: startDate,
    endDate: endDate,
  );
  // Cast to List<CarbLoadingDay>
  return days.cast<db.CarbLoadingDay>();
}
