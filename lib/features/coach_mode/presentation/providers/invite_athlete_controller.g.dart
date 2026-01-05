// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_athlete_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InviteAthleteController)
const inviteAthleteControllerProvider = InviteAthleteControllerProvider._();

final class InviteAthleteControllerProvider
    extends $AsyncNotifierProvider<InviteAthleteController, void> {
  const InviteAthleteControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteAthleteControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteAthleteControllerHash();

  @$internal
  @override
  InviteAthleteController create() => InviteAthleteController();
}

String _$inviteAthleteControllerHash() =>
    r'1cb2cd97d625479675fe39eb0b6acf635930e4ac';

abstract class _$InviteAthleteController extends $AsyncNotifier<void> {
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
