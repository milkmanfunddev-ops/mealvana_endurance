import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../application/supabase_auth_service.dart';

part 'password_recovery_controller.g.dart';

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
@riverpod
class PasswordRecoveryController extends _$PasswordRecoveryController {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SupabaseAuthService get _authService => ref.read(supabaseAuthServiceProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Send a password reset code to the given email
  Future<bool> sendResetCode(String email) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info(
        'Sending password reset code',
        context: 'PASSWORD_RECOVERY',
        data: {'email_length': email.length},
      );
      await _authService.resetPassword(email: email);
      _logger.info('Password reset code sent', context: 'PASSWORD_RECOVERY');
    });

    if (state.hasError) {
      _logger.error(
        'Failed to send reset code',
        context: 'PASSWORD_RECOVERY',
        error: state.error,
      );
    }

    return !state.hasError;
  }

  /// Verify the 6-digit OTP code sent to the user's email
  Future<bool> verifyResetCode(String email, String token) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Verifying reset code', context: 'PASSWORD_RECOVERY');
      await _authService.verifyOtp(email: email, token: token);
      _logger.info('Reset code verified', context: 'PASSWORD_RECOVERY');
    });

    if (state.hasError) {
      _logger.error(
        'Reset code verification failed',
        context: 'PASSWORD_RECOVERY',
        error: state.error,
      );
    }

    return !state.hasError;
  }

  /// Set a new password (user must be authenticated via OTP verification)
  Future<bool> setNewPassword(String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Setting new password', context: 'PASSWORD_RECOVERY');
      await _authService.updatePassword(newPassword: password);
      _logger.info(
        'Password updated successfully',
        context: 'PASSWORD_RECOVERY',
      );
    });

    if (state.hasError) {
      _logger.error(
        'Failed to set new password',
        context: 'PASSWORD_RECOVERY',
        error: state.error,
      );
    }

    return !state.hasError;
  }
}
