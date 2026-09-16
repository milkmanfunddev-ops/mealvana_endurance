import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:typed_data';

import '../data/meal_photo_repository.dart';
import 'dish_photo_capture.dart';
import '../domain/dish_photo_preparation.dart';
import '../domain/meal_photo_history.dart';
import 'meal_catalog_controller.dart';
import 'meal_detail_controller.dart';
import 'plan_meal_photos.dart';

part 'meal_photos_controller.g.dart';

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
@riverpod
class MealPhotosController extends _$MealPhotosController {
  MealPhotoRepository get _repo => ref.read(mealPhotoRepositoryProvider);

  @override
  FutureOr<MealPhotos> build(String mealId) => _repo.history(mealId);

  /// Publish a web address as this Meal's photo.
  ///
  /// The server checks the address really answers with an image before
  /// anything is written, so a refusal here means nothing changed.
  Future<void> addAddress({
    required String url,
    String? credit,
    String? creditUrl,
  }) async {
    // Never a silent return: a page that has not finished loading must still
    // send, or Confirm would say "Photo added" having sent nothing (story 32).
    final current = state.value ?? const MealPhotos();

    // Nothing before the ack. If this throws — offline, not a Tester, not an
    // image — `state` is still `current` and the screen shows the failure.
    final added = await _repo.addAddress(
      mealId: mealId,
      url: url,
      credit: credit,
      creditUrl: creditUrl,
    );

    if (!ref.mounted) return;
    state = AsyncData(current.withAdded(added));
    _showEverywhereElse();
  }

  /// Publish a photo the Tester took or chose.
  ///
  /// [bytes] are the raw picked (and cropped) file. Preparation happens here,
  /// not on the page and not on the server: it is the step that strips the
  /// EXIF, so it must sit between the picker and anything that can send, with
  /// nothing able to skip past it. A file that cannot be read throws
  /// [DishPhotoUnreadable] before a single byte leaves the phone.
  ///
  /// It runs off the UI isolate ([dishPhotoPreparer]): decoding, resizing and
  /// re-encoding a photo straight off a phone camera would otherwise freeze the
  /// page, including the spinner that is supposed to show something is
  /// happening.
  Future<void> addUpload({
    required Uint8List bytes,
    String? credit,
    String? creditUrl,
  }) async {
    final current = state.value ?? const MealPhotos();

    final prepared = await ref.read(dishPhotoPreparerProvider)(bytes);

    final added = await _repo.addUpload(
      mealId: mealId,
      bytes: prepared,
      credit: credit,
      creditUrl: creditUrl,
    );

    if (!ref.mounted) return;
    state = AsyncData(current.withAdded(added));
    _showEverywhereElse();
  }

  /// Take the current photograph down, so the Meal shows nothing again.
  ///
  /// Not a delete: the photograph stays in History and is one tap from coming
  /// back, and no older photograph is pulled forward in its place (story 42).
  Future<void> remove() async {
    final current = state.value ?? const MealPhotos();

    await _repo.remove(mealId);

    if (!ref.mounted) return;
    state = AsyncData(current.withRemoved());
    _showEverywhereElse();
  }

  /// Put a photograph from History back on — the one tap that undoes a mistake
  /// or somebody else's vandalism (story 38).
  Future<void> restore(String photoId) async {
    final current = state.value ?? const MealPhotos();

    // The server's own answer, not the row this device happened to be holding:
    // a stale History must not put a stale credit in front of athletes.
    final photo = await _repo.restore(mealId: mealId, photoId: photoId);

    if (!ref.mounted) return;
    state = AsyncData(current.withRestored(photoId, photo));
    _showEverywhereElse();
  }

  /// Delete a photograph for good: out of History, and out of our storage when
  /// the file was ours (story 39).
  ///
  /// Deleting the photograph the Meal is wearing leaves it showing nothing —
  /// the server says so, and the page is told by its answer rather than
  /// guessing.
  Future<void> delete(String photoId) async {
    final current = state.value ?? const MealPhotos();

    final nowShowing = await _repo.deletePhoto(mealId: mealId, photoId: photoId);

    if (!ref.mounted) return;
    state = AsyncData(current.withDeleted(photoId, nowShowing));
    _showEverywhereElse();
  }

  /// The new photograph has to reach the surfaces that already drew this Meal.
  ///
  /// The recipe screen behind the page holds a `keepAlive` detail, the Meals
  /// tab holds its rails and results, and an open plan holds its photo lookup —
  /// none of them re-read on their own, so without this a Tester would have to
  /// leave the screen to see their own photograph (the debt ticket 03 left).
  void _showEverywhereElse() {
    ref.invalidate(mealDetailControllerProvider(mealId));
    ref.invalidate(mealCatalogControllerProvider);
    ref.invalidate(planMealPhotosProvider);
  }
}
