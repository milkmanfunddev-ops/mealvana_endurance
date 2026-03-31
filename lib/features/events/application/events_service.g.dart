// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(eventsService)
const eventsServiceProvider = EventsServiceProvider._();

final class EventsServiceProvider
    extends $FunctionalProvider<EventsService, EventsService, EventsService>
    with $Provider<EventsService> {
  const EventsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsServiceHash();

  @$internal
  @override
  $ProviderElement<EventsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventsService create(Ref ref) {
    return eventsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventsService>(value),
    );
  }
}

String _$eventsServiceHash() => r'05c5ee914f3f35ee069d9fed00266481d4f54cdf';
