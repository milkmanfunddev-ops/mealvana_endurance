// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'running_input_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Running Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination

@ProviderFor(RunningInputController)
const runningInputControllerProvider = RunningInputControllerProvider._();

/// Running Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
final class RunningInputControllerProvider
    extends $NotifierProvider<RunningInputController, RunningFormState> {
  /// Running Input Controller - manages form state and delegates macro generation
  /// FOA COMPLIANT: Contains form state management and business logic coordination
  const RunningInputControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningInputControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningInputControllerHash();

  @$internal
  @override
  RunningInputController create() => RunningInputController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RunningFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RunningFormState>(value),
    );
  }
}

String _$runningInputControllerHash() =>
    r'579cb786b08a18f68b27075e269a2d718e8d22d7';

/// Running Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination

abstract class _$RunningInputController extends $Notifier<RunningFormState> {
  RunningFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<RunningFormState, RunningFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RunningFormState, RunningFormState>,
              RunningFormState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
