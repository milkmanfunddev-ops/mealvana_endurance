import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach.dart';

part 'coach_profile_setup_controller.g.dart';

/// State for coach profile setup/edit
class CoachProfileSetupState {
  final Coach? existingProfile;
  final bool isSubmitting;
  final String? error;

  const CoachProfileSetupState({
    this.existingProfile,
    this.isSubmitting = false,
    this.error,
  });

  CoachProfileSetupState copyWith({
    Coach? existingProfile,
    bool? isSubmitting,
    String? error,
  }) {
    return CoachProfileSetupState(
      existingProfile: existingProfile ?? this.existingProfile,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

@riverpod
class CoachProfileSetupController extends _$CoachProfileSetupController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<CoachProfileSetupState> build() async {
    // Check if user already has a coach profile
    final existingProfile = await _coachService.getCurrentCoachProfile();

    return CoachProfileSetupState(
      existingProfile: existingProfile,
    );
  }

  /// Save or update coach profile
  Future<void> saveProfile({
    required String displayName,
    String? bio,
    List<CoachSpecialization> specializations = const [],
    VoidCallback? onSuccess,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isSubmitting: true, error: null));

    try {
      if (currentState.existingProfile != null) {
        // Update existing profile
        await _coachService.updateCoachProfile(
          displayName: displayName,
          bio: bio,
          specializations: specializations,
        );
      } else {
        // Create new profile
        await _coachService.createCoachProfile(
          displayName: displayName,
          bio: bio,
          specializations: specializations,
        );
      }

      state = AsyncData(currentState.copyWith(isSubmitting: false));
      onSuccess?.call();
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isSubmitting: false,
        error: 'Failed to save profile: ${e.toString()}',
      ));
    }
  }

  /// Clear any error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
