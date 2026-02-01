// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_sync_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activitySyncHandler)
const activitySyncHandlerProvider = ActivitySyncHandlerProvider._();

final class ActivitySyncHandlerProvider
    extends
        $FunctionalProvider<
          ActivitySyncHandler,
          ActivitySyncHandler,
          ActivitySyncHandler
        >
    with $Provider<ActivitySyncHandler> {
  const ActivitySyncHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitySyncHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitySyncHandlerHash();

  @$internal
  @override
  $ProviderElement<ActivitySyncHandler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivitySyncHandler create(Ref ref) {
    return activitySyncHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivitySyncHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivitySyncHandler>(value),
    );
  }
}

String _$activitySyncHandlerHash() =>
    r'b9d282b42917ffd18822e606537fc2615a6061df';
