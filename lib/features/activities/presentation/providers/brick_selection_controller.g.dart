// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_selection_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing brick workout selection mode
///
/// Handles the UI flow for creating brick workouts from existing activities:
/// - Enter/exit selection mode
/// - Toggle activity selection with order tracking (1, 2, 3)
/// - Validate selection (2-3 activities, different sports, same day)
/// - Provide selection order for brick creation
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.

@ProviderFor(BrickSelectionController)
const brickSelectionControllerProvider = BrickSelectionControllerProvider._();

/// Controller for managing brick workout selection mode
///
/// Handles the UI flow for creating brick workouts from existing activities:
/// - Enter/exit selection mode
/// - Toggle activity selection with order tracking (1, 2, 3)
/// - Validate selection (2-3 activities, different sports, same day)
/// - Provide selection order for brick creation
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
final class BrickSelectionControllerProvider
    extends $NotifierProvider<BrickSelectionController, BrickSelectionState> {
  /// Controller for managing brick workout selection mode
  ///
  /// Handles the UI flow for creating brick workouts from existing activities:
  /// - Enter/exit selection mode
  /// - Toggle activity selection with order tracking (1, 2, 3)
  /// - Validate selection (2-3 activities, different sports, same day)
  /// - Provide selection order for brick creation
  ///
  /// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
  const BrickSelectionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brickSelectionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brickSelectionControllerHash();

  @$internal
  @override
  BrickSelectionController create() => BrickSelectionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrickSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrickSelectionState>(value),
    );
  }
}

String _$brickSelectionControllerHash() =>
    r'29c0120125d1bdab7455d80694ae012448205c07';

/// Controller for managing brick workout selection mode
///
/// Handles the UI flow for creating brick workouts from existing activities:
/// - Enter/exit selection mode
/// - Toggle activity selection with order tracking (1, 2, 3)
/// - Validate selection (2-3 activities, different sports, same day)
/// - Provide selection order for brick creation
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.

abstract class _$BrickSelectionController
    extends $Notifier<BrickSelectionState> {
  BrickSelectionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<BrickSelectionState, BrickSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BrickSelectionState, BrickSelectionState>,
              BrickSelectionState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
