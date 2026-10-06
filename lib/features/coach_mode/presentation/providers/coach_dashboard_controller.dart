import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/report/report.dart';
import '../../application/coach_service.dart';
import '../../domain/coach.dart';
import '../../domain/coach_athlete_relationship.dart';

part 'coach_dashboard_controller.g.dart';

/// State for the coach dashboard
class CoachDashboardState {
  final CoachInfo? coachInfo;
  final List<CoachAthleteRelationship> activeAthletes;
  final List<CoachAthleteRelationship> pendingRequests;
  final bool isLoading;
  final String? error;

  const CoachDashboardState({
    this.coachInfo,
    this.activeAthletes = const [],
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  CoachDashboardState copyWith({
    CoachInfo? coachInfo,
    List<CoachAthleteRelationship>? activeAthletes,
    List<CoachAthleteRelationship>? pendingRequests,
    bool? isLoading,
    String? error,
  }) {
    return CoachDashboardState(
      coachInfo: coachInfo ?? this.coachInfo,
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

  /// Whether user is a coach
  bool get isCoach => coachInfo?.isCoach ?? false;
}

@riverpod
class CoachDashboardController extends _$CoachDashboardController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<CoachDashboardState> build() async {
    return _loadDashboard();
  }

  /// Load local data immediately, sync in background
  Future<CoachDashboardState> _loadDashboard() async {
    final coachService = _coachService;
    final report = ref.read(reportProvider);
    try {
      var coachInfo = await coachService.getCurrentCoachInfo();

      if (coachInfo == null) {
        final isCoachAfterSync = await coachService
            .syncCurrentCoachDataFromSupabase();
        if (isCoachAfterSync) {
          coachInfo = await coachService.getCurrentCoachInfo();
        }
      }

      if (coachInfo == null) {
        return const CoachDashboardState(
          error:
              'You are not registered as a coach. Please apply via the coach registration form.',
        );
      }

      // 1. Load local data IMMEDIATELY
      final activeAthletes = await coachService.getMyAthletes();
      final pendingRequests = await coachService.getPendingAthleteRequests();

      // 2. Background sync (fire-and-forget)
      if (ref.mounted) unawaited(_backgroundSync());

      return CoachDashboardState(
        coachInfo: coachInfo,
        activeAthletes: activeAthletes,
        pendingRequests: pendingRequests,
      );
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Coach dashboard load failed',
      );
      return CoachDashboardState(
        error: 'Failed to load dashboard: ${e.toString()}',
      );
    }
  }

  /// Background sync: fetches latest data from Supabase, then refreshes UI.
  /// Uses a _synced flag to ensure we only invalidate once per build cycle,
  /// preventing infinite build→sync→invalidate loops if sync fails.
  bool _hasSynced = false;

  Future<void> _backgroundSync() async {
    if (_hasSynced) return;
    final coachService = ref.read(coachServiceProvider);
    final report = ref.read(reportProvider);

    try {
      await coachService.syncRelationshipsFromSupabase();
      await coachService.syncMyAthletesProfiles();
      _hasSynced = true;
      if (!ref.mounted) return;
      ref.invalidateSelf();
    } catch (e, stackTrace) {
      _hasSynced = true; // Don't retry on failure within same lifecycle
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Coach dashboard background sync failed',
      );
    }
  }

  /// Refresh dashboard data
  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _loadDashboard());
    if (ref.mounted) state = result;
  }

  /// Accept a pending athlete request
  Future<void> acceptRequest(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    final coachService = _coachService;
    final report = ref.read(reportProvider);

    try {
      await coachService.acceptAthleteRequest(relationshipId);

      // Refresh to get updated lists
      final activeAthletes = await coachService.getMyAthletes();
      final pendingRequests = await coachService.getPendingAthleteRequests();

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(
          activeAthletes: activeAthletes,
          pendingRequests: pendingRequests,
          isLoading: false,
        ),
      );
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Accept athlete request failed',
        extra: {'relationshipId': relationshipId},
      );
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to accept request: ${e.toString()}',
        ),
      );
    }
  }

  /// Decline a pending athlete request
  Future<void> declineRequest(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    final coachService = _coachService;
    final report = ref.read(reportProvider);

    try {
      await coachService.declineAthleteRequest(relationshipId);

      // Remove from pending list
      final updatedPending = currentState.pendingRequests
          .where((r) => r.id != relationshipId)
          .toList();

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(
          pendingRequests: updatedPending,
          isLoading: false,
        ),
      );
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Decline athlete request failed',
        extra: {'relationshipId': relationshipId},
      );
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to decline request: ${e.toString()}',
        ),
      );
    }
  }

  /// Archive an athlete relationship
  Future<void> archiveAthlete(String relationshipId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    final coachService = _coachService;
    final report = ref.read(reportProvider);

    try {
      await coachService.archiveAthlete(relationshipId);

      // Remove from active list
      final updatedActive = currentState.activeAthletes
          .where((r) => r.id != relationshipId)
          .toList();

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(activeAthletes: updatedActive, isLoading: false),
      );
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Archive athlete failed',
        extra: {'relationshipId': relationshipId},
      );
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to archive athlete: ${e.toString()}',
        ),
      );
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
