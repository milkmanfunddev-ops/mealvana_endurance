import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/report/report.dart';
import '../../application/supabase_auth_service.dart';

part 'password_recovery_controller.g.dart';

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
@riverpod
class PasswordRecoveryController extends _$PasswordRecoveryController {
  Report get _report => ref.report;
  SupabaseAuthService get _authService => ref.read(supabaseAuthServiceProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Send a password reset code to the given email
  Future<bool> sendResetCode(String email) async {
    final report = _report;
    final authService = _authService;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info(
        'Sending password reset code',
        area: 'auth',
        data: {'email_length': email.length},
      );
      await authService.resetPassword(email: email);
      report.info('Password reset code sent', area: 'auth');
    });

    if (ref.mounted) state = result;

    if (result.hasError) {
      report.fault(
        result.error!,
        area: 'auth',
        message: 'Failed to send reset code',
      );
    }

    return !result.hasError;
  }

  /// Verify the 6-digit OTP code sent to the user's email
  Future<bool> verifyResetCode(String email, String token) async {
    final report = _report;
    final authService = _authService;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info('Verifying reset code', area: 'auth');
      await authService.verifyOtp(email: email, token: token);
      report.info('Reset code verified', area: 'auth');
    });

    if (ref.mounted) state = result;

    if (result.hasError) {
      report.fault(
        result.error!,
        area: 'auth',
        message: 'Reset code verification failed',
      );
    }

    return !result.hasError;
  }

  /// Set a new password (user must be authenticated via OTP verification)
  Future<bool> setNewPassword(String password) async {
    final report = _report;
    final authService = _authService;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info('Setting new password', area: 'auth');
      await authService.updatePassword(newPassword: password);
      report.info('Password updated successfully', area: 'auth');
    });

    if (ref.mounted) state = result;

    if (result.hasError) {
      report.fault(
        result.error!,
        area: 'auth',
        message: 'Failed to set new password',
      );
    }

    return !result.hasError;
  }
}
