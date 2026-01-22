import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/carb_loading_service.dart';
import '../../data/carb_loading_repository.dart';
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
    try {
      // Ensure carb loading data is synced using new sync architecture
      final userId = await ref.read(userIdProvider.future);
      final repository = ref.read(carbLoadingRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);

      await syncCoordinator.ensureSynced(
        'carb_loading_plans',
        userId,
        repository: repository,
      );
    } catch (e, stackTrace) {
      // Log sync errors but don't block UI - offline-first means we can work with cached data
      _logger.error(
        'Failed to sync carb loading data on controller build',
        context: 'CARB_LOADING_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create a carb loading plan for an event
  Future<void> createCarbLoadingPlan({
    required String eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);
      final userId = deviceIdValue; // Device ID is used as user ID

      await _service.createCarbLoadingPlan(
        deviceId: deviceIdValue,
        userId: userId,
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      // Refresh carb loading days - invalidate the range provider family
      ref.invalidateSelf();
      // Invalidate all carbLoadingDaysForRange provider instances to refresh calendar
      ref.invalidate(carbLoadingDaysForRangeProvider);
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

      // Refresh carb loading days
      ref.invalidateSelf();
      // Invalidate all carbLoadingDaysForRange provider instances to refresh calendar
      ref.invalidate(carbLoadingDaysForRangeProvider);
    } catch (e) {
      _logger.error('Error deleting carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete a single carb loading day
  Future<void> deleteCarbLoadingDay(String carbLoadingDayId) async {
    try {
      await _service.deleteCarbLoadingDay(carbLoadingDayId);

      // Refresh carb loading days
      ref.invalidateSelf();
      // Invalidate all carbLoadingDaysForRange provider instances to refresh calendar
      ref.invalidate(carbLoadingDaysForRangeProvider);
    } catch (e) {
      _logger.error('Error deleting carb loading day', error: e);
      rethrow;
    }
  }

  /// Update carb loading protocol (delete old plan and create new one)
  Future<void> updateCarbLoadingProtocol({
    required String eventId,
    required int newProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);
      final userId = deviceIdValue;

      await _service.updateCarbLoadingProtocol(
        deviceId: deviceIdValue,
        userId: userId,
        eventId: eventId,
        newProtocolDays: newProtocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      // Refresh carb loading days
      ref.invalidateSelf();
      // Invalidate all carbLoadingDaysForRange provider instances to refresh calendar
      ref.invalidate(carbLoadingDaysForRangeProvider);
    } catch (e) {
      _logger.error('Error updating carb loading protocol', error: e);
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
      ref.invalidateSelf();
      ref.invalidate(carbLoadingDaysForRangeProvider);
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
/// Returns List<CarbLoadingDay> from the database
@riverpod
Future<List<dynamic>> carbLoadingDaysForPlan(Ref ref, String planId) async {
  final service = ref.read(carbLoadingServiceProvider);
  return await service.getCarbLoadingDays(planId);
}

/// Provider for getting carb loading days in a date range
/// Returns List<CarbLoadingDay> from the database
@riverpod
Future<List<dynamic>> carbLoadingDaysForRange(
  Ref ref,
  DateTime startDate,
  DateTime endDate,
) async {
  final service = ref.read(carbLoadingServiceProvider);
  final days = await service.getCarbLoadingDaysForRange(
    startDate: startDate,
    endDate: endDate,
  );
  // Cast to List<CarbLoadingDay>
  return days.cast<db.CarbLoadingDay>();
}
