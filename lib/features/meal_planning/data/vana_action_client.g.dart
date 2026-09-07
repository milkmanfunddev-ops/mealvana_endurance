// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_action_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vanaActionClient)
const vanaActionClientProvider = VanaActionClientProvider._();

final class VanaActionClientProvider
    extends
        $FunctionalProvider<
          VanaActionClient,
          VanaActionClient,
          VanaActionClient
        >
    with $Provider<VanaActionClient> {
  const VanaActionClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaActionClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaActionClientHash();

  @$internal
  @override
  $ProviderElement<VanaActionClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VanaActionClient create(Ref ref) {
    return vanaActionClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaActionClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaActionClient>(value),
    );
  }
}

String _$vanaActionClientHash() => r'416c3e74f5351eeb832d2d31cbdf3f935be30197';
