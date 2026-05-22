// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_macros_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DailyMacrosController)
const dailyMacrosControllerProvider = DailyMacrosControllerProvider._();

final class DailyMacrosControllerProvider
    extends $AsyncNotifierProvider<DailyMacrosController, DailyMacrosState> {
  const DailyMacrosControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyMacrosControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyMacrosControllerHash();

  @$internal
  @override
  DailyMacrosController create() => DailyMacrosController();
}

String _$dailyMacrosControllerHash() =>
    r'd02a090fd2bcdedfa03587666e7c452f37c66b24';

abstract class _$DailyMacrosController
    extends $AsyncNotifier<DailyMacrosState> {
  FutureOr<DailyMacrosState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<DailyMacrosState>, DailyMacrosState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DailyMacrosState>, DailyMacrosState>,
              AsyncValue<DailyMacrosState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
