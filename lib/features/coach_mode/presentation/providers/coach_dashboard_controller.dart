import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach.dart';
import '../../domain/coach_athlete_relationship.dart';

part 'coach_dashboard_controller.g.dart';

/// State for the coach dashboard
class CoachDashboardState {
  final Coach? coach;
  final List<CoachAthleteRelationship> activeAthletes;
  final List<CoachAthleteRelationship> pendingRequests;
  final bool isLoading;
  final String? error;

  const CoachDashboardState({
    this.coach,
    this.activeAthletes = const [],
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  CoachDashboardState copyWith({
    Coach? coach,
    List<CoachAthleteRelationship>? activeAthletes,
    List<CoachAthleteRelationship>? pendingRequests,
    bool? isLoading,
    String? error,
  }) {
    return CoachDashboardState(
      coach: coach ?? this.coach,
      activeAthletes: activeAthletes ?? this.activeAthletes,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Total athlete count (active only)
  int get athleteCount => activeAthletes.length;

  /// Whether coach has any pending requests
  bool get hasPendingRequests => pendingRequests.isNotEmpty;

  /// Whether coach profile is set up
  bool get hasProfile => coach != null;
}

@riverpod
class CoachDashboardController extends _$CoachDashboardController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<CoachDashboardState> build() async {
    return _loadDashboard();
  }

  /// Load all dashboard data
  Future<CoachDashboardState> _loadDashboard() async {
    try {
      final coach = await _coachService.getCurrentCoachProfile();
      
      if (coach == null) {
        return const CoachDashboardState(
          error: 'No coach profile found. Please set up your coach profile.',
        );
      }

      final activeAthletes = await _coachService.getMyAthletes();
      final pendingRequests = await _coachService.getPendingAthleteRequests();

      return CoachDashboardState(
        coach: coach,
        activeAthletes: activeAthletes,
        pendingRequests: pendingRequests,
      );
    } catch (e) {
      return CoachDashboardState(
        error: 'Failed to load dashboard: ${e.toString()}',
      );
    }
  }

  /// Refresh dashboard data
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard());
  }

  /// Accept a pending athlete request
  Future<void> acceptRequest(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.acceptAthleteRequest(relationshipId);
      
      // Refresh to get updated lists
      final activeAthletes = await _coachService.getMyAthletes();
      final pendingRequests = await _coachService.getPendingAthleteRequests();

      state = AsyncData(currentState.copyWith(
        activeAthletes: activeAthletes,
        pendingRequests: pendingRequests,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to accept request: ${e.toString()}',
      ));
    }
  }

  /// Decline a pending athlete request
  Future<void> declineRequest(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.declineAthleteRequest(relationshipId);
      
      // Remove from pending list
      final updatedPending = currentState.pendingRequests
          .where((r) => r.id != relationshipId)
          .toList();

      state = AsyncData(currentState.copyWith(
        pendingRequests: updatedPending,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to decline request: ${e.toString()}',
      ));
    }
  }

  /// Archive an athlete relationship
  Future<void> archiveAthlete(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.archiveAthlete(relationshipId);
      
      // Remove from active list
      final updatedActive = currentState.activeAthletes
          .where((r) => r.id != relationshipId)
          .toList();

      state = AsyncData(currentState.copyWith(
        activeAthletes: updatedActive,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to archive athlete: ${e.toString()}',
      ));
    }
  }

  /// Clear any error message
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
