import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../../../shared/services/logging_service.dart';

part 'coach_registration_controller.g.dart';

@riverpod
class CoachRegistrationController extends _$CoachRegistrationController {
  CoachService get _coachService => ref.read(coachServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<void> build() {
    // Return initial state (no data needed)
  }

  /// Submit a coach application
  /// Returns true if successful, false otherwise
  Future<bool> submitApplication({
    required String firstName,
    required String lastName,
    required String email,
    String? bio,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info(
        'Submitting coach application',
        context: 'COACH_REGISTRATION_CONTROLLER',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
        },
      );

      final success = await _coachService.submitCoachApplication(
        firstName: firstName,
        lastName: lastName,
        email: email,
        bio: bio,
      );

      if (!success) {
        _logger.warning(
          'Coach application submission failed',
          context: 'COACH_REGISTRATION_CONTROLLER',
        );
        throw Exception('Failed to submit application. Please try again.');
      }

      _logger.info(
        'Coach application submitted successfully',
        context: 'COACH_REGISTRATION_CONTROLLER',
      );

      return;
    });

    return !state.hasError;
  }
}
