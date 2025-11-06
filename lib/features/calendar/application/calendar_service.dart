import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/activity.dart' as domain;
import '../domain/event.dart' as domain;
import '../domain/activity_completion.dart' as domain;
import '../../activities/domain/activity_reminder.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/notification_service.dart';

/// Service for managing calendar activities and events
class CalendarService {
  final AppDatabase _database;
  final AppLogger _logger;
  final Uuid _uuid = const Uuid();

  CalendarService(this._database, this._logger);

  /// Get activities for a specific date range
  Future<List<domain.Activity>> getActivitiesForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = _database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.equals(userId) &
                              tbl.scheduledDateTime.isBetweenValues(startDate, endDate) &
                              tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);
      
      final activities = await query.get();

      return activities.map(_mapToActivityDomain).cast<domain.Activity>().toList();
    } catch (e) {
      _logger.error('Error getting activities for date range', error: e);
      rethrow;
    }
  }

  /// Get activities for a specific week
  Future<List<domain.Activity>> getActivitiesForWeek(String userId, DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return getActivitiesForDateRange(userId, weekStart, weekEnd);
  }

  /// Get all activities for a user (no date filter)
  Future<List<domain.Activity>> getAllActivities(String userId) async {
    try {
      final query = _database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.equals(userId) &
                              tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

      final activities = await query.get();

      return activities.map(_mapToActivityDomain).cast<domain.Activity>().toList();
    } catch (e) {
      _logger.error('Error getting all activities', error: e);
      rethrow;
    }
  }

  /// Get a specific activity by ID
  Future<domain.Activity?> getActivityById(String userId, String activityId) async {
    try {
      final query = _database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.equals(userId) &
                              tbl.id.equals(activityId) &
                              tbl.deletedAt.isNull());
      
      final activity = await query.getSingleOrNull();

      return activity != null ? _mapToActivityDomain(activity) : null;
    } catch (e) {
      _logger.error('Error getting activity by ID: $activityId', error: e);
      rethrow;
    }
  }

  /// Create a new activity
  Future<domain.Activity> createActivity({
    required String userId,
    required domain.ActivityType activityType,
    required String title,
    required DateTime scheduledDateTime,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    domain.IntensityLevel? intensityLevel,
    String? notes,
    bool reminderEnabled = false,
    int? reminderDaysBefore,
    String? reminderTimeOfDay,
    bool reminderRecurring = false,
  }) async {
    try {
      final id = _generateId();
      final companion = ActivitiesTableCompanion.insert(
        id: id,
        userId: userId,
        activityType: activityType.name,
        title: title,
        scheduledDateTime: scheduledDateTime,
        distanceMiles: Value(distanceMiles),
        durationMinutes: Value(durationMinutes),
        paceTargetMinutesPerMile: Value(paceTargetMinutesPerMile),
        intensityLevel: Value(intensityLevel?.name),
        notes: Value(notes),
        reminderEnabled: Value(reminderEnabled),
        reminderDaysBefore: Value(reminderDaysBefore),
        reminderTimeOfDay: Value(reminderTimeOfDay),
        reminderRecurring: Value(reminderRecurring),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _database.into(_database.activitiesTable).insert(companion);

      // Get the created activity
      final createdActivity = await getActivityById(userId, id);
      if (createdActivity == null) {
        throw Exception('Failed to retrieve created activity');
      }

      // Schedule notification if reminder is enabled
      if (reminderEnabled && reminderDaysBefore != null && reminderTimeOfDay != null) {
        await _scheduleActivityReminder(
          activityId: id,
          activityTitle: title,
          scheduledDateTime: scheduledDateTime,
          daysBefore: reminderDaysBefore,
          timeOfDay: reminderTimeOfDay,
          recurring: reminderRecurring,
        );
      }

      return createdActivity;
    } catch (e) {
      _logger.error('Error creating activity', error: e);
      rethrow;
    }
  }

  /// Update an existing activity
  Future<domain.Activity> updateActivity(domain.Activity activity) async {
    try {
      final companion = ActivitiesTableCompanion(
        title: Value(activity.title),
        scheduledDateTime: Value(activity.scheduledDateTime),
        distanceMiles: Value(activity.distanceMiles),
        durationMinutes: Value(activity.durationMinutes),
        paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
        intensityLevel: Value(activity.intensityLevel?.name),
        notes: Value(activity.notes),
        reminderEnabled: Value(activity.reminderEnabled),
        reminderDaysBefore: Value(activity.reminderDaysBefore),
        reminderTimeOfDay: Value(activity.reminderTimeOfDay),
        reminderRecurring: Value(activity.reminderRecurring),
        updatedAt: Value(DateTime.now()),
      );

      await (_database.update(_database.activitiesTable)..where((tbl) => tbl.id.equals(activity.id)))
          .write(companion);

      // Cancel any existing reminders for this activity
      await NotificationService.cancelAllReminders();

      // Schedule new notification if reminder is enabled
      if (activity.reminderEnabled &&
          activity.reminderDaysBefore != null &&
          activity.reminderTimeOfDay != null) {
        await _scheduleActivityReminder(
          activityId: activity.id,
          activityTitle: activity.title,
          scheduledDateTime: activity.scheduledDateTime,
          daysBefore: activity.reminderDaysBefore!,
          timeOfDay: activity.reminderTimeOfDay!,
          recurring: activity.reminderRecurring,
        );
      }

      return activity;
    } catch (e) {
      _logger.error('Error updating activity: ${activity.id}', error: e);
      rethrow;
    }
  }

  /// Soft delete an activity
  /// Also deletes associated event, carb loading plan, and carb loading days
  Future<void> deleteActivity(String activityId) async {
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

      // Finally, soft delete the activity
      await (_database.update(_database.activitiesTable)..where((tbl) => tbl.id.equals(activityId)))
          .write(ActivitiesTableCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));

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
      // ignore: avoid_print
      print('Error getting event for activity: $activityId');
      // ignore: avoid_print
      print('Error: $e');
      // ignore: avoid_print
      print('StackTrace: $stackTrace');
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
    required domain.EventType eventType,
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
      final id = _generateId();
      final companion = EventsTableCompanion.insert(
        userId: userId,
        id: id,
        activityId: Value(activityId), // Now nullable
        eventType: eventType.dbValue,
        eventSubtype: Value(eventSubtype),
        eventName: Value(eventName),
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

      await _database.into(_database.eventsTable).insert(companion);

      // Get the created event by ID
      final createdEvent = await getEventById('current-user', id);
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
        id: Value(event.id),
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
        hasNutritionPlan: Value(event.hasNutritionPlan),
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

  /// Update event's nutrition plan flag
  Future<void> updateEventNutritionPlanFlag({
    required String activityId,
    required bool hasNutritionPlan,
  }) async {
    try {
      // Get the event for this activity
      final event = await getEventForActivity(activityId);

      if (event == null) {
        return;
      }

      // Update the event with the new nutrition plan flag
      final companion = EventsTableCompanion(
        id: Value(event.id),
        hasNutritionPlan: Value(hasNutritionPlan),
        updatedAt: Value(DateTime.now()),
      );

      await (_database.update(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(event.id)))
          .write(companion);

    } catch (e) {
      _logger.error('Error updating event nutrition plan flag for activity $activityId', error: e);
      rethrow;
    }
  }

  /// Complete an activity with detailed completion data
  Future<domain.ActivityCompletion> completeActivity({
    required String activityId,
    required String userId,
    required DateTime completedAt,
    domain.CompletionType completionType = domain.CompletionType.manual,
    double? actualDistanceMiles,
    int? actualDurationMinutes,
    double? averagePaceMinutesPerMile,
    int? maxHeartRate,
    int? averageHeartRate,
    int? caloriesBurned,
    int? effortRating,
    int? nutritionRating,
    int? overallSatisfaction,
    String? textNotes,
    String? voiceNoteId,
    bool? hasVoiceRecording,
    String? weatherConditions,
    int? temperatureFahrenheit,
    int? humidityPercent,
  }) async {
    try {
      // Update activity status to completed
      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .write(ActivitiesTableCompanion(
            status: const Value('completed'),
            completedAt: Value(completedAt),
            actualDistanceMiles: Value(actualDistanceMiles),
            actualDurationMinutes: Value(actualDurationMinutes),
            updatedAt: Value(DateTime.now()),
          ));

      // Create completion record
      final id = _generateId();
      final companion = ActivityCompletionsTableCompanion.insert(
        id: id,
        activityId: activityId,
        userId: userId,
        completedAt: completedAt,
        completionType: Value(completionType.name),
        actualDistanceMiles: Value(actualDistanceMiles),
        actualDurationMinutes: Value(actualDurationMinutes),
        averagePaceMinutesPerMile: Value(averagePaceMinutesPerMile),
        maxHeartRate: Value(maxHeartRate),
        averageHeartRate: Value(averageHeartRate),
        caloriesBurned: Value(caloriesBurned),
        effortRating: Value(effortRating),
        nutritionRating: Value(nutritionRating),
        overallSatisfaction: Value(overallSatisfaction),
        textNotes: Value(textNotes),
        voiceNoteId: Value(voiceNoteId),
        hasVoiceRecording: Value(hasVoiceRecording ?? false),
        weatherConditions: Value(weatherConditions),
        temperatureFahrenheit: Value(temperatureFahrenheit),
        humidityPercent: Value(humidityPercent),
      );

      await _database.into(_database.activityCompletionsTable).insert(companion);
      
      // Get the created completion
      final completion = await getCompletionForActivity(activityId);
      if (completion == null) {
        throw Exception('Failed to retrieve created completion');
      }

      return completion;
    } catch (e) {
      _logger.error('Error completing activity: $activityId', error: e);
      rethrow;
    }
  }

  /// Get completion data for an activity
  Future<domain.ActivityCompletion?> getCompletionForActivity(String activityId) async {
    try {
      final query = _database.select(_database.activityCompletionsTable)
            ..where((tbl) => tbl.activityId.equals(activityId));

      final completion = await query.getSingleOrNull();

      return completion != null ? _mapToCompletionDomain(completion) : null;
    } catch (e) {
      _logger.error('Error getting completion for activity: $activityId', error: e);
      rethrow;
    }
  }

  /// Update activity completion notes
  Future<void> updateActivityCompletion({
    required String activityId,
    String? textNotes,
  }) async {
    try {
      final companion = ActivityCompletionsTableCompanion(
        textNotes: Value(textNotes),
      );

      await (_database.update(_database.activityCompletionsTable)
            ..where((tbl) => tbl.activityId.equals(activityId)))
          .write(companion);

    } catch (e) {
      _logger.error('Error updating activity completion: $activityId', error: e);
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
      final planId = _generateId();
      final planCompanion = CarbLoadingPlansTableCompanion.insert(
        id: planId,
        eventId: eventId != null && eventId.isNotEmpty ? Value(eventId) : const Value.absent(),
        userId: userId,
        totalDays: protocolDays,
        startDate: startDate,
        endDate: endDate,
        dailyCarbTargetGrams: avgDailyCarbs,
        generatedAt: DateTime.now(),
      );

      await _database.into(_database.carbLoadingPlansTable).insert(planCompanion);

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
        final carbDayId = _generateId();
        final carbDayCompanion = CarbLoadingDaysTableCompanion.insert(
          id: carbDayId,
          carbLoadingPlanId: planId,
          planDate: dayDate,
          dayNumber: dayOffset + 1,
          carbTargetGrams: targetCarbsGrams.round(),
          carbProtocolGPerKg: carbProtocolGPerKg,
        );

        await _database.into(_database.carbLoadingDaysTable).insert(carbDayCompanion);
      }

      // Update event with carb loading info (only if eventId is provided)
      if (eventId != null && eventId.isNotEmpty) {
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

  /// Helper method to generate UUID
  /// Schedule activity reminder notification
  Future<void> _scheduleActivityReminder({
    required String activityId,
    required String activityTitle,
    required DateTime scheduledDateTime,
    required int daysBefore,
    required String timeOfDay,
    required bool recurring,
  }) async {
    try {
      final reminder = ActivityReminder(
        enabled: true,
        daysBefore: daysBefore,
        timeOfDay: timeOfDay,
        recurring: recurring,
      );

      final reminderDateTime = reminder.calculateReminderDateTime(scheduledDateTime);

      await NotificationService.scheduleReminder(
        scheduledDate: reminderDateTime,
        recurring: recurring,
        title: 'Upcoming Activity Reminder',
        body: 'Your activity "$activityTitle" is in $daysBefore ${daysBefore == 1 ? "day" : "days"}!',
        planId: activityId,
      );

      _logger.info('Scheduled reminder for activity $activityId at $reminderDateTime');
    } catch (e) {
      _logger.error('Error scheduling activity reminder', error: e);
      // Don't rethrow - reminder scheduling failure shouldn't block activity creation
    }
  }

  String _generateId() {
    return _uuid.v4();
  }

  /// Map database Activity to domain Activity
  domain.Activity _mapToActivityDomain(Activity activity) {
    return domain.Activity(
      id: activity.id,
      userId: activity.userId,
      activityType: domain.ActivityType.values.firstWhere(
        (type) => type.name == activity.activityType,
        orElse: () => domain.ActivityType.running,
      ),
      title: activity.title,
      scheduledDateTime: activity.scheduledDateTime,
      status: domain.ActivityStatus.values.firstWhere(
        (status) => status.name == activity.status,
        orElse: () => domain.ActivityStatus.planned,
      ),
      distanceMiles: activity.distanceMiles,
      durationMinutes: activity.durationMinutes,
      paceTargetMinutesPerMile: activity.paceTargetMinutesPerMile,
      intensityLevel: activity.intensityLevel != null
          ? domain.IntensityLevel.values.firstWhere(
              (level) => level.name == activity.intensityLevel,
              orElse: () => domain.IntensityLevel.moderate,
            )
          : null,
      completedAt: activity.completedAt,
      completionRating: activity.completionRating,
      completionNotes: activity.completionNotes,
      actualDistanceMiles: activity.actualDistanceMiles,
      actualDurationMinutes: activity.actualDurationMinutes,
      notes: activity.notes,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
      deletedAt: activity.deletedAt,
    );
  }

  /// Map database Event to domain Event
  domain.Event _mapToEventDomain(Event event) {
    return domain.Event(
      id: event.id,
      activityId: event.activityId,
      eventType: domain.EventTypeExtension.fromDbValue(event.eventType),
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

  /// Map database ActivityCompletion to domain ActivityCompletion
  domain.ActivityCompletion _mapToCompletionDomain(ActivityCompletion completion) {
    return domain.ActivityCompletion(
      id: completion.id,
      activityId: completion.activityId,
      userId: completion.userId,
      completedAt: completion.completedAt,
      completionType: domain.CompletionType.values.firstWhere(
        (type) => type.name == completion.completionType,
        orElse: () => domain.CompletionType.manual,
      ),
      actualDistanceMiles: completion.actualDistanceMiles,
      actualDurationMinutes: completion.actualDurationMinutes,
      averagePaceMinutesPerMile: completion.averagePaceMinutesPerMile,
      maxHeartRate: completion.maxHeartRate,
      averageHeartRate: completion.averageHeartRate,
      caloriesBurned: completion.caloriesBurned,
      effortRating: completion.effortRating,
      nutritionRating: completion.nutritionRating,
      overallSatisfaction: completion.overallSatisfaction,
      textNotes: completion.textNotes,
      voiceNoteId: completion.voiceNoteId,
      hasVoiceRecording: completion.hasVoiceRecording,
      weatherConditions: completion.weatherConditions,
      temperatureFahrenheit: completion.temperatureFahrenheit,
      humidityPercent: completion.humidityPercent,
      nutritionAdherenceScore: completion.nutritionAdherenceScore,
      performanceVsTarget: completion.performanceVsTarget,
    );
  }
}

/// Provider for CalendarService
final calendarServiceProvider = Provider<CalendarService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final appLogger = ref.watch(appLoggerProvider);
  return CalendarService(database, appLogger);
});