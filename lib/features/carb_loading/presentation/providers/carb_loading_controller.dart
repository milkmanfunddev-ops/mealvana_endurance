import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/carb_loading_service.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/user_id_provider.dart';

part 'carb_loading_controller.g.dart';

/// Controller for managing carb loading plans
/// Handles carb loading protocol creation, updates, and queries
@Riverpod(keepAlive: true)
class CarbLoadingController extends _$CarbLoadingController {
  CarbLoadingService get _service => ref.read(carbLoadingServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<void> build() {
    // No state to load on build - carb loading days are fetched via separate provider
    return null;
  }

  /// Create a carb loading plan for an event
  Future<void> createCarbLoadingPlan({
    required int eventId,
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
  Future<void> deleteCarbLoadingPlan(int eventId) async {
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
  Future<void> deleteCarbLoadingDay(int carbLoadingDayId) async {
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
    required int eventId,
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

  // No refresh needed - use separate providers that can be invalidated independently
}

/// Provider for getting carb loading plan for a specific event
/// Returns CarbLoadingPlan? from the database
@riverpod
Future<dynamic> carbLoadingPlan(Ref ref, int eventId) async {
  final service = ref.read(carbLoadingServiceProvider);
  return await service.getCarbLoadingPlan(eventId);
}

/// Provider for getting carb loading days for a plan
/// Returns List<CarbLoadingDay> from the database
@riverpod
Future<List<dynamic>> carbLoadingDaysForPlan(Ref ref, int planId) async {
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
