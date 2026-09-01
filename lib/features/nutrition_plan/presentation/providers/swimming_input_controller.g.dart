// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swimming_input_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Swimming Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination

@ProviderFor(SwimmingInputController)
const swimmingInputControllerProvider = SwimmingInputControllerProvider._();

/// Swimming Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
final class SwimmingInputControllerProvider
    extends $NotifierProvider<SwimmingInputController, SwimmingFormState> {
  /// Swimming Input Controller - manages form state and delegates macro generation
  /// FOA COMPLIANT: Contains form state management and business logic coordination
  const SwimmingInputControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'swimmingInputControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$swimmingInputControllerHash();

  @$internal
  @override
  SwimmingInputController create() => SwimmingInputController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SwimmingFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SwimmingFormState>(value),
    );
  }
}

String _$swimmingInputControllerHash() =>
    r'7ccc06ae5f4db822b6483493b65d6e90af1d1721';

/// Swimming Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination

abstract class _$SwimmingInputController extends $Notifier<SwimmingFormState> {
  SwimmingFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SwimmingFormState, SwimmingFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SwimmingFormState, SwimmingFormState>,
              SwimmingFormState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
