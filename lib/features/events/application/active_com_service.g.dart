// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_com_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Active.com event search service provider

@ProviderFor(activeComService)
const activeComServiceProvider = ActiveComServiceProvider._();

/// Active.com event search service provider

final class ActiveComServiceProvider
    extends
        $FunctionalProvider<
          ActiveComService,
          ActiveComService,
          ActiveComService
        >
    with $Provider<ActiveComService> {
  /// Active.com event search service provider
  const ActiveComServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeComServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeComServiceHash();

  @$internal
  @override
  $ProviderElement<ActiveComService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActiveComService create(Ref ref) {
    return activeComService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveComService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveComService>(value),
    );
  }
}

String _$activeComServiceHash() => r'4ae1089b6aa10f2952af013a76d356ffad8e25cd';
