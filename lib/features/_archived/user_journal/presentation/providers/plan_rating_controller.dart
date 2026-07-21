import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../nutrition_plan/data/nutrition_plan_repository.dart';

part 'plan_rating_controller.g.dart';

/// Controller state for plan rating
class PlanRatingState {
  const PlanRatingState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final String? error;

  PlanRatingState copyWith({bool? isSubmitting, String? error}) {
    return PlanRatingState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error ?? this.error,
    );
  }
}

/// Controller for handling nutrition plan ratings
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern
@riverpod
class PlanRatingController extends _$PlanRatingController {
  @override
  FutureOr<PlanRatingState> build() {
    return const PlanRatingState();
  }

  /// Submit a rating for a nutrition plan
  Future<void> submitRating(String activityId, int rating) async {
    if (rating < 1 || rating > 3) {
      throw ArgumentError('Rating must be between 1 and 3');
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      try {
        final repository = await ref.read(
          nutritionPlanRepositoryProvider.future,
        );

        await repository.updatePlanFeedbackForActivity(
          activityId: activityId,
          rating: rating,
          notes: null,
        );

        return const PlanRatingState();
      } catch (error) {
        return PlanRatingState(error: error.toString());
      }
    });
  }

  /// Skip feedback for a nutrition plan - marks it as addressed without rating
  Future<void> skipFeedback(String activityId) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      try {
        final repository = await ref.read(
          nutritionPlanRepositoryProvider.future,
        );

        // Mark plan as addressed by adding a skip note
        await repository.updatePlanFeedbackForActivity(
          activityId: activityId,
          rating: null,
          notes: 'Feedback skipped',
        );

        return const PlanRatingState();
      } catch (error) {
        return PlanRatingState(error: error.toString());
      }
    });
  }
}
