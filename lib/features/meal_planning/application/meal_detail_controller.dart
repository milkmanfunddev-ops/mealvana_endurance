import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/app_version_provider.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../meal_logging/data/saved_meals_repository.dart';
import '../../meal_logging/domain/saved_meal.dart';
import '../data/meal_library_remote_data_source.dart';
import '../data/meal_review_repository.dart';
import '../data/vana_action_client.dart';
import '../domain/meal_detail.dart';
import '../domain/meal_ref.dart';
import '../domain/meal_source.dart';
import '../domain/ui_action.dart';

part 'meal_detail_controller.g.dart';

/// The athlete's saved copy of library meal [libraryMealId] (My Foods), or
/// null. Read from Drift, so the detail's heart shows a meal saved on an
/// earlier visit as saved (testing-wave 89-009).
@riverpod
Stream<SavedMeal?> savedCopyOfLibraryMeal(Ref ref, String libraryMealId) async* {
  final userId = await ref.watch(userIdProvider.future);
  yield* ref
      .watch(savedMealsRepositoryProvider)
      .watchSavedMeals(userId)
      .map(
        (all) => all.where((s) => s.libraryMealId == libraryMealId).firstOrNull,
      );
}

/// One meal's detail page / cooking-mode source, by library id or saved
/// uuid. `keepAlive` so a detail opened once survives a network blip
/// (05 §2 — the catalog is not mirrored locally).
///
/// - [vote] is optimistic: state flips first, `set_meal_feedback` follows,
///   and a failure rolls back.
/// - [setNotes] (saved meals) is local-first through `SavedMealsRepository`.
/// - [saveToMine] (library meals) is remote-ack (`save_meal`).
@Riverpod(keepAlive: true)
class MealDetailController extends _$MealDetailController {
  MealLibraryRemoteDataSource get _remote =>
      ref.read(mealLibraryRemoteDataSourceProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  @override
  FutureOr<MealDetail> build(String id) => _remote.getMeal(id);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _remote.getMeal(id));
  }

  /// Thumbs: -1 down, 0 clear, 1 up. Optimistic; rethrows on failure after
  /// restoring the previous vote.
  Future<void> vote(int vote, {String? reason}) async {
    assert(vote >= -1 && vote <= 1);
    final current = state.value;
    if (current == null) return;

    state = AsyncData(_withVote(current, vote));
    try {
      final stored = current.meal.source == MealSource.saved
          ? await _remote.setMealFeedback(
              savedMealId: current.meal.id,
              vote: vote,
              reason: reason,
            )
          : await _remote.setMealFeedback(
              libraryMealId: current.meal.id,
              vote: vote,
              reason: reason,
            );
      if (!ref.mounted) return;
      state = AsyncData(_withVote(state.value ?? current, stored));
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.warning(
        'set_meal_feedback failed; vote rolled back',
        context: 'MEAL_DETAIL_CONTROLLER',
        error: e,
        stackTrace: st,
      );
      state = AsyncData(_withVote(state.value ?? current, current.vote));
      rethrow;
    }
  }

  /// The athlete's own directions on a saved meal (local-first; replayed by
  /// the saved-meals upload). No-op for library meals.
  Future<void> setNotes(String notes) async {
    final current = state.value;
    if (current == null || current.meal.source != MealSource.saved) return;
    final clean = notes.length > 2000 ? notes.substring(0, 2000) : notes;
    state = AsyncData(current.copyWith(notes: clean));
    state = await AsyncValue.guard(() async {
      await ref
          .read(savedMealsRepositoryProvider)
          .updateNotes(current.meal.id, clean);
      return (state.value ?? current).copyWith(notes: clean);
    });
  }

  /// Heart on a library meal → `save_meal` (remote-ack). Returns the new
  /// saved meal's [MealRef]; the saved-meals repository is re-synced so My
  /// Foods shows it. Null when the current meal is already a saved meal.
  Future<MealRef?> saveToMine() async {
    final current = state.value;
    if (current == null || current.meal.source == MealSource.saved) return null;
    final result = await ref
        .read(vanaActionClientProvider)
        .run(SaveMealAction(libraryMealId: current.meal.id));
    final saved = result.savedMealRef;
    unawaited(_resyncSavedMeals());
    return saved;
  }

  /// A second tap on the filled heart: take the library meal out of My
  /// Foods. Local-first soft delete (the repository uploads each tombstone).
  /// A save whose resync has not landed yet is pulled first, so an unsave
  /// right after a save still finds its row. Returns false when there was
  /// nothing to remove.
  Future<bool> removeFromMine() async {
    final current = state.value;
    if (current == null || current.meal.source == MealSource.saved) {
      return false;
    }
    final repo = ref.read(savedMealsRepositoryProvider);
    final userId = await ref.read(userIdProvider.future);
    Future<List<SavedMeal>> find() async =>
        (await repo.watchSavedMeals(userId).first)
            .where((s) => s.libraryMealId == current.meal.id)
            .toList();

    var copies = await find();
    if (copies.isEmpty) {
      await _resyncSavedMeals();
      copies = await find();
    }
    // Every copy goes: an older duplicate left behind would keep the heart
    // filled after the athlete took the meal out.
    for (final copy in copies) {
      await repo.softDelete(copy.id);
    }
    return copies.isNotEmpty;
  }

  /// Admin review (mp-144 clause 3): is this a good recipe, and why. Remote
  /// ack only — the team reads the row cross-user, so nothing is reported as
  /// sent until the server has it. The detail state is untouched; a failure
  /// (offline, RLS refusing a non-admin) rethrows for the screen to show.
  Future<void> review({required bool isGood, required String why}) async {
    final current = state.value;
    if (current == null) return;
    final clean = why.trim();
    if (clean.isEmpty) return;
    try {
      // The build that sent it (89-014); a version the platform cannot
      // give is sent as null, never a reason to refuse the review.
      final appVersion = await ref.read(appVersionProvider.future);
      await ref
          .read(mealReviewRepositoryProvider)
          .addReview(
            MealReview(
              mealSource: current.meal.source,
              mealId: current.meal.id,
              mealName: current.meal.name,
              isGood: isGood,
              why: clean.length > 2000 ? clean.substring(0, 2000) : clean,
              appVersion: appVersion,
            ),
          );
    } catch (e, st) {
      _logger.warning(
        'meal_reviews insert failed',
        context: 'MEAL_DETAIL_CONTROLLER',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _resyncSavedMeals() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final result = await ref
          .read(savedMealsRepositoryProvider)
          .syncFromRemote(userId);
      if (!result.success) {
        _logger.warning(
          'saved_meals resync after save_meal failed',
          context: 'MEAL_DETAIL_CONTROLLER',
          data: {'error': result.error},
        );
      }
    } catch (e) {
      _logger.warning(
        'saved_meals resync after save_meal threw',
        context: 'MEAL_DETAIL_CONTROLLER',
        error: e,
      );
    }
  }

  static MealDetail _withVote(MealDetail detail, int vote) => detail.copyWith(
    vote: vote,
    meal: detail.meal.copyWith(myVote: vote),
  );
}
