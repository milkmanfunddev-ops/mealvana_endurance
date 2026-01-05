// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_profile_setup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoachProfileSetupController)
const coachProfileSetupControllerProvider =
    CoachProfileSetupControllerProvider._();

final class CoachProfileSetupControllerProvider
    extends
        $AsyncNotifierProvider<
          CoachProfileSetupController,
          CoachProfileSetupState
        > {
  const CoachProfileSetupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachProfileSetupControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachProfileSetupControllerHash();

  @$internal
  @override
  CoachProfileSetupController create() => CoachProfileSetupController();
}

String _$coachProfileSetupControllerHash() =>
    r'3340367c253d4d4b1d67bc3ee67a285c691482e2';

abstract class _$CoachProfileSetupController
    extends $AsyncNotifier<CoachProfileSetupState> {
  FutureOr<CoachProfileSetupState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<CoachProfileSetupState>, CoachProfileSetupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CoachProfileSetupState>,
                CoachProfileSetupState
              >,
              AsyncValue<CoachProfileSetupState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
