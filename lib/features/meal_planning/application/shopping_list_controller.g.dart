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
/// retry timer. A tick made on the offline copy has no row id: it waits in
/// the store while the offline copy is on screen (the retry timer probes
/// for the live list instead) and is matched by name once the plan's live
/// list loads (110-001). A refusal the server answers (any other error)
/// rolls the tick back and rethrows so the screen can say so.
///
/// The Drift mirror (`meal_plans.shopping`) is never replayed onto the
/// server — that would clobber ticks made online — but every settled write
/// on a plan's list is copied into it (110-003), so a cold offline start
/// shows what this phone last saw.

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
/// retry timer. A tick made on the offline copy has no row id: it waits in
/// the store while the offline copy is on screen (the retry timer probes
/// for the live list instead) and is matched by name once the plan's live
/// list loads (110-001). A refusal the server answers (any other error)
/// rolls the tick back and rethrows so the screen can say so.
///
/// The Drift mirror (`meal_plans.shopping`) is never replayed onto the
/// server — that would clobber ticks made online — but every settled write
/// on a plan's list is copied into it (110-003), so a cold offline start
/// shows what this phone last saw.
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
  /// retry timer. A tick made on the offline copy has no row id: it waits in
  /// the store while the offline copy is on screen (the retry timer probes
  /// for the live list instead) and is matched by name once the plan's live
  /// list loads (110-001). A refusal the server answers (any other error)
  /// rolls the tick back and rethrows so the screen can say so.
  ///
  /// The Drift mirror (`meal_plans.shopping`) is never replayed onto the
  /// server — that would clobber ticks made online — but every settled write
  /// on a plan's list is copied into it (110-003), so a cold offline start
  /// shows what this phone last saw.
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
    r'aece6b2f635e4c302647938886c1611f14f1dd14';

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
/// retry timer. A tick made on the offline copy has no row id: it waits in
/// the store while the offline copy is on screen (the retry timer probes
/// for the live list instead) and is matched by name once the plan's live
/// list loads (110-001). A refusal the server answers (any other error)
/// rolls the tick back and rethrows so the screen can say so.
///
/// The Drift mirror (`meal_plans.shopping`) is never replayed onto the
/// server — that would clobber ticks made online — but every settled write
/// on a plan's list is copied into it (110-003), so a cold offline start
/// shows what this phone last saw.

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
