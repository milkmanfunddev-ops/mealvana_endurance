// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Calendar controller for managing activities and events

@ProviderFor(CalendarController)
const calendarControllerProvider = CalendarControllerProvider._();

/// Calendar controller for managing activities and events
final class CalendarControllerProvider
    extends $AsyncNotifierProvider<CalendarController, CalendarState> {
  /// Calendar controller for managing activities and events
  const CalendarControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarControllerHash();

  @$internal
  @override
  CalendarController create() => CalendarController();
}

String _$calendarControllerHash() =>
    r'7971779c8045bcecdc8f97dabb80fcc8790a176d';

/// Calendar controller for managing activities and events

abstract class _$CalendarController extends $AsyncNotifier<CalendarState> {
  FutureOr<CalendarState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CalendarState>, CalendarState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CalendarState>, CalendarState>,
              AsyncValue<CalendarState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// All Events Controller - separate from calendar week view
/// Used by EventsListScreen to show ALL events, not just current week

@ProviderFor(AllEventsController)
const allEventsControllerProvider = AllEventsControllerProvider._();

/// All Events Controller - separate from calendar week view
/// Used by EventsListScreen to show ALL events, not just current week
final class AllEventsControllerProvider
    extends $AsyncNotifierProvider<AllEventsController, CalendarState> {
  /// All Events Controller - separate from calendar week view
  /// Used by EventsListScreen to show ALL events, not just current week
  const AllEventsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allEventsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allEventsControllerHash();

  @$internal
  @override
  AllEventsController create() => AllEventsController();
}

String _$allEventsControllerHash() =>
    r'85867aac60d08e1f3eee715a7ef317acffd8a201';

/// All Events Controller - separate from calendar week view
/// Used by EventsListScreen to show ALL events, not just current week

abstract class _$AllEventsController extends $AsyncNotifier<CalendarState> {
  FutureOr<CalendarState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CalendarState>, CalendarState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CalendarState>, CalendarState>,
              AsyncValue<CalendarState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider to watch a specific event by eventId
/// This ensures the UI updates when the event data changes in the database

@ProviderFor(eventDetail)
const eventDetailProvider = EventDetailFamily._();

/// Provider to watch a specific event by eventId
/// This ensures the UI updates when the event data changes in the database

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
  /// Provider to watch a specific event by eventId
  /// This ensures the UI updates when the event data changes in the database
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

String _$eventDetailHash() => r'1cc29a7ae2623c1469add1de605dca70adefabe7';

/// Provider to watch a specific event by eventId
/// This ensures the UI updates when the event data changes in the database

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

  /// Provider to watch a specific event by eventId
  /// This ensures the UI updates when the event data changes in the database

  EventDetailProvider call(String eventId) =>
      EventDetailProvider._(argument: eventId, from: this);

  @override
  String toString() => r'eventDetailProvider';
}

/// Provider to watch a specific activity by activityId
/// This ensures the UI updates when the activity data changes in the database

@ProviderFor(activityDetail)
const activityDetailProvider = ActivityDetailFamily._();

/// Provider to watch a specific activity by activityId
/// This ensures the UI updates when the activity data changes in the database

final class ActivityDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Activity activity, Event? event})>,
          ({Activity activity, Event? event}),
          FutureOr<({Activity activity, Event? event})>
        >
    with
        $FutureModifier<({Activity activity, Event? event})>,
        $FutureProvider<({Activity activity, Event? event})> {
  /// Provider to watch a specific activity by activityId
  /// This ensures the UI updates when the activity data changes in the database
  const ActivityDetailProvider._({
    required ActivityDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activityDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityDetailHash();

  @override
  String toString() {
    return r'activityDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<({Activity activity, Event? event})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Activity activity, Event? event})> create(Ref ref) {
    final argument = this.argument as String;
    return activityDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityDetailHash() => r'50510abc5afd5e92cd485e724e2fd20246ac92ea';

/// Provider to watch a specific activity by activityId
/// This ensures the UI updates when the activity data changes in the database

final class ActivityDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({Activity activity, Event? event})>,
          String
        > {
  const ActivityDetailFamily._()
    : super(
        retry: null,
        name: r'activityDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to watch a specific activity by activityId
  /// This ensures the UI updates when the activity data changes in the database

  ActivityDetailProvider call(String activityId) =>
      ActivityDetailProvider._(argument: activityId, from: this);

  @override
  String toString() => r'activityDetailProvider';
}

/// Next Upcoming Event Provider - for showing the upcoming event widget
/// Gets the single next upcoming event from today onwards

@ProviderFor(nextUpcomingEvent)
const nextUpcomingEventProvider = NextUpcomingEventProvider._();

/// Next Upcoming Event Provider - for showing the upcoming event widget
/// Gets the single next upcoming event from today onwards

final class NextUpcomingEventProvider
    extends $FunctionalProvider<AsyncValue<Event?>, Event?, FutureOr<Event?>>
    with $FutureModifier<Event?>, $FutureProvider<Event?> {
  /// Next Upcoming Event Provider - for showing the upcoming event widget
  /// Gets the single next upcoming event from today onwards
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
  $FutureProviderElement<Event?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Event?> create(Ref ref) {
    return nextUpcomingEvent(ref);
  }
}

String _$nextUpcomingEventHash() => r'a9a3a0ac592489a9e64b67dbe18cda97c2e4b087';
