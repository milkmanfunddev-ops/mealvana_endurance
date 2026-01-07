// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_registration_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoachRegistrationController)
const coachRegistrationControllerProvider =
    CoachRegistrationControllerProvider._();

final class CoachRegistrationControllerProvider
    extends $AsyncNotifierProvider<CoachRegistrationController, void> {
  const CoachRegistrationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachRegistrationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachRegistrationControllerHash();

  @$internal
  @override
  CoachRegistrationController create() => CoachRegistrationController();
}

String _$coachRegistrationControllerHash() =>
    r'f3b62a0bbde9b662017d1e2c0ce89fc84a180723';

abstract class _$CoachRegistrationController extends $AsyncNotifier<void> {
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
