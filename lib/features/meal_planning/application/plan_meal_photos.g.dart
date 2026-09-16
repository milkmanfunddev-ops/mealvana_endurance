// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_meal_photos.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Each of those Meals' current Dish photo, keyed by meal id (ADR 0003).
///
/// This is the join behind a plan row's picture: plan meals are stored locally
/// and carry no picture, so the photo is read from the library by meal id and
/// never copied onto the plan row. A photo added to a Meal later therefore
/// reaches plans already made, the next time this is fetched.
///
/// The plan tile, the plan bar and the review sheet share one answer, so a
/// meal looks the same on all three.
///
/// Deliberately **not** `keepAlive`: it lives while a plan surface is watching
/// and is dropped when none is, so returning to a plan reads the Meals again
/// and a photograph added since then appears (story 13). Nothing invalidates
/// this yet — the Tester's photo controller (tickets 05 and 06) should, so a
/// Tester sees their own photo without leaving the screen.
///
/// A failure stays a failure: it is carried in the [AsyncValue] rather than
/// swallowed, so an outage is visible and is not cached as "these Meals have
/// no photographs". Callers read it through [PlanPhotos.planPhotoSlots], which
/// draws no picture until an answer arrives — the plan itself renders from
/// Drift and never waits on this.

@ProviderFor(planMealPhotos)
const planMealPhotosProvider = PlanMealPhotosFamily._();

/// Each of those Meals' current Dish photo, keyed by meal id (ADR 0003).
///
/// This is the join behind a plan row's picture: plan meals are stored locally
/// and carry no picture, so the photo is read from the library by meal id and
/// never copied onto the plan row. A photo added to a Meal later therefore
/// reaches plans already made, the next time this is fetched.
///
/// The plan tile, the plan bar and the review sheet share one answer, so a
/// meal looks the same on all three.
///
/// Deliberately **not** `keepAlive`: it lives while a plan surface is watching
/// and is dropped when none is, so returning to a plan reads the Meals again
/// and a photograph added since then appears (story 13). Nothing invalidates
/// this yet — the Tester's photo controller (tickets 05 and 06) should, so a
/// Tester sees their own photo without leaving the screen.
///
/// A failure stays a failure: it is carried in the [AsyncValue] rather than
/// swallowed, so an outage is visible and is not cached as "these Meals have
/// no photographs". Callers read it through [PlanPhotos.planPhotoSlots], which
/// draws no picture until an answer arrives — the plan itself renders from
/// Drift and never waits on this.

final class PlanMealPhotosProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, MealPhoto>>,
          Map<String, MealPhoto>,
          FutureOr<Map<String, MealPhoto>>
        >
    with
        $FutureModifier<Map<String, MealPhoto>>,
        $FutureProvider<Map<String, MealPhoto>> {
  /// Each of those Meals' current Dish photo, keyed by meal id (ADR 0003).
  ///
  /// This is the join behind a plan row's picture: plan meals are stored locally
  /// and carry no picture, so the photo is read from the library by meal id and
  /// never copied onto the plan row. A photo added to a Meal later therefore
  /// reaches plans already made, the next time this is fetched.
  ///
  /// The plan tile, the plan bar and the review sheet share one answer, so a
  /// meal looks the same on all three.
  ///
  /// Deliberately **not** `keepAlive`: it lives while a plan surface is watching
  /// and is dropped when none is, so returning to a plan reads the Meals again
  /// and a photograph added since then appears (story 13). Nothing invalidates
  /// this yet — the Tester's photo controller (tickets 05 and 06) should, so a
  /// Tester sees their own photo without leaving the screen.
  ///
  /// A failure stays a failure: it is carried in the [AsyncValue] rather than
  /// swallowed, so an outage is visible and is not cached as "these Meals have
  /// no photographs". Callers read it through [PlanPhotos.planPhotoSlots], which
  /// draws no picture until an answer arrives — the plan itself renders from
  /// Drift and never waits on this.
  const PlanMealPhotosProvider._({
    required PlanMealPhotosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planMealPhotosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planMealPhotosHash();

  @override
  String toString() {
    return r'planMealPhotosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, MealPhoto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, MealPhoto>> create(Ref ref) {
    final argument = this.argument as String;
    return planMealPhotos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanMealPhotosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planMealPhotosHash() => r'3eeab22d25f57eeaa5b91b21aff8571b1554b617';

/// Each of those Meals' current Dish photo, keyed by meal id (ADR 0003).
///
/// This is the join behind a plan row's picture: plan meals are stored locally
/// and carry no picture, so the photo is read from the library by meal id and
/// never copied onto the plan row. A photo added to a Meal later therefore
/// reaches plans already made, the next time this is fetched.
///
/// The plan tile, the plan bar and the review sheet share one answer, so a
/// meal looks the same on all three.
///
/// Deliberately **not** `keepAlive`: it lives while a plan surface is watching
/// and is dropped when none is, so returning to a plan reads the Meals again
/// and a photograph added since then appears (story 13). Nothing invalidates
/// this yet — the Tester's photo controller (tickets 05 and 06) should, so a
/// Tester sees their own photo without leaving the screen.
///
/// A failure stays a failure: it is carried in the [AsyncValue] rather than
/// swallowed, so an outage is visible and is not cached as "these Meals have
/// no photographs". Callers read it through [PlanPhotos.planPhotoSlots], which
/// draws no picture until an answer arrives — the plan itself renders from
/// Drift and never waits on this.

final class PlanMealPhotosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, MealPhoto>>, String> {
  const PlanMealPhotosFamily._()
    : super(
        retry: null,
        name: r'planMealPhotosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Each of those Meals' current Dish photo, keyed by meal id (ADR 0003).
  ///
  /// This is the join behind a plan row's picture: plan meals are stored locally
  /// and carry no picture, so the photo is read from the library by meal id and
  /// never copied onto the plan row. A photo added to a Meal later therefore
  /// reaches plans already made, the next time this is fetched.
  ///
  /// The plan tile, the plan bar and the review sheet share one answer, so a
  /// meal looks the same on all three.
  ///
  /// Deliberately **not** `keepAlive`: it lives while a plan surface is watching
  /// and is dropped when none is, so returning to a plan reads the Meals again
  /// and a photograph added since then appears (story 13). Nothing invalidates
  /// this yet — the Tester's photo controller (tickets 05 and 06) should, so a
  /// Tester sees their own photo without leaving the screen.
  ///
  /// A failure stays a failure: it is carried in the [AsyncValue] rather than
  /// swallowed, so an outage is visible and is not cached as "these Meals have
  /// no photographs". Callers read it through [PlanPhotos.planPhotoSlots], which
  /// draws no picture until an answer arrives — the plan itself renders from
  /// Drift and never waits on this.

  PlanMealPhotosProvider call(String mealIdsKey) =>
      PlanMealPhotosProvider._(argument: mealIdsKey, from: this);

  @override
  String toString() => r'planMealPhotosProvider';
}
