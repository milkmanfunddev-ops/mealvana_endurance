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
    r'cc73cf5e82f25db241a9774a636404ed9d51a4f3';

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
