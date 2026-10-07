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
    final report = _report;
    final authService = _authService;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info('Setting new password', area: 'auth');
      await authService.updatePassword(newPassword: password);
      report.info('Password updated successfully', area: 'auth');

      try {
        await authService.signOutEverywhere();
        report.info('Signed out every session after the reset', area: 'auth');
      } catch (e, st) {
        // Swallowed on purpose (the password did change); recorded (D9).
        await report.degraded(
          e,
          stackTrace: st,
          area: 'auth',
          message: 'Sign-out of every session after the reset failed',
        );
      }
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
