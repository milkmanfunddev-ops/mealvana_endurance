// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_preview_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Digest of the workouts imported during onboarding.
///
/// Recomputes whenever the draft changes (cheap local Drift read; fast-path
/// [TrainingInsights.none] when no platform was connected). Contract: never
/// throws — timeout or any failure Sentry-captures and falls back to the
/// generic digest so the plan reveal always renders.

@ProviderFor(onboardingTrainingInsights)
const onboardingTrainingInsightsProvider =
    OnboardingTrainingInsightsProvider._();

/// Digest of the workouts imported during onboarding.
///
/// Recomputes whenever the draft changes (cheap local Drift read; fast-path
/// [TrainingInsights.none] when no platform was connected). Contract: never
/// throws — timeout or any failure Sentry-captures and falls back to the
/// generic digest so the plan reveal always renders.

final class OnboardingTrainingInsightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingInsights>,
          TrainingInsights,
          FutureOr<TrainingInsights>
        >
    with $FutureModifier<TrainingInsights>, $FutureProvider<TrainingInsights> {
  /// Digest of the workouts imported during onboarding.
  ///
  /// Recomputes whenever the draft changes (cheap local Drift read; fast-path
  /// [TrainingInsights.none] when no platform was connected). Contract: never
  /// throws — timeout or any failure Sentry-captures and falls back to the
  /// generic digest so the plan reveal always renders.
  const OnboardingTrainingInsightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingTrainingInsightsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingTrainingInsightsHash();

  @$internal
  @override
  $FutureProviderElement<TrainingInsights> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrainingInsights> create(Ref ref) {
    return onboardingTrainingInsights(ref);
  }
}

String _$onboardingTrainingInsightsHash() =>
    r'73387e6b068f2f24a4478ec730c25f787b69dc4b';

/// The plan preview both reveal screens render, personalized from imported
/// training data when the reliability gate passes. keepAlive + draft watch:
/// computed once per flow entry, cached across the two screens, recomputed
/// whenever any draft input changes.

@ProviderFor(onboardingPlanPreview)
const onboardingPlanPreviewProvider = OnboardingPlanPreviewProvider._();

/// The plan preview both reveal screens render, personalized from imported
/// training data when the reliability gate passes. keepAlive + draft watch:
/// computed once per flow entry, cached across the two screens, recomputed
/// whenever any draft input changes.

final class OnboardingPlanPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnboardingPreviewBundle>,
          OnboardingPreviewBundle,
          FutureOr<OnboardingPreviewBundle>
        >
    with
        $FutureModifier<OnboardingPreviewBundle>,
        $FutureProvider<OnboardingPreviewBundle> {
  /// The plan preview both reveal screens render, personalized from imported
  /// training data when the reliability gate passes. keepAlive + draft watch:
  /// computed once per flow entry, cached across the two screens, recomputed
  /// whenever any draft input changes.
  const OnboardingPlanPreviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingPlanPreviewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingPlanPreviewHash();

  @$internal
  @override
  $FutureProviderElement<OnboardingPreviewBundle> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OnboardingPreviewBundle> create(Ref ref) {
    return onboardingPlanPreview(ref);
  }
}

String _$onboardingPlanPreviewHash() =>
    r'b760d3a2b670a42b8335a2395a9a5b4ee51dcc77';

/// Weight (lbs) reported by an integration connected during onboarding, for
/// pre-filling the body-composition weight wheel. Lifted from the old
/// user_profile_screen autofill: prefer Garmin (scale data) over the
/// TrainingPeaks/FinalSurge athlete profile. Best-effort — any failure
/// resolves to null (no autofill), never an error.

@ProviderFor(onboardingIntegrationWeightLbs)
const onboardingIntegrationWeightLbsProvider =
    OnboardingIntegrationWeightLbsProvider._();

/// Weight (lbs) reported by an integration connected during onboarding, for
/// pre-filling the body-composition weight wheel. Lifted from the old
/// user_profile_screen autofill: prefer Garmin (scale data) over the
/// TrainingPeaks/FinalSurge athlete profile. Best-effort — any failure
/// resolves to null (no autofill), never an error.

final class OnboardingIntegrationWeightLbsProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// Weight (lbs) reported by an integration connected during onboarding, for
  /// pre-filling the body-composition weight wheel. Lifted from the old
  /// user_profile_screen autofill: prefer Garmin (scale data) over the
  /// TrainingPeaks/FinalSurge athlete profile. Best-effort — any failure
  /// resolves to null (no autofill), never an error.
  const OnboardingIntegrationWeightLbsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingIntegrationWeightLbsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingIntegrationWeightLbsHash();

  @$internal
  @override
  $FutureProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double?> create(Ref ref) {
    return onboardingIntegrationWeightLbs(ref);
  }
}

String _$onboardingIntegrationWeightLbsHash() =>
    r'b711401b62f165403ea7fcd660ae260f17ce307b';
