// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_input_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Brick Input Controller
///
/// Manages brick workout form state including:
/// - Sport selection (which sports are included)
/// - Segment order (drag to reorder)
/// - Form inputs for each sport segment
///
/// FOA COMPLIANT: Contains form state management only, business logic
/// delegated to services.

@ProviderFor(BrickInputController)
const brickInputControllerProvider = BrickInputControllerProvider._();

/// Brick Input Controller
///
/// Manages brick workout form state including:
/// - Sport selection (which sports are included)
/// - Segment order (drag to reorder)
/// - Form inputs for each sport segment
///
/// FOA COMPLIANT: Contains form state management only, business logic
/// delegated to services.
final class BrickInputControllerProvider
    extends $NotifierProvider<BrickInputController, BrickFormState> {
  /// Brick Input Controller
  ///
  /// Manages brick workout form state including:
  /// - Sport selection (which sports are included)
  /// - Segment order (drag to reorder)
  /// - Form inputs for each sport segment
  ///
  /// FOA COMPLIANT: Contains form state management only, business logic
  /// delegated to services.
  const BrickInputControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brickInputControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brickInputControllerHash();

  @$internal
  @override
  BrickInputController create() => BrickInputController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrickFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrickFormState>(value),
    );
  }
}

String _$brickInputControllerHash() =>
    r'00686806aa6d1ae1fe76ca7ce7ee6e12056621e5';

/// Brick Input Controller
///
/// Manages brick workout form state including:
/// - Sport selection (which sports are included)
/// - Segment order (drag to reorder)
/// - Form inputs for each sport segment
///
/// FOA COMPLIANT: Contains form state management only, business logic
/// delegated to services.

abstract class _$BrickInputController extends $Notifier<BrickFormState> {
  BrickFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<BrickFormState, BrickFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BrickFormState, BrickFormState>,
              BrickFormState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
