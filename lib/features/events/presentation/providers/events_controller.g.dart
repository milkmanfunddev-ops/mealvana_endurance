// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing events
/// Handles event CRUD operations (create, read, update, delete)

@ProviderFor(EventsController)
const eventsControllerProvider = EventsControllerProvider._();

/// Controller for managing events
/// Handles event CRUD operations (create, read, update, delete)
final class EventsControllerProvider
    extends $AsyncNotifierProvider<EventsController, List<Event>> {
  /// Controller for managing events
  /// Handles event CRUD operations (create, read, update, delete)
  const EventsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsControllerHash();

  @$internal
  @override
  EventsController create() => EventsController();
}

String _$eventsControllerHash() => r'8ba625a026bcb79805692ff5a5613670ad98bbe5';

/// Controller for managing events
/// Handles event CRUD operations (create, read, update, delete)

abstract class _$EventsController extends $AsyncNotifier<List<Event>> {
  FutureOr<List<Event>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Event>>, List<Event>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Event>>, List<Event>>,
              AsyncValue<List<Event>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for getting event detail with associated activity

@ProviderFor(eventDetail)
const eventDetailProvider = EventDetailFamily._();

/// Provider for getting event detail with associated activity

final class EventDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Activity? activity, Event event})>,
          ({Activity? activity, Event event}),
          FutureOr<({Activity? activity, Event event})>
        >
    with
        $FutureModifier<({Activity? activity, Event event})>,
        $FutureProvider<({Activity? activity, Event event})> {
  /// Provider for getting event detail with associated activity
  const EventDetailProvider._({
    required EventDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'eventDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$eventDetailHash();

  @override
  String toString() {
    return r'eventDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<({Activity? activity, Event event})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Activity? activity, Event event})> create(Ref ref) {
    final argument = this.argument as String;
    return eventDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EventDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$eventDetailHash() => r'73f83d6a9457d9db5478c7cedda231100c2f5c7d';

/// Provider for getting event detail with associated activity

final class EventDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({Activity? activity, Event event})>,
          String
        > {
  const EventDetailFamily._()
    : super(
        retry: null,
        name: r'eventDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting event detail with associated activity

  EventDetailProvider call(String eventId) =>
      EventDetailProvider._(argument: eventId, from: this);

  @override
  String toString() => r'eventDetailProvider';
}

/// Provider for getting all events

@ProviderFor(allEvents)
const allEventsProvider = AllEventsProvider._();

/// Provider for getting all events

final class AllEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Event>>,
          List<Event>,
          FutureOr<List<Event>>
        >
    with $FutureModifier<List<Event>>, $FutureProvider<List<Event>> {
  /// Provider for getting all events
  const AllEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allEventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allEventsHash();

  @$internal
  @override
  $FutureProviderElement<List<Event>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Event>> create(Ref ref) {
    return allEvents(ref);
  }
}

String _$allEventsHash() => r'7377c871ebb1377d43e3f5a2758d4b0193ba30b8';

/// Provider for getting next upcoming event

@ProviderFor(nextUpcomingEvent)
const nextUpcomingEventProvider = NextUpcomingEventProvider._();

/// Provider for getting next upcoming event

final class NextUpcomingEventProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Event event, DateTime eventDate})?>,
          ({Event event, DateTime eventDate})?,
          FutureOr<({Event event, DateTime eventDate})?>
        >
    with
        $FutureModifier<({Event event, DateTime eventDate})?>,
        $FutureProvider<({Event event, DateTime eventDate})?> {
  /// Provider for getting next upcoming event
  const NextUpcomingEventProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nextUpcomingEventProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nextUpcomingEventHash();

  @$internal
  @override
  $FutureProviderElement<({Event event, DateTime eventDate})?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Event event, DateTime eventDate})?> create(Ref ref) {
    return nextUpcomingEvent(ref);
  }
}

String _$nextUpcomingEventHash() => r'd919590566743935f92a0938778470b7f34b47fe';
