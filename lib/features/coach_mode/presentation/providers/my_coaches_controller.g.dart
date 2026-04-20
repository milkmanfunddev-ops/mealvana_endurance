// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_coaches_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MyCoachesController)
const myCoachesControllerProvider = MyCoachesControllerProvider._();

final class MyCoachesControllerProvider
    extends $AsyncNotifierProvider<MyCoachesController, MyCoachesState> {
  const MyCoachesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myCoachesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myCoachesControllerHash();

  @$internal
  @override
  MyCoachesController create() => MyCoachesController();
}

String _$myCoachesControllerHash() =>
    r'04462a718bd9e0d31fcf58c4ba4b70cc1f5416e5';

abstract class _$MyCoachesController extends $AsyncNotifier<MyCoachesState> {
  FutureOr<MyCoachesState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<MyCoachesState>, MyCoachesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MyCoachesState>, MyCoachesState>,
              AsyncValue<MyCoachesState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
