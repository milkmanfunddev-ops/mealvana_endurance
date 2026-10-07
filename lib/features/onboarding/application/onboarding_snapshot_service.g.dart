// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_snapshot_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(onboardingSnapshotService)
const onboardingSnapshotServiceProvider = OnboardingSnapshotServiceProvider._();

final class OnboardingSnapshotServiceProvider
    extends
        $FunctionalProvider<
          OnboardingSnapshotService,
          OnboardingSnapshotService,
          OnboardingSnapshotService
        >
    with $Provider<OnboardingSnapshotService> {
  const OnboardingSnapshotServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingSnapshotServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingSnapshotServiceHash();

  @$internal
  @override
  $ProviderElement<OnboardingSnapshotService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OnboardingSnapshotService create(Ref ref) {
    return onboardingSnapshotService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingSnapshotService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingSnapshotService>(value),
    );
  }
}

String _$onboardingSnapshotServiceHash() =>
    r'8fd801815b09b879c8b6ccb31e124a89147f9464';
