// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_sync_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coachSyncHandler)
const coachSyncHandlerProvider = CoachSyncHandlerProvider._();

final class CoachSyncHandlerProvider
    extends
        $FunctionalProvider<
          CoachSyncHandler,
          CoachSyncHandler,
          CoachSyncHandler
        >
    with $Provider<CoachSyncHandler> {
  const CoachSyncHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachSyncHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachSyncHandlerHash();

  @$internal
  @override
  $ProviderElement<CoachSyncHandler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachSyncHandler create(Ref ref) {
    return coachSyncHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachSyncHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachSyncHandler>(value),
    );
  }
}

String _$coachSyncHandlerHash() => r'12904f1f2aa0a8d00625078a707c4f28d5bb9f47';
