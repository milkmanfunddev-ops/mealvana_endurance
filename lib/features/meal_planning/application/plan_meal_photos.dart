import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/meal_library_remote_data_source.dart';
import '../domain/list_pictures.dart';
import '../domain/meal_photo.dart';
import '../domain/plan_meal.dart';

part 'plan_meal_photos.g.dart';

/// The library Meals one plan needs photographs for, as a single cache key.
///
/// Sorted and de-duplicated so the same plan always asks the same question:
/// a Riverpod family keys on argument equality, and a `List` has none, so a
/// list argument would miss the cache on every rebuild and re-read forever.
/// Empty when no row has a library Meal to look up.
///
/// Surfaces don't build this themselves — [PlanPhotos.planPhotoSlots] does —
/// so the shape of the key stays an implementation detail of this file.
@visibleForTesting
String planPhotoIdsKey(List<PlanMeal> meals) =>
    (meals.map((m) => m.libraryMealId).nonNulls.toSet().toList()..sort()).join(
      ',',
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
@riverpod
Future<Map<String, MealPhoto>> planMealPhotos(
  Ref ref,
  String mealIdsKey,
) async {
  final ids = mealIdsKey.split(',').where((id) => id.isNotEmpty);
  if (ids.isEmpty) return const {};
  return ref.read(mealLibraryRemoteDataSourceProvider).photosForMeals(ids);
}

/// The plan-row picture lookup, held in one place for the three surfaces that
/// draw plan rows.
extension PlanPhotos on WidgetRef {
  /// What each row of [meals] draws where a picture goes, keyed by plan-meal
  /// id (ADR 0003).
  ///
  /// Draws nothing while the read is in flight and nothing if it fails: a plan
  /// is complete without its photographs, and the rows appear from Drift
  /// whether or not this answers.
  Map<String, MealPhotoSlot> planPhotoSlots(List<PlanMeal> meals) {
    final photos =
        watch(planMealPhotosProvider(planPhotoIdsKey(meals))).value ??
        const <String, MealPhoto>{};
    return planPhotoSlotsFor(meals, photos);
  }
}
