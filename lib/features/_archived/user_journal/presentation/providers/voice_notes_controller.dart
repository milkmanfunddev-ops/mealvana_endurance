import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../nutrition_plan/data/nutrition_plan_repository.dart';
import '../../../nutrition_plan/domain/nutrition_plan.dart';
import '../../../auth/data/user_repository.dart';

part 'voice_notes_controller.g.dart';

/// Controller for managing voice notes/journal entries list
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern
@riverpod
class VoiceNotesController extends _$VoiceNotesController {
  @override
  FutureOr<List<NutritionPlan>> build() async {
    return await _loadNotes();
  }

  /// Load all notes with journal entries
  Future<List<NutritionPlan>> _loadNotes() async {
    try {
      final userRepo = await ref.read(userRepositoryProvider.future);
      final user = await userRepo.getCurrentUser();

      if (user == null) {
        throw Exception('No user found');
      }

      final repository = await ref.read(nutritionPlanRepositoryProvider.future);
      final allPlans = await repository.getUserNutritionPlans(user.id);

      // Filter plans that have journal notes or ratings
      final notesPlans = allPlans
          .where(
            (plan) =>
                plan.journalNotes != null && plan.journalNotes!.isNotEmpty ||
                plan.planRating != null,
          )
          .toList();

      // Sort by run date (newest first), then by creation date
      notesPlans.sort((a, b) {
        final dateA =
            a.runDateTime ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            b.runDateTime ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      return notesPlans;
    } catch (e) {
      throw Exception('Failed to load voice notes: $e');
    }
  }

  /// Refresh the notes list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadNotes());
  }

  /// Delete a note (clear journal notes and rating)
  Future<void> deleteNote(String? activityId) async {
    if (activityId == null) {
      throw Exception('Cannot delete note without activity reference');
    }
    try {
      final repository = await ref.read(nutritionPlanRepositoryProvider.future);
      await repository.updatePlanFeedbackForActivity(
        activityId: activityId,
        rating: null,
        notes: null,
      );
      await refresh();
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }

  /// Update a note
  Future<void> updateNote(String? activityId, String notes) async {
    if (activityId == null) {
      throw Exception('Cannot update note without activity reference');
    }
    try {
      final repository = await ref.read(nutritionPlanRepositoryProvider.future);
      await repository.updatePlanFeedbackForActivity(
        activityId: activityId,
        rating: null,
        notes: notes,
      );
      await refresh();
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }
}
