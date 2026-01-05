import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../activities/domain/activity.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../../domain/coach_feedback.dart';

part 'athlete_detail_controller.g.dart';

/// State for viewing an athlete's details
class AthleteDetailState {
  final CoachAthleteRelationship relationship;
  final List<Activity> activities;
  final List<CoachFeedback> feedback;
  final bool isLoading;
  final String? error;

  const AthleteDetailState({
    required this.relationship,
    this.activities = const [],
    this.feedback = const [],
    this.isLoading = false,
    this.error,
  });

  AthleteDetailState copyWith({
    CoachAthleteRelationship? relationship,
    List<Activity>? activities,
    List<CoachFeedback>? feedback,
    bool? isLoading,
    String? error,
  }) {
    return AthleteDetailState(
      relationship: relationship ?? this.relationship,
      activities: activities ?? this.activities,
      feedback: feedback ?? this.feedback,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Check if coach can view activities
  bool get canViewActivities =>
      relationship.hasPermission('view_activities');

  /// Check if coach can view nutrition plans
  bool get canViewNutritionPlans =>
      relationship.hasPermission('view_nutrition_plans');

  /// Check if coach can add feedback
  bool get canAddFeedback =>
      relationship.hasPermission('add_notes');
}

@riverpod
class AthleteDetailController extends _$AthleteDetailController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<AthleteDetailState> build(String relationshipId) async {
    return _loadAthleteDetails(relationshipId);
  }

  Future<AthleteDetailState> _loadAthleteDetails(String relationshipId) async {
    try {
      // Get the relationship - for now just create a placeholder
      // In production, we would fetch from repository
      final feedback = await _coachService.getFeedbackForRelationship(
        relationshipId,
      );

      // TODO: Fetch athlete's activities via a new service method
      // For now, return empty activities list

      // Create a placeholder relationship for now
      // In production, this would come from the repository
      final relationship = CoachAthleteRelationship(
        id: relationshipId,
        coachId: '',
        athleteUserId: '',
        athleteDeviceId: '',
        requestedBy: 'coach',
        requestedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: RelationshipStatus.active,
      );

      return AthleteDetailState(
        relationship: relationship,
        feedback: feedback,
        activities: [],
      );
    } catch (e) {
      // Return error state with placeholder relationship
      return AthleteDetailState(
        relationship: CoachAthleteRelationship(
          id: relationshipId,
          coachId: '',
          athleteUserId: '',
          athleteDeviceId: '',
          requestedBy: 'coach',
          requestedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        error: 'Failed to load athlete details: ${e.toString()}',
      );
    }
  }

  /// Add feedback for this athlete
  Future<void> addFeedback({
    required String feedbackText,
    FeedbackType feedbackType = FeedbackType.general,
    String? activityId,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      final newFeedback = await _coachService.addFeedback(
        relationshipId: currentState.relationship.id,
        athleteUserId: currentState.relationship.athleteUserId,
        feedbackText: feedbackText,
        feedbackType: feedbackType,
        activityId: activityId,
      );

      if (newFeedback != null) {
        final updatedFeedback = [newFeedback, ...currentState.feedback];
        state = AsyncData(currentState.copyWith(
          feedback: updatedFeedback,
          isLoading: false,
        ));
      } else {
        state = AsyncData(currentState.copyWith(
          isLoading: false,
          error: 'Failed to add feedback',
        ));
      }
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to add feedback: ${e.toString()}',
      ));
    }
  }

  /// Delete feedback
  Future<void> deleteFeedback(String feedbackId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.deleteFeedback(feedbackId);

      final updatedFeedback = currentState.feedback
          .where((f) => f.id != feedbackId)
          .toList();

      state = AsyncData(currentState.copyWith(
        feedback: updatedFeedback,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to delete feedback: ${e.toString()}',
      ));
    }
  }

  /// Refresh athlete data
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loadAthleteDetails(currentState.relationship.id),
    );
  }

  /// Clear error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
