import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../activities/domain/activity.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../../domain/coach_message.dart';

part 'athlete_detail_controller.g.dart';

/// State for viewing an athlete's details (coach perspective)
class AthleteDetailState {
  final CoachAthleteRelationship relationship;
  final List<Activity> activities;
  final List<CoachMessage> messages;
  final bool isLoading;
  final String? error;

  const AthleteDetailState({
    required this.relationship,
    this.activities = const [],
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AthleteDetailState copyWith({
    CoachAthleteRelationship? relationship,
    List<Activity>? activities,
    List<CoachMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AthleteDetailState(
      relationship: relationship ?? this.relationship,
      activities: activities ?? this.activities,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
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
      // Get all relationships for this coach to find the specific one
      final relationships = await _coachService.getMyAthletes();
      final relationship = relationships.firstWhere(
        (r) => r.id == relationshipId,
        orElse: () => _createPlaceholderRelationship(relationshipId),
      );

      // Get conversation messages with this athlete
      final messages = await _coachService.getConversation(
        coachUserId: relationship.coachUserId,
        athleteUserId: relationship.athleteUserId,
      );

      // TODO: Fetch athlete's activities via a new service method
      // For now, return empty activities list

      return AthleteDetailState(
        relationship: relationship,
        messages: messages,
        activities: [],
      );
    } catch (e) {
      return AthleteDetailState(
        relationship: _createPlaceholderRelationship(relationshipId),
        error: 'Failed to load athlete details: ${e.toString()}',
      );
    }
  }

  CoachAthleteRelationship _createPlaceholderRelationship(String id) {
    return CoachAthleteRelationship(
      id: id,
      coachUserId: '',
      athleteUserId: '',
      requestedBy: 'coach',
      requestedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Send a message to this athlete
  Future<void> sendMessage({
    required String messageText,
    String? activityId,
    String? nutritionPlanId,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      final newMessage = await _coachService.sendMessage(
        coachUserId: currentState.relationship.coachUserId,
        athleteUserId: currentState.relationship.athleteUserId,
        messageText: messageText,
        activityId: activityId,
        nutritionPlanId: nutritionPlanId,
      );

      if (newMessage != null) {
        final updatedMessages = [newMessage, ...currentState.messages];
        state = AsyncData(currentState.copyWith(
          messages: updatedMessages,
          isLoading: false,
        ));
      } else {
        state = AsyncData(currentState.copyWith(
          isLoading: false,
          error: 'Failed to send message',
        ));
      }
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to send message: ${e.toString()}',
      ));
    }
  }

  /// Delete a message (only if you sent it)
  Future<void> deleteMessage(String messageId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.deleteMessage(messageId);

      final updatedMessages = currentState.messages
          .where((m) => m.id != messageId)
          .toList();

      state = AsyncData(currentState.copyWith(
        messages: updatedMessages,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to delete message: ${e.toString()}',
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
