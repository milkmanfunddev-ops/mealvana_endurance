// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'survey_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SurveyController)
const surveyControllerProvider = SurveyControllerProvider._();

final class SurveyControllerProvider
    extends $AsyncNotifierProvider<SurveyController, SurveyState> {
  const SurveyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'surveyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$surveyControllerHash();

  @$internal
  @override
  SurveyController create() => SurveyController();
}

String _$surveyControllerHash() => r'8b44db19cd8b8bee6aec9f9fc4001933a7221399';

abstract class _$SurveyController extends $AsyncNotifier<SurveyState> {
  FutureOr<SurveyState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<SurveyState>, SurveyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SurveyState>, SurveyState>,
              AsyncValue<SurveyState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
