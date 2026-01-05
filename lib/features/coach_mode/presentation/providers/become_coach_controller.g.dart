// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'become_coach_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BecomeCoachController)
const becomeCoachControllerProvider = BecomeCoachControllerProvider._();

final class BecomeCoachControllerProvider
    extends $AsyncNotifierProvider<BecomeCoachController, void> {
  const BecomeCoachControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'becomeCoachControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$becomeCoachControllerHash();

  @$internal
  @override
  BecomeCoachController create() => BecomeCoachController();
}

String _$becomeCoachControllerHash() =>
    r'5de7f0450f23a637761f0bc7342c7fa0a4d692ae';

abstract class _$BecomeCoachController extends $AsyncNotifier<void> {
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
