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

  /// Set a new password (user must be authenticated via OTP verification),
  /// then end every session of the account (ticket 108, Finding 32-003, Lee
  /// 2026-09-25): the recovery session the code opened and any other device.
  /// The athlete signs in once with the new password.
  ///
  /// A failed update signs nothing out. A sign-out that fails after the
  /// update still reports success: the password did change, and GoTrue drops
  /// this device's session before it calls the server, so the athlete lands
  /// on Log In either way.
  Future<bool> setNewPassword(String password) async {
    state = const AsyncLoading();

    // Read before the first await: this notifier is auto-dispose.
    final authService = _authService;
    final logger = _logger;

    state = await AsyncValue.guard(() async {
      logger.info('Setting new password', context: 'PASSWORD_RECOVERY');
      await authService.updatePassword(newPassword: password);
      logger.info(
        'Password updated successfully',
        context: 'PASSWORD_RECOVERY',
      );

      try {
        await authService.signOutEverywhere();
        logger.info(
          'Signed out every session after the reset',
          context: 'PASSWORD_RECOVERY',
        );
      } catch (e) {
        logger.error(
          'Sign-out of every session after the reset failed',
          context: 'PASSWORD_RECOVERY',
          error: e,
        );
      }
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
