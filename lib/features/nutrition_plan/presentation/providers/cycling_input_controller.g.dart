// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycling_input_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cycling Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination

@ProviderFor(CyclingInputController)
const cyclingInputControllerProvider = CyclingInputControllerProvider._();

/// Cycling Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
final class CyclingInputControllerProvider
    extends $NotifierProvider<CyclingInputController, CyclingFormState> {
  /// Cycling Input Controller - manages form state and delegates macro generation
  /// FOA COMPLIANT: Contains form state management and business logic coordination
  const CyclingInputControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cyclingInputControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cyclingInputControllerHash();

  @$internal
  @override
  CyclingInputController create() => CyclingInputController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CyclingFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CyclingFormState>(value),
    );
  }
}

String _$cyclingInputControllerHash() =>
    r'3e6280fc22684389fa0aa3061dabd0e9c332f3f2';

/// Cycling Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination

abstract class _$CyclingInputController extends $Notifier<CyclingFormState> {
  CyclingFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CyclingFormState, CyclingFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CyclingFormState, CyclingFormState>,
              CyclingFormState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
