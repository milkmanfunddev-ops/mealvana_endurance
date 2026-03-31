// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_events_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for PublicEventsService

@ProviderFor(publicEventsService)
const publicEventsServiceProvider = PublicEventsServiceProvider._();

/// Provider for PublicEventsService

final class PublicEventsServiceProvider
    extends
        $FunctionalProvider<
          PublicEventsService,
          PublicEventsService,
          PublicEventsService
        >
    with $Provider<PublicEventsService> {
  /// Provider for PublicEventsService
  const PublicEventsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicEventsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicEventsServiceHash();

  @$internal
  @override
  $ProviderElement<PublicEventsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PublicEventsService create(Ref ref) {
    return publicEventsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PublicEventsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PublicEventsService>(value),
    );
  }
}

String _$publicEventsServiceHash() =>
    r'a6eb6097bc7f0e5e966c978f425e2325080ab748';
