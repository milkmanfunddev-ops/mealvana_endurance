// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_preview_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single draft field the imported-workout digest depends on, exposed as
/// its own provider so the digest is insulated from unrelated draft churn.
///
/// The controller's `_updateDraft` force-notifies on EVERY mutator — and the
/// plan-reveal sliders route each release through `applyPlanEdits` — so a
/// digest that watched the controller directly re-ran its 456-day activities
/// scan on every slider release. A plain provider recomputes on notify but
/// only rebuilds dependents when the returned VALUE changes, which for this
/// string is exactly the connect/disconnect transitions.

@ProviderFor(onboardingConnectedProviderName)
const onboardingConnectedProviderNameProvider =
    OnboardingConnectedProviderNameProvider._();

/// The single draft field the imported-workout digest depends on, exposed as
/// its own provider so the digest is insulated from unrelated draft churn.
///
/// The controller's `_updateDraft` force-notifies on EVERY mutator — and the
/// plan-reveal sliders route each release through `applyPlanEdits` — so a
/// digest that watched the controller directly re-ran its 456-day activities
/// scan on every slider release. A plain provider recomputes on notify but
/// only rebuilds dependents when the returned VALUE changes, which for this
/// string is exactly the connect/disconnect transitions.

final class OnboardingConnectedProviderNameProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The single draft field the imported-workout digest depends on, exposed as
  /// its own provider so the digest is insulated from unrelated draft churn.
  ///
  /// The controller's `_updateDraft` force-notifies on EVERY mutator — and the
  /// plan-reveal sliders route each release through `applyPlanEdits` — so a
  /// digest that watched the controller directly re-ran its 456-day activities
  /// scan on every slider release. A plain provider recomputes on notify but
  /// only rebuilds dependents when the returned VALUE changes, which for this
  /// string is exactly the connect/disconnect transitions.
  const OnboardingConnectedProviderNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingConnectedProviderNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingConnectedProviderNameHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return onboardingConnectedProviderName(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$onboardingConnectedProviderNameHash() =>
    r'91fab01c94b71cceea296205abc35d14fe1b1923';

/// Digest of the workouts imported during onboarding.
///
/// Recomputes when the connected provider changes (cheap local Drift read;
/// fast-path [TrainingInsights.none] when no platform was connected) — NOT
/// on every draft notify; see [onboardingConnectedProviderName]. The plan
/// reveal additionally invalidates this on entry so imports that finished
/// landing after the connect step still get digested. Contract: never
/// throws — timeout or any failure Sentry-captures and falls back to the
/// generic digest so the plan reveal always renders.

@ProviderFor(onboardingTrainingInsights)
const onboardingTrainingInsightsProvider =
    OnboardingTrainingInsightsProvider._();

/// Digest of the workouts imported during onboarding.
///
/// Recomputes when the connected provider changes (cheap local Drift read;
/// fast-path [TrainingInsights.none] when no platform was connected) — NOT
/// on every draft notify; see [onboardingConnectedProviderName]. The plan
/// reveal additionally invalidates this on entry so imports that finished
/// landing after the connect step still get digested. Contract: never
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
  /// Recomputes when the connected provider changes (cheap local Drift read;
  /// fast-path [TrainingInsights.none] when no platform was connected) — NOT
  /// on every draft notify; see [onboardingConnectedProviderName]. The plan
  /// reveal additionally invalidates this on entry so imports that finished
  /// landing after the connect step still get digested. Contract: never
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
    r'aeb7d0c0b5dd85c58f197fc063e7128d2adb12fc';

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
