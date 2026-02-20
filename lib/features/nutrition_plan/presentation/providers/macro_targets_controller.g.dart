// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro_targets_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns

@ProviderFor(MacroTargetsController)
const macroTargetsControllerProvider = MacroTargetsControllerProvider._();

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns
final class MacroTargetsControllerProvider
    extends $AsyncNotifierProvider<MacroTargetsController, MacroTargetsState> {
  /// Controller for distance page gut entry screen
  /// FOA COMPLIANT: Contains ALL business logic, no UI concerns
  const MacroTargetsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'macroTargetsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$macroTargetsControllerHash();

  @$internal
  @override
  MacroTargetsController create() => MacroTargetsController();
}

String _$macroTargetsControllerHash() =>
    r'7b5cd060d0dbaa6652454f91e3591464f297a1a8';

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns

abstract class _$MacroTargetsController
    extends $AsyncNotifier<MacroTargetsState> {
  FutureOr<MacroTargetsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<MacroTargetsState>, MacroTargetsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MacroTargetsState>, MacroTargetsState>,
              AsyncValue<MacroTargetsState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
