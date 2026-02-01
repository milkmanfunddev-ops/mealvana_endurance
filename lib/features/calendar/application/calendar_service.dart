import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activities/domain/activity.dart' as domain;
import '../../events/domain/event.dart' as domain;
import '../../activities/application/activities_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';

/// Service for managing calendar views, events, and carb loading plans
/// Delegates activity CRUD operations to ActivitiesService
class CalendarService {
  final AppDatabase _database;
  final AppLogger _logger;
  final ActivitiesService _activitiesService;

  CalendarService(
    this._database,
    this._logger,
    this._activitiesService,
  );

  /// Get activities for a specific date range - delegates to ActivitiesService
  Future<List<domain.Activity>> getActivitiesForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _activitiesService.getActivitiesForDateRange(userId, startDate, endDate);
  }

  /// Get activities for a specific week - delegates to ActivitiesService
  Future<List<domain.Activity>> getActivitiesForWeek(String userId, DateTime weekStart) async {
    return _activitiesService.getActivitiesForWeek(userId, weekStart);
  }

  /// Get all activities for a user - delegates to ActivitiesService
  Future<List<domain.Activity>> getAllActivities(String userId) async {
    return _activitiesService.getAllActivities(userId);
  }

  /// Get a specific activity by ID - delegates to ActivitiesService
  Future<domain.Activity?> getActivityById(String userId, String activityId) async {
    return _activitiesService.getActivityById(userId, activityId);
  }

  /// Soft delete an activity and its associated event, carb loading plan, and carb loading days
  /// Orchestrates the deletion of related entities before delegating activity deletion
  Future<void> deleteActivity({
    required String deviceId,
    required String activityId,
  }) async {
    try {
      // First, check if this activity has an event
      final event = await getEventForActivity(activityId);

      if (event != null) {
        // If there's an event, check for carb loading plan
        final carbLoadingPlan = await getCarbLoadingPlan(event.id);

        if (carbLoadingPlan != null) {
          // Get all carb loading day IDs for this plan
          final carbLoadingDays = await (_database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.carbLoadingPlanId.equals(carbLoadingPlan.id)))
              .get();

          // Delete all meals for each carb loading day
          for (final day in carbLoadingDays) {
            await (_database.delete(_database.carbLoadingDayMealsTable)
              ..where((tbl) => tbl.carbLoadingDayId.equals(day.id)))
                .go();
          }

          // Delete all carb loading days for this plan
          await (_database.delete(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.carbLoadingPlanId.equals(carbLoadingPlan.id)))
              .go();

          // Delete the carb loading plan
          await (_database.delete(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.id.equals(carbLoadingPlan.id)))
              .go();
        }

        // Delete the event
        await (_database.delete(_database.eventsTable)
          ..where((tbl) => tbl.id.equals(event.id)))
            .go();
      }

      // Finally, delegate activity deletion to ActivitiesService
      await _activitiesService.deleteActivity(
        deviceId: deviceId,
        activityId: activityId,
      );

    } catch (e) {
      _logger.error('Error deleting activity: $activityId', error: e);
      rethrow;
    }
  }

  /// Get event for a specific activity
  Future<domain.Event?> getEventForActivity(String activityId) async {
    try {
      final query = _database.select(_database.eventsTable)
            ..where((tbl) => tbl.activityId.equals(activityId));

      final event = await query.getSingleOrNull();

      return event != null ? _mapToEventDomain(event) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting event for activity: $activityId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a specific event by ID
  Future<domain.Event?> getEventById(String userId, String eventId) async {
    try {
      final query = _database.select(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId));

      final event = await query.getSingleOrNull();

      return event != null ? _mapToEventDomain(event) : null;
    } catch (e) {
      _logger.error('Error getting event by ID: $eventId', error: e);
      rethrow;
    }
  }

  /// Get all events for a user
  Future<List<domain.Event>> getAllEvents(String userId) async {
    try {
      // Note: Events table doesn't have userId column, but we'll keep the parameter
      // for future compatibility and to match the API signature
      final query = _database.select(_database.eventsTable)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

      final events = await query.get();

      return events.map(_mapToEventDomain).toList();
    } catch (e) {
      _logger.error('Error getting all events', error: e);
      rethrow;
    }
  }

  /// Get events for a specific week
  Future<List<domain.Event>> getEventsForWeek(String userId, DateTime weekStart) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      // Get all events
      final allEvents = await getAllEvents(userId);

      // Filter events that have activities in this week
      final eventsInWeek = <domain.Event>[];
      for (final event in allEvents) {
        if (event.activityId != null) {
          final activity = await getActivityById(userId, event.activityId!);
          if (activity != null &&
              activity.scheduledDateTime.isAfter(weekStart) &&
              activity.scheduledDateTime.isBefore(weekEnd)) {
            eventsInWeek.add(event);
          }
        }
      }

      return eventsInWeek;
    } catch (e) {
      _logger.error('Error getting events for week', error: e);
      rethrow;
    }
  }

  /// Create an event (optionally linked to an activity)
  Future<domain.Event> createEvent({
    required String userId,
    String? activityId, // Now nullable - events can exist without activities
    required ActivityType eventType, // Event type: running, cycling, swimming, triathlon, duathlon, multisport
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
    try {
      // Parse eventDate from startTime for calendar display
      DateTime? eventDate;
      if (startTime != null && startTime.isNotEmpty) {
        eventDate = DateTime.tryParse(startTime);
      }

      final companion = EventsTableCompanion.insert(
        userId: userId,
        activityId: activityId != null ? Value(activityId) : const Value.absent(),
        eventType: eventType.dbValue,
        eventSubtype: Value(eventSubtype),
        eventName: Value(eventName),
        eventDate: Value(eventDate), // Set eventDate for calendar indicators
        location: Value(location),
        registrationUrl: Value(registrationUrl),
        startTime: Value(startTime),
        goalTimeMinutes: Value(goalTimeMinutes),
        goalPaceMinutesPerMile: Value(goalPaceMinutesPerMile),
        predictedFinishTimeMinutes: Value(predictedFinishTimeMinutes),
        hasCarbLoading: Value(hasCarbLoading ?? false),
        carbLoadingDays: Value(carbLoadingDays),
        carbLoadingStartDate: Value(carbLoadingStartDate),
        bibNumber: Value(bibNumber),
        waveStartTime: Value(waveStartTime),
        packetPickupInfo: Value(packetPickupInfo),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert and get the full row back (including generated ID)
      final insertedEvent = await _database.into(_database.eventsTable).insertReturning(companion);

      // Get the created event by ID
      final createdEvent = await getEventById(userId, insertedEvent.id);
      if (createdEvent == null) {
        throw Exception('Failed to retrieve created event');
      }

      return createdEvent;
    } catch (e) {
      _logger.error('Error creating event', error: e);
      rethrow;
    }
  }

  /// Update an existing event
  Future<void> updateEvent(domain.Event event) async {
    try {
      final companion = EventsTableCompanion(
        eventType: Value(event.eventType.dbValue),
        eventSubtype: Value(event.eventSubtype),
        eventName: Value(event.eventName),
        location: Value(event.location),
        registrationUrl: Value(event.registrationUrl),
        startTime: Value(event.startTime),
        goalTimeMinutes: Value(event.goalTimeMinutes),
        goalPaceMinutesPerMile: Value(event.goalPaceMinutesPerMile),
        predictedFinishTimeMinutes: Value(event.predictedFinishTimeMinutes),
        hasCarbLoading: Value(event.hasCarbLoading),
        carbLoadingDays: Value(event.carbLoadingDays),
        carbLoadingStartDate: Value(event.carbLoadingStartDate),
        hasNutritionPlan: Value(event.hasNutritionPlan), // OBSOLETE: kept for backward compatibility
        bibNumber: Value(event.bibNumber),
        waveStartTime: Value(event.waveStartTime),
        packetPickupInfo: Value(event.packetPickupInfo),
        updatedAt: Value(DateTime.now()),
      );

      await (_database.update(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(event.id)))
          .write(companion);

    } catch (e) {
      _logger.error('Error updating event', error: e);
      rethrow;
    }
  }

  /// Create a carb loading plan for an event
  /// This generates day records for each carb loading day based on the protocol
  Future<void> createCarbLoadingPlan({
    required String userId,
    String? eventId, // Made nullable to support standalone carb loading plans
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Convert body weight to kg (1 pound = 0.453592 kg)
      final bodyWeightKg = bodyWeightPounds * 0.453592;

      // Calculate carb loading start date (X days before race, NOT including race day)
      // For 2-day protocol: starts 2 days before race (day -2 and day -1)
      // For 3-day protocol: starts 3 days before race (day -3, day -2, and day -1)
      final startDate = raceDate.subtract(Duration(days: protocolDays));
      final endDate = raceDate.subtract(const Duration(days: 1));

      // Calculate average daily carb target for the plan
      double totalCarbs = 0;
      for (int dayOffset = 0; dayOffset < protocolDays; dayOffset++) {
        final daysBeforeRace = protocolDays - dayOffset;
        final carbProtocol = _getCarbProtocolForDay(
          protocolDays: protocolDays,
          daysBeforeRace: daysBeforeRace,
        );
        totalCarbs += carbProtocol * bodyWeightKg;
      }
      final avgDailyCarbs = (totalCarbs / protocolDays).round();

      // Create the carb loading plan record
      final planCompanion = CarbLoadingPlansTableCompanion.insert(
        eventId: eventId != null ? Value(eventId) : const Value.absent(),
        userId: userId,
        totalDays: protocolDays,
        startDate: startDate,
        endDate: endDate,
        dailyCarbTargetGrams: avgDailyCarbs,
        generatedAt: DateTime.now(),
      );

      // Insert and get the full row back (including generated ID)
      final insertedPlan = await _database.into(_database.carbLoadingPlansTable).insertReturning(planCompanion);
      final planId = insertedPlan.id;

      // Generate carb loading day records
      for (int dayOffset = 0; dayOffset < protocolDays; dayOffset++) {
        final dayDate = startDate.add(Duration(days: dayOffset));
        final daysBeforeRace = protocolDays - dayOffset;

        // Calculate protocol g/kg for this day
        final carbProtocolGPerKg = _getCarbProtocolForDay(
          protocolDays: protocolDays,
          daysBeforeRace: daysBeforeRace,
        );

        // Calculate target carbs based on protocol and day
        final targetCarbsGrams = carbProtocolGPerKg * bodyWeightKg;

        // Create carb loading day record
        final carbDayCompanion = CarbLoadingDaysTableCompanion.insert(
          carbLoadingPlanId: planId,
          planDate: dayDate,
          dayNumber: dayOffset + 1,
          carbTargetGrams: targetCarbsGrams.round(),
          carbProtocolGPerKg: Value(carbProtocolGPerKg),
        );

        await _database.into(_database.carbLoadingDaysTable).insert(carbDayCompanion);
      }

      // Update event with carb loading info (only if eventId is provided)
      if (eventId != null) {
        await (_database.update(_database.eventsTable)..where((tbl) => tbl.id.equals(eventId)))
            .write(EventsTableCompanion(
              hasCarbLoading: const Value(true),
              carbLoadingDays: Value(protocolDays),
              carbLoadingStartDate: Value(startDate),
              updatedAt: Value(DateTime.now()),
            ));
      }
    } catch (e) {
      _logger.error('Error creating carb loading plan', error: e);
      rethrow;
    }
  }

  /// Get the carb protocol (g/kg) for a specific day
  double _getCarbProtocolForDay({
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

  /// Delete carb loading plan and associated day records
  Future<void> deleteCarbLoadingPlan({
    required String eventId,
  }) async {
    try {
      // Get the carb loading plan
      final planQuery = _database.select(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.eventId.equals(eventId));
      final plan = await planQuery.getSingleOrNull();

      if (plan == null) {
        _logger.warning('No carb loading plan found for event: $eventId');
        return;
      }

      // Get all carb loading days
      final carbLoadingDays = await (_database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.carbLoadingPlanId.equals(plan.id)))
          .get();

      // Delete all meals for each day
      for (final day in carbLoadingDays) {
        await (_database.delete(_database.carbLoadingDayMealsTable)
              ..where((tbl) => tbl.carbLoadingDayId.equals(day.id)))
            .go();
      }

      // Delete carb loading day records
      await (_database.delete(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.carbLoadingPlanId.equals(plan.id)))
          .go();

      // Delete carb loading plan
      await (_database.delete(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.id.equals(plan.id)))
          .go();

      // Update event
      await (_database.update(_database.eventsTable)..where((tbl) => tbl.id.equals(eventId)))
          .write(const EventsTableCompanion(
            hasCarbLoading: Value(false),
            carbLoadingDays: Value.absent(),
            carbLoadingStartDate: Value.absent(),
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
      _logger.error('Error deleting carb loading day: $carbLoadingDayId', error: e);
      rethrow;
    }
  }

  /// Update carb loading protocol (delete old plan and create new one)
  Future<void> updateCarbLoadingProtocol({
    required String userId,
    required String eventId,
    required int newProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Delete existing plan
      await deleteCarbLoadingPlan(eventId: eventId);

      // Create new plan
      await createCarbLoadingPlan(
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
  Future<CarbLoadingPlan?> getCarbLoadingPlan(String eventId) async {
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

  /// Get all carb loading days for a date range, scoped to a specific user
  ///
  /// IMPORTANT: This method joins through carb_loading_plans to ensure
  /// only days belonging to the specified user are returned.
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Join carb_loading_days with carb_loading_plans to filter by user_id
      final query = _database.select(_database.carbLoadingDaysTable).join([
        innerJoin(
          _database.carbLoadingPlansTable,
          _database.carbLoadingPlansTable.id
              .equalsExp(_database.carbLoadingDaysTable.carbLoadingPlanId),
        ),
      ])
        ..where(_database.carbLoadingPlansTable.userId.equals(userId) &
            _database.carbLoadingDaysTable.planDate
                .isBiggerOrEqualValue(startDate) &
            _database.carbLoadingDaysTable.planDate
                .isSmallerOrEqualValue(endDate))
        ..orderBy([OrderingTerm.asc(_database.carbLoadingDaysTable.planDate)]);

      final results = await query.get();
      return results
          .map((row) => row.readTable(_database.carbLoadingDaysTable))
          .toList();
    } catch (e) {
      _logger.error('Error getting carb loading days for range', error: e);
      rethrow;
    }
  }


  /// Map database Event to domain Event
  domain.Event _mapToEventDomain(Event event) {
    return domain.Event(
      id: event.id,
      userId: event.userId,
      activityId: event.activityId,
      eventType: _parseActivityType(event.eventType),
      eventSubtype: event.eventSubtype,
      eventName: event.eventName,
      location: event.location,
      registrationUrl: event.registrationUrl,
      startTime: event.startTime,
      goalTimeMinutes: event.goalTimeMinutes,
      goalPaceMinutesPerMile: event.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes: event.predictedFinishTimeMinutes,
      hasCarbLoading: event.hasCarbLoading,
      carbLoadingDays: event.carbLoadingDays,
      carbLoadingStartDate: event.carbLoadingStartDate,
      hasNutritionPlan: event.hasNutritionPlan,
      bibNumber: event.bibNumber,
      waveStartTime: event.waveStartTime,
      packetPickupInfo: event.packetPickupInfo,
      actualFinishTimeMinutes: event.actualFinishTimeMinutes,
      finalPlacement: event.finalPlacement,
      ageGroupPlacement: event.ageGroupPlacement,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }

  /// Parse database event_type string to ActivityType enum
  ActivityType _parseActivityType(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'running':
        return ActivityType.running;
      case 'cycling':
        return ActivityType.cycling;
      case 'swimming':
        return ActivityType.swimming;
      case 'triathlon':
      case 'duathlon':
      case 'multisport':
        // For multi-sport events, default to running for now
        return ActivityType.running;
      default:
        return ActivityType.running;
    }
  }
}

/// Provider for CalendarService
final calendarServiceProvider = Provider<CalendarService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final appLogger = ref.watch(appLoggerProvider);
  final activitiesService = ref.watch(activitiesServiceProvider);
  return CalendarService(database, appLogger, activitiesService);
});
