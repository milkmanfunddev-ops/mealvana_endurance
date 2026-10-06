import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/report/report.dart';
import '../../application/coach_service.dart';
import '../../domain/coach.dart';

part 'coach_directory_controller.g.dart';

/// State for the coach directory
class CoachDirectoryState {
  final List<CoachInfo> coaches;
  final bool isLoading;
  final String? error;

  const CoachDirectoryState({
    this.coaches = const [],
    this.isLoading = false,
    this.error,
  });

  CoachDirectoryState copyWith({
    List<CoachInfo>? coaches,
    bool? isLoading,
    String? error,
  }) {
    return CoachDirectoryState(
      coaches: coaches ?? this.coaches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasCoaches => coaches.isNotEmpty;
}

@riverpod
class CoachDirectoryController extends _$CoachDirectoryController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<CoachDirectoryState> build() async {
    return _loadCoaches();
  }

  Future<CoachDirectoryState> _loadCoaches() async {
    final coachService = _coachService;
    final report = ref.read(reportProvider);
    try {
      final coaches = await coachService.getAvailableCoaches();
      return CoachDirectoryState(coaches: coaches);
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Coach directory load failed',
      );
      return CoachDirectoryState(error: 'Failed to load coaches: $e');
    }
  }

  /// Refresh coach list
  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _loadCoaches());
    if (ref.mounted) state = result;
  }

  /// Request to connect with a coach (athlete initiates)
  Future<bool> requestCoach(String coachUserId) async {
    final currentState = state.value;
    if (currentState == null) return false;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final coachService = _coachService;
    final report = ref.read(reportProvider);

    try {
      final success = await coachService.requestCoachConnection(coachUserId);

      if (success) {
        if (ref.mounted) {
          state = AsyncData(currentState.copyWith(isLoading: false));
        }
        return true;
      } else {
        if (!ref.mounted) return false;
        state = AsyncData(
          currentState.copyWith(
            isLoading: false,
            error: 'Failed to send coach request',
          ),
        );
        return false;
      }
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'coach_mode',
        message: 'Coach connection request failed',
        extra: {'coachUserId': coachUserId},
      );
      if (!ref.mounted) return false;
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to send coach request: $e',
        ),
      );
      return false;
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
