import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../../../shared/services/report/report.dart';

part 'coach_registration_controller.g.dart';

@riverpod
class CoachRegistrationController extends _$CoachRegistrationController {
  CoachService get _coachService => ref.read(coachServiceProvider);
  Report get _report => ref.read(reportProvider);

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
      final success = await _coachService.submitCoachApplication(
        firstName: firstName,
        lastName: lastName,
        email: email,
        bio: bio,
      );

      if (!success) {
        _report.degraded(
          LoggedFault(
            'Coach application submission failed',
            context: 'COACH_REGISTRATION_CONTROLLER',
          ),
          area: 'coach_mode',
        );
        throw Exception('Failed to submit application. Please try again.');
      }

      return;
    });

    return !state.hasError;
  }
}
