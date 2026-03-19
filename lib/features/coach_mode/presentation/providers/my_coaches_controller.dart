import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/logging_service.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_athlete_relationship.dart';

part 'my_coaches_controller.g.dart';

/// State for the athlete's "My Coaches" view
class MyCoachesState {
  final List<CoachAthleteRelationship> activeCoaches;
  final List<CoachAthleteRelationship> pendingRequests;
  final bool isLoading;
  final String? error;

  const MyCoachesState({
    this.activeCoaches = const [],
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  MyCoachesState copyWith({
    List<CoachAthleteRelationship>? activeCoaches,
    List<CoachAthleteRelationship>? pendingRequests,
    bool? isLoading,
    String? error,
  }) {
    return MyCoachesState(
      activeCoaches: activeCoaches ?? this.activeCoaches,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Whether there are any pending coach requests
  bool get hasPendingRequests => pendingRequests.isNotEmpty;

  /// Whether the athlete has any active coaches
  bool get hasCoaches => activeCoaches.isNotEmpty;
}

@riverpod
class MyCoachesController extends _$MyCoachesController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<MyCoachesState> build() async {
    return _loadCoaches();
  }

  /// Load local data immediately, sync in background
  Future<MyCoachesState> _loadCoaches() async {
    try {
      // 1. Load local data IMMEDIATELY
      final activeCoaches = await _coachService.getMyCoaches();
      final pendingRequests = await _coachService.getPendingCoachRequests();

      // 2. Background sync (fire-and-forget)
      unawaited(_backgroundSync());

      return MyCoachesState(
        activeCoaches: activeCoaches,
        pendingRequests: pendingRequests,
      );
    } catch (e) {
      return MyCoachesState(error: 'Failed to load coaches: $e');
    }
  }

  /// Background sync: fetches latest data from Supabase, then refreshes UI.
  /// Uses a _synced flag to ensure we only invalidate once per build cycle,
  /// preventing infinite build→sync→invalidate loops if sync fails.
  bool _hasSynced = false;

  Future<void> _backgroundSync() async {
    if (_hasSynced) return;
    final coachService = ref.read(coachServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      await coachService.syncRelationshipsFromSupabase();
      await coachService.syncMyCoachesData();
      _hasSynced = true;
      if (!ref.mounted) return;
      ref.invalidateSelf();
    } catch (e, stackTrace) {
      _hasSynced = true; // Don't retry on failure within same lifecycle
      logger.error(
        'Background sync failed',
        context: 'MY_COACHES_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Refresh coach list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadCoaches());
  }

  /// Accept a coach's request
  Future<void> acceptRequest(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      final accepted = await _coachService.acceptCoachRequest(relationshipId);

      if (accepted != null) {
        // Move from pending to active
        final updatedPending = currentState.pendingRequests
            .where((r) => r.id != relationshipId)
            .toList();
        final updatedActive = [...currentState.activeCoaches, accepted];

        state = AsyncData(
          currentState.copyWith(
            activeCoaches: updatedActive,
            pendingRequests: updatedPending,
            isLoading: false,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to accept request: $e',
        ),
      );
    }
  }

  /// Decline a coach's request
  Future<void> declineRequest(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.declineCoachRequest(relationshipId);

      final updatedPending = currentState.pendingRequests
          .where((r) => r.id != relationshipId)
          .toList();

      state = AsyncData(
        currentState.copyWith(
          pendingRequests: updatedPending,
          isLoading: false,
        ),
      );
    } catch (e) {
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to decline request: $e',
        ),
      );
    }
  }

  /// Clear error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
