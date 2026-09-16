// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_photos_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One library Meal's photographs, for the Meal photos page (ADR 0003).
///
/// Every write is **remote-ack only**: no local write, no Drift row, no upload
/// queue. A photograph publishes to every athlete, so "Photo added" may only be
/// said once the server has it (story 32), and with no signal the add must fail
/// where the Tester can see it rather than publish later unwatched (story 33).
///
/// A failure therefore leaves the state exactly as it was and is rethrown for
/// the screen — the page keeps showing what athletes really see, rather than
/// replacing it with an error. (The spec's `AsyncValue.guard()` would instead
/// put the failure *in* the state, which changes it; the ticket's "a thrown
/// failure leaves state unchanged and reaches the screen" wins, and it is what
/// `MealDetailController.review` already does for the other cross-user write.)
///
/// Not `keepAlive`: the page is the only watcher, and reopening it should ask
/// the server again rather than show a Tester a cached History.

@ProviderFor(MealPhotosController)
const mealPhotosControllerProvider = MealPhotosControllerFamily._();

/// One library Meal's photographs, for the Meal photos page (ADR 0003).
///
/// Every write is **remote-ack only**: no local write, no Drift row, no upload
/// queue. A photograph publishes to every athlete, so "Photo added" may only be
/// said once the server has it (story 32), and with no signal the add must fail
/// where the Tester can see it rather than publish later unwatched (story 33).
///
/// A failure therefore leaves the state exactly as it was and is rethrown for
/// the screen — the page keeps showing what athletes really see, rather than
/// replacing it with an error. (The spec's `AsyncValue.guard()` would instead
/// put the failure *in* the state, which changes it; the ticket's "a thrown
/// failure leaves state unchanged and reaches the screen" wins, and it is what
/// `MealDetailController.review` already does for the other cross-user write.)
///
/// Not `keepAlive`: the page is the only watcher, and reopening it should ask
/// the server again rather than show a Tester a cached History.
final class MealPhotosControllerProvider
    extends $AsyncNotifierProvider<MealPhotosController, MealPhotos> {
  /// One library Meal's photographs, for the Meal photos page (ADR 0003).
  ///
  /// Every write is **remote-ack only**: no local write, no Drift row, no upload
  /// queue. A photograph publishes to every athlete, so "Photo added" may only be
  /// said once the server has it (story 32), and with no signal the add must fail
  /// where the Tester can see it rather than publish later unwatched (story 33).
  ///
  /// A failure therefore leaves the state exactly as it was and is rethrown for
  /// the screen — the page keeps showing what athletes really see, rather than
  /// replacing it with an error. (The spec's `AsyncValue.guard()` would instead
  /// put the failure *in* the state, which changes it; the ticket's "a thrown
  /// failure leaves state unchanged and reaches the screen" wins, and it is what
  /// `MealDetailController.review` already does for the other cross-user write.)
  ///
  /// Not `keepAlive`: the page is the only watcher, and reopening it should ask
  /// the server again rather than show a Tester a cached History.
  const MealPhotosControllerProvider._({
    required MealPhotosControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mealPhotosControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mealPhotosControllerHash();

  @override
  String toString() {
    return r'mealPhotosControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MealPhotosController create() => MealPhotosController();

  @override
  bool operator ==(Object other) {
    return other is MealPhotosControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mealPhotosControllerHash() =>
    r'ad7b9b64e2e4d78af8829b067b59c2e46951bc30';

/// One library Meal's photographs, for the Meal photos page (ADR 0003).
///
/// Every write is **remote-ack only**: no local write, no Drift row, no upload
/// queue. A photograph publishes to every athlete, so "Photo added" may only be
/// said once the server has it (story 32), and with no signal the add must fail
/// where the Tester can see it rather than publish later unwatched (story 33).
///
/// A failure therefore leaves the state exactly as it was and is rethrown for
/// the screen — the page keeps showing what athletes really see, rather than
/// replacing it with an error. (The spec's `AsyncValue.guard()` would instead
/// put the failure *in* the state, which changes it; the ticket's "a thrown
/// failure leaves state unchanged and reaches the screen" wins, and it is what
/// `MealDetailController.review` already does for the other cross-user write.)
///
/// Not `keepAlive`: the page is the only watcher, and reopening it should ask
/// the server again rather than show a Tester a cached History.

final class MealPhotosControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MealPhotosController,
          AsyncValue<MealPhotos>,
          MealPhotos,
          FutureOr<MealPhotos>,
          String
        > {
  const MealPhotosControllerFamily._()
    : super(
        retry: null,
        name: r'mealPhotosControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One library Meal's photographs, for the Meal photos page (ADR 0003).
  ///
  /// Every write is **remote-ack only**: no local write, no Drift row, no upload
  /// queue. A photograph publishes to every athlete, so "Photo added" may only be
  /// said once the server has it (story 32), and with no signal the add must fail
  /// where the Tester can see it rather than publish later unwatched (story 33).
  ///
  /// A failure therefore leaves the state exactly as it was and is rethrown for
  /// the screen — the page keeps showing what athletes really see, rather than
  /// replacing it with an error. (The spec's `AsyncValue.guard()` would instead
  /// put the failure *in* the state, which changes it; the ticket's "a thrown
  /// failure leaves state unchanged and reaches the screen" wins, and it is what
  /// `MealDetailController.review` already does for the other cross-user write.)
  ///
  /// Not `keepAlive`: the page is the only watcher, and reopening it should ask
  /// the server again rather than show a Tester a cached History.

  MealPhotosControllerProvider call(String mealId) =>
      MealPhotosControllerProvider._(argument: mealId, from: this);

  @override
  String toString() => r'mealPhotosControllerProvider';
}

/// One library Meal's photographs, for the Meal photos page (ADR 0003).
///
/// Every write is **remote-ack only**: no local write, no Drift row, no upload
/// queue. A photograph publishes to every athlete, so "Photo added" may only be
/// said once the server has it (story 32), and with no signal the add must fail
/// where the Tester can see it rather than publish later unwatched (story 33).
///
/// A failure therefore leaves the state exactly as it was and is rethrown for
/// the screen — the page keeps showing what athletes really see, rather than
/// replacing it with an error. (The spec's `AsyncValue.guard()` would instead
/// put the failure *in* the state, which changes it; the ticket's "a thrown
/// failure leaves state unchanged and reaches the screen" wins, and it is what
/// `MealDetailController.review` already does for the other cross-user write.)
///
/// Not `keepAlive`: the page is the only watcher, and reopening it should ask
/// the server again rather than show a Tester a cached History.

abstract class _$MealPhotosController extends $AsyncNotifier<MealPhotos> {
  late final _$args = ref.$arg as String;
  String get mealId => _$args;

  FutureOr<MealPhotos> build(String mealId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<MealPhotos>, MealPhotos>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MealPhotos>, MealPhotos>,
              AsyncValue<MealPhotos>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
