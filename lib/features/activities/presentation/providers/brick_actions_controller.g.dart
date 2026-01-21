// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_actions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for handling brick workout actions (create, ungroup, remove segments)
///
/// This controller manages the business logic for:
/// - Creating brick workouts from selected activities
/// - Ungrouping brick workouts back to standalone activities
/// - Removing segments from existing brick workouts
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
/// All business logic is in the controller, NOT in UI screens.

@ProviderFor(BrickActionsController)
const brickActionsControllerProvider = BrickActionsControllerProvider._();

/// Controller for handling brick workout actions (create, ungroup, remove segments)
///
/// This controller manages the business logic for:
/// - Creating brick workouts from selected activities
/// - Ungrouping brick workouts back to standalone activities
/// - Removing segments from existing brick workouts
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
/// All business logic is in the controller, NOT in UI screens.
final class BrickActionsControllerProvider
    extends $AsyncNotifierProvider<BrickActionsController, void> {
  /// Controller for handling brick workout actions (create, ungroup, remove segments)
  ///
  /// This controller manages the business logic for:
  /// - Creating brick workouts from selected activities
  /// - Ungrouping brick workouts back to standalone activities
  /// - Removing segments from existing brick workouts
  ///
  /// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
  /// All business logic is in the controller, NOT in UI screens.
  const BrickActionsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brickActionsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brickActionsControllerHash();

  @$internal
  @override
  BrickActionsController create() => BrickActionsController();
}

String _$brickActionsControllerHash() =>
    r'15f5c66c264f651ef9b952281e11fa6cca5f3737';

/// Controller for handling brick workout actions (create, ungroup, remove segments)
///
/// This controller manages the business logic for:
/// - Creating brick workouts from selected activities
/// - Ungrouping brick workouts back to standalone activities
/// - Removing segments from existing brick workouts
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
/// All business logic is in the controller, NOT in UI screens.

abstract class _$BrickActionsController extends $AsyncNotifier<void> {
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
