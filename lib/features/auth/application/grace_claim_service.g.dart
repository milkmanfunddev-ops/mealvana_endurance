// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grace_claim_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(graceClaimService)
const graceClaimServiceProvider = GraceClaimServiceProvider._();

final class GraceClaimServiceProvider
    extends
        $FunctionalProvider<
          GraceClaimService,
          GraceClaimService,
          GraceClaimService
        >
    with $Provider<GraceClaimService> {
  const GraceClaimServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graceClaimServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graceClaimServiceHash();

  @$internal
  @override
  $ProviderElement<GraceClaimService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GraceClaimService create(Ref ref) {
    return graceClaimService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GraceClaimService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GraceClaimService>(value),
    );
  }
}

String _$graceClaimServiceHash() => r'cb3f090990b7d945b3f93fd81eca789a76e26961';
