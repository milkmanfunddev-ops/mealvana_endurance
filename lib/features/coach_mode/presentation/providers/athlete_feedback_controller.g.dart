// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete_feedback_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AthleteFeedbackController)
const athleteFeedbackControllerProvider = AthleteFeedbackControllerProvider._();

final class AthleteFeedbackControllerProvider
    extends
        $AsyncNotifierProvider<
          AthleteFeedbackController,
          AthleteFeedbackState
        > {
  const AthleteFeedbackControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'athleteFeedbackControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$athleteFeedbackControllerHash();

  @$internal
  @override
  AthleteFeedbackController create() => AthleteFeedbackController();
}

String _$athleteFeedbackControllerHash() =>
    r'a69d2274c4b06529525f8bdd0994249c32767a01';

abstract class _$AthleteFeedbackController
    extends $AsyncNotifier<AthleteFeedbackState> {
  FutureOr<AthleteFeedbackState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<AthleteFeedbackState>, AthleteFeedbackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AthleteFeedbackState>,
                AthleteFeedbackState
              >,
              AsyncValue<AthleteFeedbackState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
