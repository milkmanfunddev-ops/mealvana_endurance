import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/report/report.dart';
import '../../../ai_credits/data/revenuecat_service.dart';
import '../../application/supabase_auth_service.dart';
import '../../domain/auth_exceptions.dart';

part 'password_recovery_controller.g.dart';

/// Controller for managing OTP-based password recovery flow
/// Steps: 1) Send reset code  2) Verify code  3) Set new password
///
/// The right reset code signs the phone in (GoTrue's recovery OTP opens a
/// session). That session is only ever a means to Set New Password
/// (testing-wave 124-003, Lee 2026-09-26): [verifyResetCode] sets the
/// [recoveryPendingKey] marker, [setNewPassword] clears it, and
/// [cancelRecovery] (Cancel, back) signs the session out. A marker still set
/// at startup means the app was quit on Set New Password:
/// `AppStartupService.endAbandonedRecovery` signs out before routing, so the
/// relaunch lands on Log In.
@riverpod
class PasswordRecoveryController extends _$PasswordRecoveryController {
  Report get _report => ref.report;
  SupabaseAuthService get _authService => ref.read(supabaseAuthServiceProvider);
  SharedPreferences get _prefs =>
      ref.read(appExternalDepsProvider).sharedPreferences;

  /// The SharedPreferences marker: a recovery session is live and its new
  /// password has not been saved.
  static const recoveryPendingKey = 'password_recovery_pending';

  /// The wait GoTrue asked for when the last [sendResetCode] was refused as
  /// too soon (124-004), or null when it was not.
  int? lastRetryAfterSeconds;

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Send a password reset code to the given email
  Future<bool> sendResetCode(String email) async {
    final report = _report;
    final authService = _authService;
    state = const AsyncLoading();
    lastRetryAfterSeconds = null;

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
      final message = result.error.toString();
      if (ResendRateLimitedException.matches(message: message)) {
        // The server's gap between two emails (124-004): a wait, not a
        // failure. The screen counts it down.
        lastRetryAfterSeconds =
            ResendRateLimitedException.secondsFrom(message) ??
            ResendRateLimitedException.serverGapSeconds;
        report.info(
          'Reset code not resent yet: server asks to wait',
          area: 'auth',
          data: {'retry_after_seconds': lastRetryAfterSeconds},
        );
      } else {
        report.fault(
          result.error!,
          area: 'auth',
          message: 'Failed to send reset code',
        );
      }
    }

    return !result.hasError;
  }

  /// Verify the 6-digit OTP code sent to the user's email. A right code
  /// opens a recovery session, marked pending until the new password is
  /// saved (124-003).
  Future<bool> verifyResetCode(String email, String token) async {
    final report = _report;
    final authService = _authService;
    state = const AsyncLoading();
    final prefs = _prefs;

    final result = await AsyncValue.guard(() async {
      report.info('Verifying reset code', area: 'auth');
      await authService.verifyOtp(email: email, token: token);
      await prefs.setBool(recoveryPendingKey, true);
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
    final prefs = _prefs;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info('Setting new password', area: 'auth');
      await authService.updatePassword(newPassword: password);
      // The recovery session did its one job (124-003).
      await prefs.remove(recoveryPendingKey);
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

  /// Leave a reset without saving a password (Cancel or back on Set New
  /// Password, 124-003): the recovery session the code opened is signed out
  /// and the marker cleared, so the phone is signed out on Log In and a
  /// relaunch stays there. The RevenueCat identity the session took is let
  /// go too (develop identifies RevenueCat for AI credits).
  ///
  /// Running twice, or with no session: nothing to sign out; the marker is
  /// cleared either way. Never throws.
  Future<void> cancelRecovery() async {
    // Read before the first await: this notifier is auto-dispose.
    final authService = _authService;
    final report = _report;
    final prefs = _prefs;
    // keepAlive: the service outlives this controller.
    final revenueCat = ref.read(revenueCatServiceProvider);

    await prefs.remove(recoveryPendingKey);
    if (!authService.isAuthenticated) return;
    try {
      await authService.signOut();
      report.info(
        'Recovery session signed out without a new password',
        area: 'auth',
      );
    } catch (e, st) {
      // Swallowed: the screen leaves either way; recorded (D9).
      await report.fault(
        e,
        stackTrace: st,
        area: 'auth',
        message: 'Sign-out of the recovery session failed',
      );
    }
    // Develop identifies RevenueCat for AI credits; mealplanning clears the
    // Pro entitlement here instead. logOut reports its own failures.
    await revenueCat.logOut();
  }
}
