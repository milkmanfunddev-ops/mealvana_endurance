// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the most recent list (or the one opened from "Previous lists")
/// through `vana-action`, groups it by aisle, and routes every edit — tick,
/// add, rename, delete, new list — back through the same actions. Each
/// write is optimistic on screen and settled by the server's answer.
///
/// Offline the server is unreachable, so the active plan's own mirror
/// (`meal_plans.shopping`, kept in Drift) stands in read-only: the same
/// lines, no ids, no edits.

@ProviderFor(ShoppingListController)
const shoppingListControllerProvider = ShoppingListControllerProvider._();

/// Reads the most recent list (or the one opened from "Previous lists")
/// through `vana-action`, groups it by aisle, and routes every edit — tick,
/// add, rename, delete, new list — back through the same actions. Each
/// write is optimistic on screen and settled by the server's answer.
///
/// Offline the server is unreachable, so the active plan's own mirror
/// (`meal_plans.shopping`, kept in Drift) stands in read-only: the same
/// lines, no ids, no edits.
final class ShoppingListControllerProvider
    extends $AsyncNotifierProvider<ShoppingListController, ShoppingListState> {
  /// Reads the most recent list (or the one opened from "Previous lists")
  /// through `vana-action`, groups it by aisle, and routes every edit — tick,
  /// add, rename, delete, new list — back through the same actions. Each
  /// write is optimistic on screen and settled by the server's answer.
  ///
  /// Offline the server is unreachable, so the active plan's own mirror
  /// (`meal_plans.shopping`, kept in Drift) stands in read-only: the same
  /// lines, no ids, no edits.
  const ShoppingListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shoppingListControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shoppingListControllerHash();

  @$internal
  @override
  ShoppingListController create() => ShoppingListController();
}

String _$shoppingListControllerHash() =>
    r'5b98f7eb619c5a40107c74473a97f18fb9177b27';

/// Reads the most recent list (or the one opened from "Previous lists")
/// through `vana-action`, groups it by aisle, and routes every edit — tick,
/// add, rename, delete, new list — back through the same actions. Each
/// write is optimistic on screen and settled by the server's answer.
///
/// Offline the server is unreachable, so the active plan's own mirror
/// (`meal_plans.shopping`, kept in Drift) stands in read-only: the same
/// lines, no ids, no edits.

abstract class _$ShoppingListController
    extends $AsyncNotifier<ShoppingListState> {
  FutureOr<ShoppingListState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<ShoppingListState>, ShoppingListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ShoppingListState>, ShoppingListState>,
              AsyncValue<ShoppingListState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
