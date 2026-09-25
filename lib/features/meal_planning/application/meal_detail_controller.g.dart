// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The athlete's saved copy of library meal [libraryMealId] (My Foods), or
/// null. Read from Drift, so the detail's heart shows a meal saved on an
/// earlier visit as saved (testing-wave 89-009).

@ProviderFor(savedCopyOfLibraryMeal)
const savedCopyOfLibraryMealProvider = SavedCopyOfLibraryMealFamily._();

/// The athlete's saved copy of library meal [libraryMealId] (My Foods), or
/// null. Read from Drift, so the detail's heart shows a meal saved on an
/// earlier visit as saved (testing-wave 89-009).

final class SavedCopyOfLibraryMealProvider
    extends
        $FunctionalProvider<
          AsyncValue<SavedMeal?>,
          SavedMeal?,
          Stream<SavedMeal?>
        >
    with $FutureModifier<SavedMeal?>, $StreamProvider<SavedMeal?> {
  /// The athlete's saved copy of library meal [libraryMealId] (My Foods), or
  /// null. Read from Drift, so the detail's heart shows a meal saved on an
  /// earlier visit as saved (testing-wave 89-009).
  const SavedCopyOfLibraryMealProvider._({
    required SavedCopyOfLibraryMealFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'savedCopyOfLibraryMealProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$savedCopyOfLibraryMealHash();

  @override
  String toString() {
    return r'savedCopyOfLibraryMealProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SavedMeal?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SavedMeal?> create(Ref ref) {
    final argument = this.argument as String;
    return savedCopyOfLibraryMeal(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedCopyOfLibraryMealProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$savedCopyOfLibraryMealHash() =>
    r'b7a26584157111df9f4fb3075317d9ac1dd8318c';

/// The athlete's saved copy of library meal [libraryMealId] (My Foods), or
/// null. Read from Drift, so the detail's heart shows a meal saved on an
/// earlier visit as saved (testing-wave 89-009).

final class SavedCopyOfLibraryMealFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SavedMeal?>, String> {
  const SavedCopyOfLibraryMealFamily._()
    : super(
        retry: null,
        name: r'savedCopyOfLibraryMealProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The athlete's saved copy of library meal [libraryMealId] (My Foods), or
  /// null. Read from Drift, so the detail's heart shows a meal saved on an
  /// earlier visit as saved (testing-wave 89-009).

  SavedCopyOfLibraryMealProvider call(String libraryMealId) =>
      SavedCopyOfLibraryMealProvider._(argument: libraryMealId, from: this);

  @override
  String toString() => r'savedCopyOfLibraryMealProvider';
}

/// One meal's detail page / cooking-mode source, by library id or saved
/// uuid. `keepAlive` so a detail opened once survives a network blip
/// (05 §2 — the catalog is not mirrored locally).
///
/// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
///   and a failure rolls back.
/// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
/// - [saveToMine] (library meals) is remote-ack (`save_meal`).

@ProviderFor(MealDetailController)
const mealDetailControllerProvider = MealDetailControllerFamily._();

/// One meal's detail page / cooking-mode source, by library id or saved
/// uuid. `keepAlive` so a detail opened once survives a network blip
/// (05 §2 — the catalog is not mirrored locally).
///
/// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
///   and a failure rolls back.
/// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
/// - [saveToMine] (library meals) is remote-ack (`save_meal`).
final class MealDetailControllerProvider
    extends $AsyncNotifierProvider<MealDetailController, MealDetail> {
  /// One meal's detail page / cooking-mode source, by library id or saved
  /// uuid. `keepAlive` so a detail opened once survives a network blip
  /// (05 §2 — the catalog is not mirrored locally).
  ///
  /// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
  ///   and a failure rolls back.
  /// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
  /// - [saveToMine] (library meals) is remote-ack (`save_meal`).
  const MealDetailControllerProvider._({
    required MealDetailControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mealDetailControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mealDetailControllerHash();

  @override
  String toString() {
    return r'mealDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MealDetailController create() => MealDetailController();

  @override
  bool operator ==(Object other) {
    return other is MealDetailControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mealDetailControllerHash() =>
    r'da6238d452985438856de714655f38e17dce08b2';

/// One meal's detail page / cooking-mode source, by library id or saved
/// uuid. `keepAlive` so a detail opened once survives a network blip
/// (05 §2 — the catalog is not mirrored locally).
///
/// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
///   and a failure rolls back.
/// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
/// - [saveToMine] (library meals) is remote-ack (`save_meal`).

final class MealDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MealDetailController,
          AsyncValue<MealDetail>,
          MealDetail,
          FutureOr<MealDetail>,
          String
        > {
  const MealDetailControllerFamily._()
    : super(
        retry: null,
        name: r'mealDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One meal's detail page / cooking-mode source, by library id or saved
  /// uuid. `keepAlive` so a detail opened once survives a network blip
  /// (05 §2 — the catalog is not mirrored locally).
  ///
  /// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
  ///   and a failure rolls back.
  /// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
  /// - [saveToMine] (library meals) is remote-ack (`save_meal`).

  MealDetailControllerProvider call(String id) =>
      MealDetailControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'mealDetailControllerProvider';
}

/// One meal's detail page / cooking-mode source, by library id or saved
/// uuid. `keepAlive` so a detail opened once survives a network blip
/// (05 §2 — the catalog is not mirrored locally).
///
/// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
///   and a failure rolls back.
/// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
/// - [saveToMine] (library meals) is remote-ack (`save_meal`).

abstract class _$MealDetailController extends $AsyncNotifier<MealDetail> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<MealDetail> build(String id);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<MealDetail>, MealDetail>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MealDetail>, MealDetail>,
              AsyncValue<MealDetail>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
