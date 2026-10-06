import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/report/report.dart';
import '../../application/supabase_auth_service.dart';

part 'password_recovery_controller.g.dart';

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
@riverpod
class PasswordRecoveryController extends _$PasswordRecoveryController {
  Report get _report => ref.read(reportProvider);
  SupabaseAuthService get _authService => ref.read(supabaseAuthServiceProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Send a password reset code to the given email
  Future<bool> sendResetCode(String email) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _report.info(
        'Sending password reset code',
        area: 'PASSWORD_RECOVERY',
        data: {'email_length': email.length},
      );
      await _authService.resetPassword(email: email);
      _report.info('Password reset code sent', area: 'PASSWORD_RECOVERY');
    });

    if (state.hasError) {
      _report.fault(
        state.error!,
        area: 'PASSWORD_RECOVERY',
        message: 'Failed to send reset code',
      );
    }

    return !state.hasError;
  }

  /// Verify the 6-digit OTP code sent to the user's email
  Future<bool> verifyResetCode(String email, String token) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _report.info('Verifying reset code', area: 'PASSWORD_RECOVERY');
      await _authService.verifyOtp(email: email, token: token);
      _report.info('Reset code verified', area: 'PASSWORD_RECOVERY');
    });

    if (state.hasError) {
      _report.fault(
        state.error!,
        area: 'PASSWORD_RECOVERY',
        message: 'Reset code verification failed',
      );
    }

    return !state.hasError;
  }

  /// Set a new password (user must be authenticated via OTP verification)
  Future<bool> setNewPassword(String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _report.info('Setting new password', area: 'PASSWORD_RECOVERY');
      await _authService.updatePassword(newPassword: password);
      _report.info('Password updated successfully', area: 'PASSWORD_RECOVERY');
    });

    if (state.hasError) {
      _report.fault(
        state.error!,
        area: 'PASSWORD_RECOVERY',
        message: 'Failed to set new password',
      );
    }

    return !state.hasError;
  }
}
