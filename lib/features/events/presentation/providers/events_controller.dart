import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/events_service.dart';
import '../../../activities/application/activities_service.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import '../../../macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import '../../domain/duplicate_event_name_on_day.dart';
import '../../domain/event.dart';
import '../../../activities/domain/activity.dart';
import '../../../../shared/services/report/report.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../data/events_repository.dart';

part 'events_controller.g.dart';

/// Controller for managing events
/// Handles event CRUD operations (create, read, update, delete)
@riverpod
class EventsController extends _$EventsController {
  @override
  FutureOr<List<Event>> build() async {
    // Cache service reference before async operations
    final service = ref.read(eventsServiceProvider);

    // Get user ID
    final userId = await ref.read(userIdProvider.future);

    // 1. Load local data IMMEDIATELY
    final localData = await service.getAllEvents(userId);

    // 2. Background sync (fire-and-forget). It reads `ref`, so skip it when
    // this build was disposed during the awaits above; its result is discarded.
    if (!ref.mounted) return localData;
    unawaited(_backgroundSync(userId));

    return localData;
  }

  /// Background sync: ensures data is fresh, then refreshes UI only when data was stale
  Future<void> _backgroundSync(String userId) async {
    final repo = ref.read(eventsRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final report = ref.read(reportProvider);

    try {
      final wasStale = await repo.isStale();
      await syncCoordinator.ensureSynced('events', userId, repository: repo);
      // Only refresh UI if data was stale AND sync actually succeeded.
      // We verify success by checking that staleness was cleared (timestamp updated).
      // Without this guard, a failed sync leaves wasStale=true forever,
      // causing an infinite build→sync→invalidate loop.
      final stillStale = await repo.isStale();
      if (wasStale && !stillStale) {
        if (!ref.mounted) return;
        ref.invalidateSelf();
      }
    } catch (e) {
      report.degraded(
        LoggedFault('Background sync failed'),
        area: 'events',
        extra: {'error': e.toString()},
      );
    }
  }

  /// Create a new event
  /// Note: Does NOT invalidate the provider - calling code should handle refresh
  /// If [forUserId] is provided, creates event for that user (coach creating for athlete)
  Future<String> createEvent({
    String? activityId,
    String?
    forUserId, // NEW: If provided, create event for this user (coach creating for athlete)
    required ActivityType eventType,
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
    // Keep provider alive during async work when invoked via ref.read (no listeners)
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    // to avoid "Ref disposed" errors if provider rebuilds during async work
    final service = ref.read(eventsServiceProvider);
    final repo = ref.read(eventsRepositoryProvider);
    final report = ref.read(reportProvider);

    try {
      // Read deviceId BEFORE async operations
      final deviceIdValue = await ref.read(userIdProvider.future);

      await _refuseSameNameSameDay(
        repo,
        report,
        userId: forUserId ?? deviceIdValue,
        eventName: eventName,
        eventDate: Event.dateFromStartTime(startTime),
      );

      // Use cached service reference (no ref access after this point)
      final createdEvent = await service.createEvent(
        deviceId: deviceIdValue,
        forUserId:
            forUserId, // NEW: Pass through forUserId for coach-created events
        activityId: activityId,
        eventType: eventType,
        eventSubtype: eventSubtype,
        eventName: eventName,
        location: location,
        registrationUrl: registrationUrl,
        startTime: startTime,
        goalTimeMinutes: goalTimeMinutes,
        goalPaceMinutesPerMile: goalPaceMinutesPerMile,
        predictedFinishTimeMinutes: predictedFinishTimeMinutes,
        hasCarbLoading: hasCarbLoading,
        carbLoadingDays: carbLoadingDays,
        carbLoadingStartDate: carbLoadingStartDate,
        bibNumber: bibNumber,
        waveStartTime: waveStartTime,
        packetPickupInfo: packetPickupInfo,
      );

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return createdEvent.id;

      // Invalidate providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);
      // G27: a new event may open a race-window nudge schedule.
      unawaited(ref.read(carbNudgeCoordinatorProvider.notifier).run());

      return createdEvent.id;
    } on DuplicateEventNameOnDayException {
      rethrow; // written down by _refuseSameNameSameDay; not a fault
    } catch (e) {
      // Use cached report (safe - no ref access)
      report.fault(e, area: 'events', message: 'Error creating event');
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Update an existing event
  /// Note: Does NOT invalidate the provider - calling code should handle refresh
  Future<void> updateEvent(Event event) async {
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final repo = ref.read(eventsRepositoryProvider);
    final report = ref.read(reportProvider);

    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await _refuseSameNameSameDay(
        repo,
        report,
        userId: event.userId,
        eventName: event.eventName,
        eventDate: event.withDerivedEventDate().eventDate,
        excludeEventId: event.id,
      );

      await service.updateEvent(deviceId: deviceIdValue, event: event);

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return;

      // Invalidate providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);

      // The update can MOVE the event's linked activity (EventsService
      // ._moveLinkedActivityToEventDate), and the events list renders
      // `activity.scheduledDateTime` in preference to the event's own date —
      // so without this the row keeps painting the pre-move date from the
      // cached activity list while the database is already correct. Same
      // reasoning as deleteEvent's cascade invalidation below.
      // Bug 2026-09-16-event-date-edit-leaves-linked-activity-behind (layer 3:
      // verified in prod that the rows moved while the screen did not).
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(allActivitiesProvider);
    } on DuplicateEventNameOnDayException {
      rethrow; // written down by _refuseSameNameSameDay; not a fault
    } catch (e) {
      report.fault(e, area: 'events', message: 'Error updating event');
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Throws [DuplicateEventNameOnDayException] when [userId] already has a
  /// local event with the same trimmed name on [eventDate] (ticket 72). The
  /// server's `events_user_date_name_unique` index would refuse that row with
  /// 23505 on every upload, so the form refuses it up front. A write with no
  /// name or no date cannot collide (nulls are distinct in the index).
  Future<void> _refuseSameNameSameDay(
    EventsRepository repo,
    Report report, {
    required String userId,
    required String? eventName,
    required DateTime? eventDate,
    String? excludeEventId,
  }) async {
    final name = eventName?.trim() ?? '';
    if (name.isEmpty || eventDate == null) return;
    final existing = await repo.findSameNameSameDayEvent(
      userId: userId,
      eventName: name,
      eventDate: eventDate,
      excludeEventId: excludeEventId,
    );
    if (existing == null) return;
    report.info(
      'Event write refused: same name on the same day',
      area: 'events',
      data: {
        'existingEventId': existing.id,
        if (excludeEventId != null) 'editedEventId': excludeEventId,
      },
    );
    throw DuplicateEventNameOnDayException(
      userId: userId,
      eventName: name,
      eventDate: eventDate,
      existingEventId: existing.id,
    );
  }

  /// Delete an event
  /// Also cascade deletes any associated carb loading plan and invalidates related providers
  Future<void> deleteEvent(String eventId) async {
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final report = ref.read(reportProvider);

    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await service.deleteEvent(deviceId: deviceIdValue, eventId: eventId);

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return;

      // Invalidate event providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);

      // Invalidate carb loading providers to refresh calendar UI
      // The event deletion cascades to carb loading data in the repository
      // layer. G24: cover EVERY family a carb surface watches — the summary's
      // day rows and the loading-day dashboard go stale otherwise.
      ref.invalidate(carbLoadingDaysForRangeProvider);
      ref.invalidate(carbLoadingPlanProvider(eventId));
      ref.invalidate(carbLoadingDaysForPlanProvider);
      ref.invalidate(carbDashboardForDateProvider);

      // Invalidate activities providers since event deletion cascade-deletes associated activity
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(allActivitiesProvider);
    } catch (e) {
      report.fault(e, area: 'events', message: 'Error deleting event');
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Get event by ID
  Future<Event?> getEventById(String eventId) async {
    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final report = ref.read(reportProvider);

    try {
      final userId = await ref.read(userIdProvider.future);
      return await service.getEventById(userId, eventId);
    } catch (e) {
      report.fault(e, area: 'events', message: 'Error getting event by ID');
      rethrow;
    }
  }

  /// Get event for a specific activity
  Future<Event?> getEventForActivity(String activityId) async {
    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final report = ref.read(reportProvider);

    try {
      return await service.getEventForActivity(activityId);
    } catch (e) {
      report.fault(
        e,
        area: 'events',
        message: 'Error getting event for activity',
      );
      rethrow;
    }
  }

  /// Refresh events list (uses cached data, respects staleness)
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Force refresh events from Supabase (bypasses staleness check).
  ///
  /// Use this for pull-to-refresh when user explicitly wants fresh data,
  /// or when athlete needs to see coach-made changes immediately.
  Future<void> forceRefresh() async {
    final report = ref.read(reportProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final repository = ref.read(eventsRepositoryProvider);

    try {
      final userId = await ref.read(userIdProvider.future);

      // Force sync from Supabase (bypasses 24h staleness check)
      await syncCoordinator.forceSyncRepository(
        'events',
        userId,
        repository: repository,
      );

      // Invalidate to reload with fresh data
      if (!ref.mounted) return;
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);
    } catch (e) {
      report.fault(e, area: 'events', message: 'Error during force refresh');
      // Still invalidate to show whatever data we have
      if (ref.mounted) ref.invalidateSelf();
    }
  }
}

/// Provider for getting event detail with associated activity.
/// Accepts an optional [forUserId] to query on behalf of another user
/// (e.g. when a coach views an athlete's event).
@riverpod
Future<({Activity? activity, Event event})> eventDetail(
  Ref ref,
  String eventId, {
  String? forUserId,
}) async {
  // Every `ref` read happens before the first await: this auto-dispose family
  // is often disposed mid-load when the detail screen pops, and a read after
  // that throws UnmountedRefException (Sentry MEALVANA-ENDURANCE-D1).
  final report = ref.read(reportProvider);
  final repo = ref.read(eventsRepositoryProvider);
  final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
  final eventsService = ref.read(eventsServiceProvider);
  final activitiesService = ref.read(activitiesServiceProvider);
  final String userId = forUserId ?? await ref.read(userIdProvider.future);

  // Sync events from remote if stale (respects 1-hour staleness threshold).
  // This ensures coach-created changes (e.g. hasCarbLoading flag) are visible.
  try {
    await syncCoordinator.ensureSynced('events', userId, repository: repo);
  } catch (e) {
    report.degraded(
      LoggedFault('Could not sync events from remote; using local data'),
      area: 'events',
      extra: {'error': e.toString()},
    );
  }

  final event = await eventsService.getEventById(userId, eventId);
  if (event == null) {
    report.fault(
      LoggedFault('EventDetail: Event not found'),
      area: 'events',
      extra: {'eventId': eventId, 'userId': userId},
    );
    throw Exception('Event not found: $eventId');
  }

  Activity? activity;
  if (event.activityId != null) {
    activity = await activitiesService.getActivityById(
      userId,
      event.activityId!,
    );
  }

  return (activity: activity, event: event);
}

/// Provider for getting all events
@riverpod
Future<List<Event>> allEvents(Ref ref) async {
  // Read the service before awaiting the user id: the screens that watch this
  // auto-dispose provider often leave while the id is still loading, and a
  // `ref.read` after that throws UnmountedRefException (Sentry
  // MEALVANA-ENDURANCE-CP / DEV-9D). Once disposed, the result is discarded,
  // so skip the query too.
  final service = ref.read(eventsServiceProvider);
  final userId = await ref.read(userIdProvider.future);
  if (!ref.mounted) return const <Event>[];
  return await service.getAllEvents(userId);
}

/// Provider for getting next upcoming event
@riverpod
Future<({Event event, DateTime eventDate})?> nextUpcomingEvent(Ref ref) async {
  final now = DateTime.now();
  final eventsService = ref.read(eventsServiceProvider);
  final userId = await ref.read(userIdProvider.future);

  // Get all events
  final events = await eventsService.getAllEvents(userId);

  // Find the next upcoming event by checking startTime or eventDate
  Event? nextEvent;
  DateTime? nextEventDate;

  for (final event in events) {
    DateTime? eventDateTime;

    // Try parsing startTime first (precise time with timezone)
    if (event.startTime != null && event.startTime!.isNotEmpty) {
      // Invalid startTime format leaves null and falls through to eventDate.
      eventDateTime = DateTime.tryParse(event.startTime!);
    }

    // Fall back to eventDate (primary date for calendar)
    eventDateTime ??= event.eventDate;

    if (eventDateTime != null && eventDateTime.isAfter(now)) {
      // Check if this is the closest upcoming event
      if (nextEventDate == null || eventDateTime.isBefore(nextEventDate)) {
        nextEvent = event;
        nextEventDate = eventDateTime;
      }
    }
  }

  if (nextEvent != null && nextEventDate != null) {
    return (event: nextEvent, eventDate: nextEventDate);
  }

  return null;
}
