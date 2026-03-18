// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_reports_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoachReportsController)
const coachReportsControllerProvider = CoachReportsControllerProvider._();

final class CoachReportsControllerProvider
    extends $AsyncNotifierProvider<CoachReportsController, CoachReportsState> {
  const CoachReportsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachReportsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachReportsControllerHash();

  @$internal
  @override
  CoachReportsController create() => CoachReportsController();
}

String _$coachReportsControllerHash() =>
    r'60cfd0db0f0ea9e047e4282ed01b6441ea7632f7';

abstract class _$CoachReportsController
    extends $AsyncNotifier<CoachReportsState> {
  FutureOr<CoachReportsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<CoachReportsState>, CoachReportsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CoachReportsState>, CoachReportsState>,
              AsyncValue<CoachReportsState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
