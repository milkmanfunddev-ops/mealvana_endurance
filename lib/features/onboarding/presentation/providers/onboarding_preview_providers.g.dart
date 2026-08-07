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

/// Athlete details from the platforms connected during onboarding, used to
/// pre-fill the personal-info and body-composition steps.
///
/// Per-field precedence, and the reason for it:
///
///  - **weight**: Garmin first (it is scale data, and the freshest), then
///    TrainingPeaks' profile figure.
///  - **birth year / gender**: TrainingPeaks only — it is the sole provider
///    that returns them.
///  - **name / email**: TrainingPeaks, then Final Surge. Deliberately NOT
///    Garmin or V.O2: those store the literal strings 'Garmin Connect' and
///    'V.O2' in `providerAthleteName`, so trusting them would write
///    "Garmin"/"Connect" into someone's name fields.
///
/// No provider reports height, so the height wheels keep their defaults.
///
/// Best-effort throughout: any failure resolves to an empty profile (no
/// autofill), never an error — a convenience must not block onboarding.

@ProviderFor(onboardingIntegrationProfile)
const onboardingIntegrationProfileProvider =
    OnboardingIntegrationProfileProvider._();

/// Athlete details from the platforms connected during onboarding, used to
/// pre-fill the personal-info and body-composition steps.
///
/// Per-field precedence, and the reason for it:
///
///  - **weight**: Garmin first (it is scale data, and the freshest), then
///    TrainingPeaks' profile figure.
///  - **birth year / gender**: TrainingPeaks only — it is the sole provider
///    that returns them.
///  - **name / email**: TrainingPeaks, then Final Surge. Deliberately NOT
///    Garmin or V.O2: those store the literal strings 'Garmin Connect' and
///    'V.O2' in `providerAthleteName`, so trusting them would write
///    "Garmin"/"Connect" into someone's name fields.
///
/// No provider reports height, so the height wheels keep their defaults.
///
/// Best-effort throughout: any failure resolves to an empty profile (no
/// autofill), never an error — a convenience must not block onboarding.

final class OnboardingIntegrationProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnboardingIntegrationProfile>,
          OnboardingIntegrationProfile,
          FutureOr<OnboardingIntegrationProfile>
        >
    with
        $FutureModifier<OnboardingIntegrationProfile>,
        $FutureProvider<OnboardingIntegrationProfile> {
  /// Athlete details from the platforms connected during onboarding, used to
  /// pre-fill the personal-info and body-composition steps.
  ///
  /// Per-field precedence, and the reason for it:
  ///
  ///  - **weight**: Garmin first (it is scale data, and the freshest), then
  ///    TrainingPeaks' profile figure.
  ///  - **birth year / gender**: TrainingPeaks only — it is the sole provider
  ///    that returns them.
  ///  - **name / email**: TrainingPeaks, then Final Surge. Deliberately NOT
  ///    Garmin or V.O2: those store the literal strings 'Garmin Connect' and
  ///    'V.O2' in `providerAthleteName`, so trusting them would write
  ///    "Garmin"/"Connect" into someone's name fields.
  ///
  /// No provider reports height, so the height wheels keep their defaults.
  ///
  /// Best-effort throughout: any failure resolves to an empty profile (no
  /// autofill), never an error — a convenience must not block onboarding.
  const OnboardingIntegrationProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingIntegrationProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingIntegrationProfileHash();

  @$internal
  @override
  $FutureProviderElement<OnboardingIntegrationProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OnboardingIntegrationProfile> create(Ref ref) {
    return onboardingIntegrationProfile(ref);
  }
}

String _$onboardingIntegrationProfileHash() =>
    r'70850cd09641ac914722e341cf920ccbd4367594';

/// Weight (lbs) from [onboardingIntegrationProfile], kept as its own
/// provider so the body-composition wheel can listen to just that value.

@ProviderFor(onboardingIntegrationWeightLbs)
const onboardingIntegrationWeightLbsProvider =
    OnboardingIntegrationWeightLbsProvider._();

/// Weight (lbs) from [onboardingIntegrationProfile], kept as its own
/// provider so the body-composition wheel can listen to just that value.

final class OnboardingIntegrationWeightLbsProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// Weight (lbs) from [onboardingIntegrationProfile], kept as its own
  /// provider so the body-composition wheel can listen to just that value.
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
    r'9836e59aa94b2fafef5042fdcf30578c66896a4c';
