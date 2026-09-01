import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../meal_logging/data/saved_meals_repository.dart';
import '../data/meal_library_remote_data_source.dart';
import '../data/vana_action_client.dart';
import '../domain/meal_detail.dart';
import '../domain/meal_ref.dart';
import '../domain/meal_source.dart';
import '../domain/ui_action.dart';

part 'meal_detail_controller.g.dart';

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
