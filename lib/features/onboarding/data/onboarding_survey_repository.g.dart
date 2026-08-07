// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_survey_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(onboardingSurveyRepository)
const onboardingSurveyRepositoryProvider =
    OnboardingSurveyRepositoryProvider._();

final class OnboardingSurveyRepositoryProvider
    extends
        $FunctionalProvider<
          OnboardingSurveyRepository,
          OnboardingSurveyRepository,
          OnboardingSurveyRepository
        >
    with $Provider<OnboardingSurveyRepository> {
  const OnboardingSurveyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingSurveyRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingSurveyRepositoryHash();

  @$internal
  @override
  $ProviderElement<OnboardingSurveyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OnboardingSurveyRepository create(Ref ref) {
    return onboardingSurveyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingSurveyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingSurveyRepository>(value),
    );
  }
}

String _$onboardingSurveyRepositoryHash() =>
    r'a2c435519cbe6e6107dc7124663f9cc1f855242c';
