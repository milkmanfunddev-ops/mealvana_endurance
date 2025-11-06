// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_survey_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the feature survey screen
/// Manages user's feature selections and submission flow

@ProviderFor(FeatureSurveyController)
const featureSurveyControllerProvider = FeatureSurveyControllerProvider._();

/// Controller for the feature survey screen
/// Manages user's feature selections and submission flow
final class FeatureSurveyControllerProvider
    extends
        $AsyncNotifierProvider<FeatureSurveyController, FeatureSurveyState> {
  /// Controller for the feature survey screen
  /// Manages user's feature selections and submission flow
  const FeatureSurveyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureSurveyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureSurveyControllerHash();

  @$internal
  @override
  FeatureSurveyController create() => FeatureSurveyController();
}

String _$featureSurveyControllerHash() =>
    r'28c16a99ef8b12a57b601ddee5d5d1299a3b82bd';

/// Controller for the feature survey screen
/// Manages user's feature selections and submission flow

abstract class _$FeatureSurveyController
    extends $AsyncNotifier<FeatureSurveyState> {
  FutureOr<FeatureSurveyState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<FeatureSurveyState>, FeatureSurveyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FeatureSurveyState>, FeatureSurveyState>,
              AsyncValue<FeatureSurveyState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
