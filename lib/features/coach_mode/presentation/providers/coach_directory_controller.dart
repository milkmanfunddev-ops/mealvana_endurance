import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach.dart';

part 'coach_directory_controller.g.dart';

/// State for browsing available coaches
class CoachDirectoryState {
  final List<Coach> coaches;
  final List<Coach> filteredCoaches;
  final String? searchQuery;
  final CoachSpecialization? selectedSpecialization;
  final bool isLoading;
  final String? error;

  const CoachDirectoryState({
    this.coaches = const [],
    this.filteredCoaches = const [],
    this.searchQuery,
    this.selectedSpecialization,
    this.isLoading = false,
    this.error,
  });

  CoachDirectoryState copyWith({
    List<Coach>? coaches,
    List<Coach>? filteredCoaches,
    String? searchQuery,
    CoachSpecialization? selectedSpecialization,
    bool? isLoading,
    String? error,
    bool clearSpecialization = false,
  }) {
    return CoachDirectoryState(
      coaches: coaches ?? this.coaches,
      filteredCoaches: filteredCoaches ?? this.filteredCoaches,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSpecialization: clearSpecialization ? null : (selectedSpecialization ?? this.selectedSpecialization),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

@riverpod
class CoachDirectoryController extends _$CoachDirectoryController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<CoachDirectoryState> build() async {
    return _loadCoaches();
  }

  Future<CoachDirectoryState> _loadCoaches() async {
    try {
      final coaches = await _coachService.getAvailableCoaches();
      return CoachDirectoryState(
        coaches: coaches,
        filteredCoaches: coaches,
      );
    } catch (e) {
      return CoachDirectoryState(
        error: 'Failed to load coaches: $e',
      );
    }
  }

  /// Search coaches by name
  void search(String query) {
    final currentState = state.value;
    if (currentState == null) return;

    final filtered = _filterCoaches(
      currentState.coaches,
      query,
      currentState.selectedSpecialization,
    );

    state = AsyncData(currentState.copyWith(
      searchQuery: query,
      filteredCoaches: filtered,
    ));
  }

  /// Filter by specialization
  void filterBySpecialization(CoachSpecialization? specialization) {
    final currentState = state.value;
    if (currentState == null) return;

    final filtered = _filterCoaches(
      currentState.coaches,
      currentState.searchQuery,
      specialization,
    );

    state = AsyncData(currentState.copyWith(
      selectedSpecialization: specialization,
      filteredCoaches: filtered,
      clearSpecialization: specialization == null,
    ));
  }

  List<Coach> _filterCoaches(
    List<Coach> coaches,
    String? query,
    CoachSpecialization? specialization,
  ) {
    var filtered = coaches;

    // Filter by search query
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered.where((coach) {
        return coach.coachName.toLowerCase().contains(lowerQuery) ||
            (coach.bio?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    // Filter by specialization
    if (specialization != null) {
      filtered = filtered.where((coach) {
        return coach.specializationsTyped.contains(specialization);
      }).toList();
    }

    return filtered;
  }

  /// Request to connect with a coach
  Future<bool> requestCoach(String coachId) async {
    final currentState = state.value;
    if (currentState == null) return false;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      final success = await _coachService.requestCoachConnection(coachId);
      state = AsyncData(currentState.copyWith(isLoading: false));
      return success;
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to send request: $e',
      ));
      return false;
    }
  }

  /// Refresh coach list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadCoaches());
  }

  /// Clear error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
