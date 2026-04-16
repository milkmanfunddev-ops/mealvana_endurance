import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/calendar_service.dart';
import '../../../activities/application/activities_service.dart';
import '../../../activities/domain/activity.dart';
import '../../../events/data/events_repository.dart';
import '../../../events/domain/event.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../auth/application/auth_service.dart' as auth_service;
import '../../../auth/application/supabase_auth_service.dart' as supabase_auth;

part 'calendar_controller.g.dart';

/// Calendar controller state
class CalendarState {
  const CalendarState({
    this.activities = const [],
    this.events = const [],
    this.carbLoadingDays = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Activity> activities;
  final List<Event> events;
  final List<db.CarbLoadingDay> carbLoadingDays;
  final bool isLoading;
  final String? error;

  const CalendarState.loading() : activities = const [], events = const [], carbLoadingDays = const [], isLoading = true, error = null;

  CalendarState.error(String this.error) : activities = const [], events = const [], carbLoadingDays = const [], isLoading = false;

  const CalendarState.data({required this.activities, required this.events, this.carbLoadingDays = const []})
      : isLoading = false, error = null;

  CalendarState copyWith({
    List<Activity>? activities,
    List<Event>? events,
    List<db.CarbLoadingDay>? carbLoadingDays,
    bool? isLoading,
    String? error,
  }) {
    return CalendarState(
      activities: activities ?? this.activities,
      events: events ?? this.events,
      carbLoadingDays: carbLoadingDays ?? this.carbLoadingDays,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Calendar controller for managing activities and events
@riverpod
class CalendarController extends _$CalendarController {
  CalendarService get _calendarService => ref.read(calendarServiceProvider);
  ActivitiesService get _activitiesService => ref.read(activitiesServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);
  auth_service.AuthService get _authService => ref.read(auth_service.authServiceProvider);

  @override
  FutureOr<CalendarState> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    ref.watch(supabase_auth.currentUserProvider);
    
    // Load initial week on build
    final weekStart = _getWeekStart(DateTime.now());
    return await _loadWeekActivities(weekStart);
  }

  /// Load activities for current week
  Future<void> loadWeekActivities(DateTime weekStart) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await _loadWeekActivities(weekStart);
    });
  }

  Future<CalendarState> _loadWeekActivities(DateTime weekStart) async {
    try {
      // Get current user's device ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      final activities = await _calendarService.getActivitiesForWeek(userId, weekStart);

      // Get ALL events (not just for this week) so they show as dots on the calendar
      // The calendar shows a 2-year range, so we need events across that entire range
      final events = await _calendarService.getAllEvents(userId);

      // Fetch ALL carb loading days (not just for this week)
      // Carb loading days can be far in the future for upcoming events
      // IMPORTANT: Pass userId to ensure only current user's days are returned
      final carbLoadingDays = await _calendarService.getCarbLoadingDaysForRange(
        userId: userId,
        startDate: DateTime.now().subtract(const Duration(days: 365)), // 1 year ago
        endDate: DateTime.now().add(const Duration(days: 730)), // 2 years in future
      );

      return CalendarState.data(
        activities: activities,
        events: events,
        carbLoadingDays: carbLoadingDays,
      );
    } catch (e) {
      _logger.error('Error loading week activities', error: e);
      throw Exception('Failed to load activities: $e');
    }
  }

  /// Create a new activity
  Future<String> createActivity({
    required String title,
    required DateTime scheduledDateTime,
    ActivityType activityType = ActivityType.running,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    IntensityLevel? intensityLevel,
    String? notes,
    bool reminderEnabled = false,
    int? reminderDaysBefore,
    String? reminderTimeOfDay,
    bool reminderRecurring = false,
  }) async {
    try {
      // Get current user's device ID (stored in id field) and userId
      final user = await _authService.getCurrentUser();
      final deviceId = user?.id ?? 'unknown';
      final userId = user?.id ?? 'unknown';

      final createdActivity = await _activitiesService.createActivity(
        deviceId: deviceId,
        userId: userId,
        activityType: activityType,
        title: title,
        scheduledDateTime: scheduledDateTime,
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        paceTargetMinutesPerMile: paceTargetMinutesPerMile,
        intensityLevel: intensityLevel,
        notes: notes,
      );

      // Refresh activities
      ref.invalidateSelf();

      return createdActivity.id;
    } catch (e) {
      _logger.error('Error creating activity', error: e);
      rethrow;
    }
  }

  /// Update an existing activity
  Future<void> updateActivity(Activity activity) async {
    try {
      final user = await _authService.getCurrentUser();
      final deviceId = user?.id ?? 'unknown';

      await _activitiesService.updateActivity(
        deviceId: deviceId,
        activity: activity,
      );

      // Refresh activities
      ref.invalidateSelf();

    } catch (e) {
      _logger.error('Error updating activity', error: e);
      rethrow;
    }
  }

  /// Update an existing event
  Future<void> updateEvent(Event event) async {
    try {
      await _calendarService.updateEvent(event);

      // Refresh activities and upcoming event providers
      ref.invalidateSelf();
      ref.invalidate(allEventsControllerProvider);
      ref.invalidate(nextUpcomingEventProvider);

    } catch (e) {
      _logger.error('Error updating event', error: e);
      rethrow;
    }
  }

  /// Delete an activity and its associated event/carb loading
  Future<void> deleteActivity(String activityId) async {
    try {
      final user = await _authService.getCurrentUser();
      final deviceId = user?.id ?? 'unknown';

      await _calendarService.deleteActivity(
        deviceId: deviceId,
        activityId: activityId,
      );

      // Refresh activities and upcoming event providers
      ref.invalidateSelf();
      ref.invalidate(allEventsControllerProvider);
      ref.invalidate(nextUpcomingEventProvider);

    } catch (e) {
      _logger.error('Error deleting activity', error: e);
    }
  }

  /// Delete a carb loading day
  Future<void> deleteCarbLoadingDay(String carbLoadingDayId) async {
    try {
      await _calendarService.deleteCarbLoadingDay(carbLoadingDayId);

      // Refresh activities to update the list
      ref.invalidateSelf();

    } catch (e) {
      _logger.error('Error deleting carb loading day', error: e);
    }
  }

  /// Complete an activity by updating it with completion data
  Future<void> completeActivity({
    required String activityId,
    required DateTime completedAt,
    int? effortRating,
    int? nutritionRating,
    int? overallSatisfaction,
    String? textNotes,
    bool hasVoiceRecording = false,
    String? weatherConditions,
    int? temperatureFahrenheit,
    int? humidityPercent,
  }) async {
    try {
      // Get current user and activity
      final user = await _authService.getCurrentUser();
      final deviceId = user?.id ?? 'unknown';
      final userId = user?.id ?? 'unknown';

      final activity = await _activitiesService.getActivityById(userId, activityId);
      if (activity == null) {
        _logger.error('Activity not found: $activityId', error: null);
        return;
      }

      // Update activity with completion data
      final completedActivity = activity.copyWith(
        status: ActivityStatus.completed,
        completedAt: completedAt,
        completionRating: overallSatisfaction,
        completionNotes: textNotes,
      );

      await _activitiesService.updateActivity(
        deviceId: deviceId,
        activity: completedActivity,
      );

      // Refresh activities
      ref.invalidateSelf();

    } catch (e) {
      _logger.error('Error completing activity', error: e);
    }
  }

  /// Update activity completion notes
  Future<void> updateActivityCompletion({
    required String activityId,
    String? textNotes,
  }) async {
    try {
      final user = await _authService.getCurrentUser();
      final deviceId = user?.id ?? 'unknown';
      final userId = user?.id ?? 'unknown';

      final activity = await _activitiesService.getActivityById(userId, activityId);
      if (activity == null) {
        _logger.error('Activity not found: $activityId', error: null);
        return;
      }

      // Update activity with new completion notes
      final updatedActivity = activity.copyWith(
        completionNotes: textNotes,
      );

      await _activitiesService.updateActivity(
        deviceId: deviceId,
        activity: updatedActivity,
      );

      // Refresh activities
      ref.invalidateSelf();

    } catch (e) {
      _logger.error('Error updating activity completion', error: e);
      rethrow;
    }
  }

  /// Create a new event (optionally linked to an activity)
  Future<void> createEvent({
    String? activityId, // Now optional - events can exist without activities
    required ActivityType eventType, // Event type: running, cycling, swimming, triathlon, duathlon, multisport
    String? eventSubtype, // Specific race distance/type
    String? eventName,
    String? location,
    String? registrationUrl,
    String? startTime, // Event date/time in ISO8601 format
    int? goalTimeMinutes,
    double? goalPaceMinutesPerMile,
    bool hasCarbLoading = false,
    int? carbLoadingDays,
  }) async {
    try {
      // Get current user's device ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      // Parse eventDate from startTime for calendar display
      DateTime? eventDate;
      if (startTime != null && startTime.isNotEmpty) {
        eventDate = DateTime.tryParse(startTime);
      }

      final now = DateTime.now();
      final eventsRepo = ref.read(eventsRepositoryProvider);
      await eventsRepo.createEvent(
        deviceId: userId,
        event: Event(
          id: '', // Let DB auto-generate
          userId: userId,
          activityId: activityId,
          eventType: eventType,
          eventSubtype: eventSubtype,
          eventName: eventName,
          location: location,
          registrationUrl: registrationUrl,
          eventDate: eventDate,
          startTime: startTime,
          goalTimeMinutes: goalTimeMinutes,
          goalPaceMinutesPerMile: goalPaceMinutesPerMile,
          hasCarbLoading: hasCarbLoading,
          carbLoadingDays: carbLoadingDays,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Refresh activities and upcoming event providers
      ref.invalidateSelf();
      ref.invalidate(allEventsControllerProvider);
      ref.invalidate(nextUpcomingEventProvider);

    } catch (e) {
      _logger.error('Error creating event', error: e);
    }
  }

  /// Get activities for a specific date
  Future<List<Activity>> getActivitiesForDate(DateTime date) async {
    final weekStart = _getWeekStart(date);
    await loadWeekActivities(weekStart);
    return state.when(
      data: (data) => data.activities.where((activity) =>
          activity.scheduledDateTime.year == date.year &&
          activity.scheduledDateTime.month == date.month &&
          activity.scheduledDateTime.day == date.day
      ).toList(),
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// Get activities for current week
  List<Activity> get currentWeekActivities {
    return state.when(
      data: (data) => data.activities,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// Get events for current week
  List<Event> get currentWeekEvents {
    return state.when(
      data: (data) => data.events,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// Get week start date for a given date
  DateTime _getWeekStart(DateTime date) {
    // TODO: Use user preference for week start
    final weekStart = DateTime(date.year, date.month, date.day - date.weekday + 1);
    return weekStart;
  }

  /// Create a carb loading plan for an event
  Future<void> createCarbLoadingPlan({
    required String eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Get current user's device ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      await _calendarService.createCarbLoadingPlan(
        userId: userId,
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      // Refresh activities to show new carb loading days
      ref.invalidateSelf();

    } catch (e) {
      _logger.error('Error creating carb loading plan', error: e);
      rethrow;
    }
  }

  /// Update carb loading protocol for an event
  Future<void> updateCarbLoadingProtocol({
    required String eventId,
    required int newProtocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    try {
      // Get current user's device ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      await _calendarService.updateCarbLoadingProtocol(
        userId: userId,
        eventId: eventId,
        newProtocolDays: newProtocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      // Refresh activities to show updated carb loading days
      ref.invalidateSelf();

    } catch (e) {
      _logger.error('Error updating carb loading protocol', error: e);
      rethrow;
    }
  }
}

/// All Events Controller - separate from calendar week view
/// Used by EventsListScreen to show ALL events, not just current week
@riverpod
class AllEventsController extends _$AllEventsController {
  CalendarService get _calendarService => ref.read(calendarServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);
  auth_service.AuthService get _authService => ref.read(auth_service.authServiceProvider);

  @override
  FutureOr<CalendarState> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    ref.watch(supabase_auth.currentUserProvider);

    // Load all activities on build
    return await _loadAllActivities();
  }

  Future<CalendarState> _loadAllActivities() async {
    try {
      // Get current user's device ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      final activities = await _calendarService.getAllActivities(userId);

      // Get all events (events are now separate from activities)
      final events = await _calendarService.getAllEvents(userId);

      return CalendarState.data(
        activities: activities,
        events: events,
      );
    } catch (e) {
      _logger.error('Error loading all activities', error: e);
      throw Exception('Failed to load all activities: $e');
    }
  }

  /// Refresh all activities and events
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provider to watch a specific event by eventId
/// This ensures the UI updates when the event data changes in the database
@riverpod
Future<({Activity? activity, Event event})> eventDetail(
  Ref ref,
  String eventId,
) async {
  final service = ref.read(calendarServiceProvider);
  final logger = ref.read(appLoggerProvider);
  final authService = ref.read(auth_service.authServiceProvider);

  // Watch auth state to trigger rebuilds on sign in/out
  ref.watch(supabase_auth.currentUserProvider);

  try {
    // Get current user's device ID
    final user = await authService.getCurrentUser();
    final userId = user?.id ?? 'unknown';

    // Get the event
    final event = await service.getEventById(userId, eventId);
    if (event == null) {
      throw Exception('Event not found: $eventId');
    }

    // Get the activity for this event (if one exists)
    Activity? activity;
    if (event.activityId != null) {
      activity = await service.getActivityById(userId, event.activityId!);
    }

    return (activity: activity, event: event);
  } catch (e) {
    logger.error('Error loading event detail', error: e);
    rethrow;
  }
}

/// Provider to watch a specific activity by activityId
/// This ensures the UI updates when the activity data changes in the database
@riverpod
Future<({Activity activity, Event? event})> activityDetail(
  Ref ref,
  String activityId,
) async {
  final service = ref.read(calendarServiceProvider);
  final logger = ref.read(appLoggerProvider);
  final authService = ref.read(auth_service.authServiceProvider);

  // Watch auth state to trigger rebuilds on sign in/out
  ref.watch(supabase_auth.currentUserProvider);

  try {
    // Get current user's device ID
    final user = await authService.getCurrentUser();
    final userId = user?.id ?? 'unknown';

    // Get the activity
    final activity = await service.getActivityById(userId, activityId);
    if (activity == null) {
      throw Exception('Activity not found: $activityId');
    }

    // Check if there's an event associated with this activity
    final event = await service.getEventForActivity(activityId);

    return (activity: activity, event: event);
  } catch (e) {
    logger.error('Error loading activity detail', error: e);
    rethrow;
  }
}

/// Next Upcoming Event Provider - for showing the upcoming event widget
/// Gets the single next upcoming event from today onwards
@riverpod
Future<Event?> nextUpcomingEvent(Ref ref) async {
  final service = ref.read(calendarServiceProvider);
  final logger = ref.read(appLoggerProvider);
  final authService = ref.read(auth_service.authServiceProvider);

  // Watch auth state to trigger rebuilds on sign in/out
  ref.watch(supabase_auth.currentUserProvider);

  try {
    // Get current user's device ID
    final user = await authService.getCurrentUser();
    final userId = user?.id ?? 'unknown';

    // Get all events
    final events = await service.getAllEvents(userId);

    // Get event dates from either activity or event.startTime
    final eventsWithDates = <({Event event, DateTime eventDate})>[];

    for (final event in events) {
      DateTime? eventDate;

      // Try to get date from linked activity first
      if (event.activityId != null) {
        final activity = await service.getActivityById(userId, event.activityId!);
        if (activity != null) {
          eventDate = activity.scheduledDateTime;
        }
      }

      // Fall back to event.startTime if no activity
      if (eventDate == null && event.startTime != null) {
        try {
          eventDate = DateTime.parse(event.startTime!);
        } catch (e) {
          logger.warning('nextUpcomingEvent: Could not parse startTime for event ${event.id}: ${event.startTime}');
        }
      }

      if (eventDate != null) {
        eventsWithDates.add((event: event, eventDate: eventDate));
      } else {
        logger.warning('nextUpcomingEvent: Event ${event.id} has no date (no activity and no startTime)');
      }
    }

    // Filter for events on or after today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcomingEvents = eventsWithDates
        .where((e) {
          // Compare dates only (ignore time)
          final eventDate = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
          final isUpcoming = eventDate.isAfter(today) || eventDate.isAtSameMomentAs(today);
          return isUpcoming;
        })
        .toList();

    // Sort by event date (ascending - earliest first)
    upcomingEvents.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    // Return the next upcoming event (first in sorted list)
    final result = upcomingEvents.isEmpty ? null : upcomingEvents.first.event;
    return result;
  } catch (e, stackTrace) {
    logger.error('Error loading next upcoming event', error: e, stackTrace: stackTrace);
    return null;
  }
}