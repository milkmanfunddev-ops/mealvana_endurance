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
/// (`meal_plans.shopping`, kept in Drift) stands in: the same lines, no
/// ids, no edits except ticks.
///
/// Ticks are local-first (ticket 36, Findings 20-001/20-002): each one is
/// written to [ShoppingTickStore] before `update_shopping_item` goes out
/// and dropped when the server answers. A transport failure keeps the tick
/// on screen and in the store, marks the state offline, and the tick is
/// replayed on the next build, on the next successful call, or by the
/// retry timer. A refusal the server answers (any other error) rolls the
/// tick back and rethrows so the screen can say so. The Drift mirror is
/// never written here: the server keeps `meal_plans.shopping` from
/// `shopping_items`, and a local replay of the mirror would clobber ticks
/// made online.

@ProviderFor(ShoppingListController)
const shoppingListControllerProvider = ShoppingListControllerProvider._();

/// Reads the most recent list (or the one opened from "Previous lists")
/// through `vana-action`, groups it by aisle, and routes every edit — tick,
/// add, rename, delete, new list — back through the same actions. Each
/// write is optimistic on screen and settled by the server's answer.
///
/// Offline the server is unreachable, so the active plan's own mirror
/// (`meal_plans.shopping`, kept in Drift) stands in: the same lines, no
/// ids, no edits except ticks.
///
/// Ticks are local-first (ticket 36, Findings 20-001/20-002): each one is
/// written to [ShoppingTickStore] before `update_shopping_item` goes out
/// and dropped when the server answers. A transport failure keeps the tick
/// on screen and in the store, marks the state offline, and the tick is
/// replayed on the next build, on the next successful call, or by the
/// retry timer. A refusal the server answers (any other error) rolls the
/// tick back and rethrows so the screen can say so. The Drift mirror is
/// never written here: the server keeps `meal_plans.shopping` from
/// `shopping_items`, and a local replay of the mirror would clobber ticks
/// made online.
final class ShoppingListControllerProvider
    extends $AsyncNotifierProvider<ShoppingListController, ShoppingListState> {
  /// Reads the most recent list (or the one opened from "Previous lists")
  /// through `vana-action`, groups it by aisle, and routes every edit — tick,
  /// add, rename, delete, new list — back through the same actions. Each
  /// write is optimistic on screen and settled by the server's answer.
  ///
  /// Offline the server is unreachable, so the active plan's own mirror
  /// (`meal_plans.shopping`, kept in Drift) stands in: the same lines, no
  /// ids, no edits except ticks.
  ///
  /// Ticks are local-first (ticket 36, Findings 20-001/20-002): each one is
  /// written to [ShoppingTickStore] before `update_shopping_item` goes out
  /// and dropped when the server answers. A transport failure keeps the tick
  /// on screen and in the store, marks the state offline, and the tick is
  /// replayed on the next build, on the next successful call, or by the
  /// retry timer. A refusal the server answers (any other error) rolls the
  /// tick back and rethrows so the screen can say so. The Drift mirror is
  /// never written here: the server keeps `meal_plans.shopping` from
  /// `shopping_items`, and a local replay of the mirror would clobber ticks
  /// made online.
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
    r'9a29aba448e5d83dcc85ea2acc97c87bc46013c4';

/// Reads the most recent list (or the one opened from "Previous lists")
/// through `vana-action`, groups it by aisle, and routes every edit — tick,
/// add, rename, delete, new list — back through the same actions. Each
/// write is optimistic on screen and settled by the server's answer.
///
/// Offline the server is unreachable, so the active plan's own mirror
/// (`meal_plans.shopping`, kept in Drift) stands in: the same lines, no
/// ids, no edits except ticks.
///
/// Ticks are local-first (ticket 36, Findings 20-001/20-002): each one is
/// written to [ShoppingTickStore] before `update_shopping_item` goes out
/// and dropped when the server answers. A transport failure keeps the tick
/// on screen and in the store, marks the state offline, and the tick is
/// replayed on the next build, on the next successful call, or by the
/// retry timer. A refusal the server answers (any other error) rolls the
/// tick back and rethrows so the screen can say so. The Drift mirror is
/// never written here: the server keeps `meal_plans.shopping` from
/// `shopping_items`, and a local replay of the mirror would clobber ticks
/// made online.

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
