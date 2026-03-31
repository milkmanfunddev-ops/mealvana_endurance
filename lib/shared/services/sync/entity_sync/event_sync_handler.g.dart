// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_sync_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(eventSyncHandler)
const eventSyncHandlerProvider = EventSyncHandlerProvider._();

final class EventSyncHandlerProvider
    extends
        $FunctionalProvider<
          EventSyncHandler,
          EventSyncHandler,
          EventSyncHandler
        >
    with $Provider<EventSyncHandler> {
  const EventSyncHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventSyncHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventSyncHandlerHash();

  @$internal
  @override
  $ProviderElement<EventSyncHandler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventSyncHandler create(Ref ref) {
    return eventSyncHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventSyncHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventSyncHandler>(value),
    );
  }
}

String _$eventSyncHandlerHash() => r'abc74822ce16067216d3adf1106cc115b324badf';
