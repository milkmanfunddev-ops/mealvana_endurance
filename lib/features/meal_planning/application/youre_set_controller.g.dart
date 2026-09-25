// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'youre_set_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which plan is owed the "you're set" card (mp-235, ticket 131).
///
/// [MealPlanController.confirmPlan] sets it on every confirm the server
/// acknowledged (the Review sheet, the Plan tab, an earlier plan), and each
/// of those lands on Food > Shopping, where the card sits at the top of the
/// new list. It shows once: dismissing it or leaving Shopping clears it,
/// so the next open has none. In memory only, so a relaunch has none either.
///
/// Session-scoped (`keepAlive`): the confirm happens on one screen and the
/// card draws on another.

@ProviderFor(YoureSetController)
const youreSetControllerProvider = YoureSetControllerProvider._();

/// Which plan is owed the "you're set" card (mp-235, ticket 131).
///
/// [MealPlanController.confirmPlan] sets it on every confirm the server
/// acknowledged (the Review sheet, the Plan tab, an earlier plan), and each
/// of those lands on Food > Shopping, where the card sits at the top of the
/// new list. It shows once: dismissing it or leaving Shopping clears it,
/// so the next open has none. In memory only, so a relaunch has none either.
///
/// Session-scoped (`keepAlive`): the confirm happens on one screen and the
/// card draws on another.
final class YoureSetControllerProvider
    extends $AsyncNotifierProvider<YoureSetController, YoureSet?> {
  /// Which plan is owed the "you're set" card (mp-235, ticket 131).
  ///
  /// [MealPlanController.confirmPlan] sets it on every confirm the server
  /// acknowledged (the Review sheet, the Plan tab, an earlier plan), and each
  /// of those lands on Food > Shopping, where the card sits at the top of the
  /// new list. It shows once: dismissing it or leaving Shopping clears it,
  /// so the next open has none. In memory only, so a relaunch has none either.
  ///
  /// Session-scoped (`keepAlive`): the confirm happens on one screen and the
  /// card draws on another.
  const YoureSetControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'youreSetControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$youreSetControllerHash();

  @$internal
  @override
  YoureSetController create() => YoureSetController();
}

String _$youreSetControllerHash() =>
    r'9f3ae2aefd7f30fd224596fb0acfb5b0d7db5c3c';

/// Which plan is owed the "you're set" card (mp-235, ticket 131).
///
/// [MealPlanController.confirmPlan] sets it on every confirm the server
/// acknowledged (the Review sheet, the Plan tab, an earlier plan), and each
/// of those lands on Food > Shopping, where the card sits at the top of the
/// new list. It shows once: dismissing it or leaving Shopping clears it,
/// so the next open has none. In memory only, so a relaunch has none either.
///
/// Session-scoped (`keepAlive`): the confirm happens on one screen and the
/// card draws on another.

abstract class _$YoureSetController extends $AsyncNotifier<YoureSet?> {
  FutureOr<YoureSet?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<YoureSet?>, YoureSet?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<YoureSet?>, YoureSet?>,
              AsyncValue<YoureSet?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
