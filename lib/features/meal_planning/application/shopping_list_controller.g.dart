// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Groups the active plan's `shopping` by aisle and routes the local-first
/// `checked` / `have` toggles through [MealPlanController].

@ProviderFor(ShoppingListController)
const shoppingListControllerProvider = ShoppingListControllerProvider._();

/// Groups the active plan's `shopping` by aisle and routes the local-first
/// `checked` / `have` toggles through [MealPlanController].
final class ShoppingListControllerProvider
    extends $AsyncNotifierProvider<ShoppingListController, ShoppingListState> {
  /// Groups the active plan's `shopping` by aisle and routes the local-first
  /// `checked` / `have` toggles through [MealPlanController].
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
    r'bf96529d09bd7e1049b2452c2d176ccb42dee9b5';

/// Groups the active plan's `shopping` by aisle and routes the local-first
/// `checked` / `have` toggles through [MealPlanController].

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
