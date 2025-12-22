import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/carb_loading_repository.dart';

part 'carb_loading_service.g.dart';

@riverpod
CarbLoadingService carbLoadingService(Ref ref) {
  return CarbLoadingService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
    ref.read(carbLoadingRepositoryProvider),
  );
}

/// Service for managing carb loading plans and days
/// Handles creation, deletion, and updates of carb loading protocols
class CarbLoadingService {
  final AppDatabase _database;
  final AppLogger _logger;
  final CarbLoadingRepository _carbLoadingRepository;

  CarbLoadingService(
    this._database,
    this._logger,
    this._carbLoadingRepository,
  );

  /// Create a carb loading plan for an event
  /// This generates day records for each carb loading day based on the protocol
  Future<void> createCarbLoadingPlan({
    required String deviceId,
    required String userId,
    String? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Call repository which will invoke edge function to create plan and auto-generate days
      await _carbLoadingRepository.createCarbLoadingPlan(
        deviceId: deviceId,
        userId: userId,
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      // Update event with carb loading info (only if eventId is provided)
      if (eventId != null) {
        final startDate = raceDate.subtract(Duration(days: protocolDays));
        await (_database.update(_database.eventsTable)..where((tbl) => tbl.id.equals(eventId)))
            .write(EventsTableCompanion(
              hasCarbLoading: const Value(true),
              carbLoadingDays: Value(protocolDays),
              carbLoadingStartDate: Value(startDate),
              updatedAt: Value(DateTime.now()),
              needsUpload: const Value(true),
              localUpdatedAt: Value(DateTime.now()),
            ));
      } else {
      }
    } catch (e) {
      _logger.error('Error creating carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete carb loading plan and associated day records
  Future<void> deleteCarbLoadingPlan({
    required String deviceId,
    required String eventId,
  }) async {
    try {
      // First, look up the plan by eventId to get the actual planId
      final plan = await getCarbLoadingPlan(eventId);

      if (plan != null) {
        // Delete the plan using the actual plan ID
        await _carbLoadingRepository.deleteCarbLoadingPlan(
          deviceId: deviceId,
          planId: plan.id,
        );
        _logger.info('Deleted carb loading plan ${plan.id} for event $eventId');
      } else {
        _logger.warning('No carb loading plan found for event $eventId - nothing to delete');
      }

      // Update event to clear carb loading flags (even if plan wasn't found)
      await (_database.update(_database.eventsTable)..where((tbl) => tbl.id.equals(eventId)))
          .write(EventsTableCompanion(
            hasCarbLoading: const Value(false),
            carbLoadingDays: const Value(null),
            carbLoadingStartDate: const Value(null),
            updatedAt: Value(DateTime.now()),
            needsUpload: const Value(true),
            localUpdatedAt: Value(DateTime.now()),
          ));
    } catch (e) {
      _logger.error('Error deleting carb loading plan', error: e);
      rethrow;
    }
  }

  /// Delete a single carb loading day and its associated meals
  Future<void> deleteCarbLoadingDay(String carbLoadingDayId) async {
    try {
      // Delete all meals for this day
      await (_database.delete(_database.carbLoadingDayMealsTable)
            ..where((tbl) => tbl.carbLoadingDayId.equals(carbLoadingDayId)))
          .go();

      // Delete the carb loading day
      await (_database.delete(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.id.equals(carbLoadingDayId)))
          .go();
    } catch (e) {
      _logger.error('Error deleting carb loading day', error: e);
      rethrow;
    }
  }

  /// Update carb loading protocol (delete old plan and create new one)
  Future<void> updateCarbLoadingProtocol({
    required String deviceId,
    required String userId,
    required String eventId,
    required int newProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Delete existing plan
      await deleteCarbLoadingPlan(deviceId: deviceId, eventId: eventId);

      // Create new plan
      await createCarbLoadingPlan(
        deviceId: deviceId,
        userId: userId,
        eventId: eventId,
        protocolDays: newProtocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

    } catch (e) {
      _logger.error('Error updating carb loading protocol', error: e);
      rethrow;
    }
  }

  /// Get carb loading plan for an event
  Future<CarbLoadingPlan?> getCarbLoadingPlan(String eventId) async{
    try {
      final query = _database.select(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.eventId.equals(eventId));

      return await query.getSingleOrNull();
    } catch (e) {
      _logger.error('Error getting carb loading plan for event: $eventId', error: e);
      rethrow;
    }
  }

  /// Get carb loading days for a plan
  Future<List<CarbLoadingDay>> getCarbLoadingDays(String planId) async {
    try {
      final query = _database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.carbLoadingPlanId.equals(planId))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]);

      return await query.get();
    } catch (e) {
      _logger.error('Error getting carb loading days for plan: $planId', error: e);
      rethrow;
    }
  }

  /// Get all carb loading days for a date range
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final query = _database.select(_database.carbLoadingDaysTable)
            ..where((tbl) =>
                tbl.planDate.isBiggerOrEqualValue(startDate) &
                tbl.planDate.isSmallerOrEqualValue(endDate))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.planDate)]);

      return await query.get();
    } catch (e) {
      _logger.error('Error getting carb loading days for range', error: e);
      rethrow;
    }
  }

  /// Get the carb protocol (g/kg) for a specific day (helper method)
  double getCarbProtocolForDay({
    required int protocolDays,
    required int daysBeforeRace,
  }) {
    if (protocolDays == 2) {
      // 2-day protocol
      if (daysBeforeRace == 2) {
        // Day -2: 9g/kg
        return 9.0;
      } else {
        // Day -1: 11g/kg
        return 11.0;
      }
    } else if (protocolDays == 3) {
      // 3-day protocol
      if (daysBeforeRace == 3 || daysBeforeRace == 2) {
        // Day -3 and -2: 8g/kg
        return 8.0;
      } else {
        // Day -1: 10g/kg
        return 10.0;
      }
    }

    // Default fallback
    return 8.0;
  }
}
