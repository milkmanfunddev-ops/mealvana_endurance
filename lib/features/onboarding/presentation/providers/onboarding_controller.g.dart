// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing onboarding flow state

@ProviderFor(OnboardingController)
const onboardingControllerProvider = OnboardingControllerProvider._();

/// Controller for managing onboarding flow state
final class OnboardingControllerProvider
    extends $AsyncNotifierProvider<OnboardingController, void> {
  /// Controller for managing onboarding flow state
  const OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();
}

String _$onboardingControllerHash() =>
    r'369bf40491bb31f60112eced7af2ea8f087271aa';

/// Controller for managing onboarding flow state

abstract class _$OnboardingController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}

/// Provider for onboarding progress

@ProviderFor(onboardingProgress)
const onboardingProgressProvider = OnboardingProgressProvider._();

/// Provider for onboarding progress

final class OnboardingProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnboardingProgress>,
          OnboardingProgress,
          FutureOr<OnboardingProgress>
        >
    with
        $FutureModifier<OnboardingProgress>,
        $FutureProvider<OnboardingProgress> {
  /// Provider for onboarding progress
  const OnboardingProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingProgressHash();

  @$internal
  @override
  $FutureProviderElement<OnboardingProgress> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OnboardingProgress> create(Ref ref) {
    return onboardingProgress(ref);
  }
}

String _$onboardingProgressHash() =>
    r'811d98cd3bd2ef13b44db9780bb4ef67e2e0b3b7';
