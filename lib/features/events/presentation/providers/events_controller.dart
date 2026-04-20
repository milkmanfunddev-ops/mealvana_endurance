import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/events_service.dart';
import '../../../activities/application/activities_service.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../domain/event.dart';
import '../../../activities/domain/activity.dart';
import '../../../../shared/services/logging_service.dart';
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

    // 2. Background sync (fire-and-forget)
    unawaited(_backgroundSync(userId));

    return localData;
  }

  /// Background sync: ensures data is fresh, then refreshes UI only when data was stale
  Future<void> _backgroundSync(String userId) async {
    final repo = ref.read(eventsRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final logger = ref.read(appLoggerProvider);

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
      logger.warning(
        'Background sync failed',
        context: 'EVENTS_CONTROLLER',
        data: {'error': e.toString()},
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
    final logger = ref.read(appLoggerProvider);

    try {
      // Read deviceId BEFORE async operations
      final deviceIdValue = await ref.read(userIdProvider.future);

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

      return createdEvent.id;
    } catch (e) {
      // Use cached logger (safe - no ref access)
      logger.error('Error creating event', error: e);
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
    final logger = ref.read(appLoggerProvider);

    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await service.updateEvent(deviceId: deviceIdValue, event: event);

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return;

      // Invalidate providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);
    } catch (e) {
      logger.error('Error updating event', error: e);
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Delete an event
  /// Also cascade deletes any associated carb loading plan and invalidates related providers
  Future<void> deleteEvent(String eventId) async {
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

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
      // The event deletion cascades to carb loading data in the repository layer
      ref.invalidate(carbLoadingDaysForRangeProvider);
      ref.invalidate(carbLoadingPlanProvider(eventId));

      // Invalidate activities providers since event deletion cascade-deletes associated activity
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(allActivitiesProvider);
    } catch (e) {
      logger.error('Error deleting event', error: e);
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Get event by ID
  Future<Event?> getEventById(String eventId) async {
    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      final userId = await ref.read(userIdProvider.future);
      return await service.getEventById(userId, eventId);
    } catch (e) {
      logger.error('Error getting event by ID', error: e);
      rethrow;
    }
  }

  /// Get event for a specific activity
  Future<Event?> getEventForActivity(String activityId) async {
    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      return await service.getEventForActivity(activityId);
    } catch (e) {
      logger.error('Error getting event for activity', error: e);
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
    final logger = ref.read(appLoggerProvider);

    try {
      final userId = await ref.read(userIdProvider.future);

      // Force sync from Supabase (bypasses 24h staleness check)
      await ref
          .read(syncCoordinatorProvider.notifier)
          .forceSyncRepository(
            'events',
            userId,
            repository: ref.read(eventsRepositoryProvider),
          );

      // Invalidate to reload with fresh data
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);
    } catch (e) {
      logger.error('Error during force refresh', error: e);
      // Still invalidate to show whatever data we have
      ref.invalidateSelf();
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
  final logger = ref.read(appLoggerProvider);
  final String userId = forUserId ?? await ref.read(userIdProvider.future);

  // Sync events from remote if stale (respects 1-hour staleness threshold).
  // This ensures coach-created changes (e.g. hasCarbLoading flag) are visible.
  try {
    final repo = ref.read(eventsRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    await syncCoordinator.ensureSynced('events', userId, repository: repo);
  } catch (e) {
    logger.warning(
      'Could not sync events from remote; using local data',
      context: 'EVENT_DETAIL',
      data: {'error': e.toString()},
    );
  }

  final eventsService = ref.read(eventsServiceProvider);
  final activitiesService = ref.read(activitiesServiceProvider);
  final event = await eventsService.getEventById(userId, eventId);
  if (event == null) {
    logger.error(
      'EventDetail: Event not found',
      context: 'EVENT_DETAIL',
      data: {'eventId': eventId, 'userId': userId},
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
  final userId = await ref.read(userIdProvider.future);
  final service = ref.read(eventsServiceProvider);
  return await service.getAllEvents(userId);
}

/// Provider for getting next upcoming event
@riverpod
Future<({Event event, DateTime eventDate})?> nextUpcomingEvent(Ref ref) async {
  final now = DateTime.now();
  final userId = await ref.read(userIdProvider.future);
  final eventsService = ref.read(eventsServiceProvider);

  // Get all events
  final events = await eventsService.getAllEvents(userId);

  // Find the next upcoming event by checking startTime or eventDate
  Event? nextEvent;
  DateTime? nextEventDate;

  for (final event in events) {
    DateTime? eventDateTime;

    // Try parsing startTime first (precise time with timezone)
    if (event.startTime != null && event.startTime!.isNotEmpty) {
      try {
        eventDateTime = DateTime.parse(event.startTime!);
      } catch (_) {
        // Invalid startTime format, fall through to eventDate
      }
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
