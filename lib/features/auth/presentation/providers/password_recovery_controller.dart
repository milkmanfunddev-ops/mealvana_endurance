import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../subscription/application/subscription_status_provider.dart';
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
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
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
    state = const AsyncLoading();
    lastRetryAfterSeconds = null;

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
      final message = state.error.toString();
      if (ResendRateLimitedException.matches(message: message)) {
        // The server's gap between two emails (124-004): a wait, not a
        // failure. The screen counts it down.
        lastRetryAfterSeconds =
            ResendRateLimitedException.secondsFrom(message) ??
            ResendRateLimitedException.serverGapSeconds;
        _logger.info(
          'Reset code not resent yet: server asks to wait',
          context: 'PASSWORD_RECOVERY',
          data: {'retry_after_seconds': lastRetryAfterSeconds},
        );
      } else {
        _logger.error(
          'Failed to send reset code',
          context: 'PASSWORD_RECOVERY',
          error: state.error,
        );
      }
    }

    return !state.hasError;
  }

  /// Verify the 6-digit OTP code sent to the user's email. A right code
  /// opens a recovery session, marked pending until the new password is
  /// saved (124-003).
  Future<bool> verifyResetCode(String email, String token) async {
    state = const AsyncLoading();
    final prefs = _prefs;

    state = await AsyncValue.guard(() async {
      _logger.info('Verifying reset code', context: 'PASSWORD_RECOVERY');
      await _authService.verifyOtp(email: email, token: token);
      await prefs.setBool(recoveryPendingKey, true);
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
    final prefs = _prefs;

    state = await AsyncValue.guard(() async {
      logger.info('Setting new password', context: 'PASSWORD_RECOVERY');
      await authService.updatePassword(newPassword: password);
      // The recovery session did its one job (124-003).
      await prefs.remove(recoveryPendingKey);
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

  /// Leave a reset without saving a password (Cancel or back on Set New
  /// Password, 124-003): the recovery session the code opened is signed out
  /// and the marker cleared, so the phone is signed out on Log In and a
  /// relaunch stays there. The RevenueCat identity the session took is let
  /// go too, so the next account never reads this one's subscription.
  ///
  /// Running twice, or with no session: nothing to sign out; the marker is
  /// cleared either way. Never throws.
  Future<void> cancelRecovery() async {
    // Read before the first await: this notifier is auto-dispose.
    final authService = _authService;
    final logger = _logger;
    final prefs = _prefs;
    final subscriptionStatus = ref.read(subscriptionStatusProvider.notifier);

    await prefs.remove(recoveryPendingKey);
    if (!authService.isAuthenticated) return;
    try {
      await authService.signOut();
      logger.info(
        'Recovery session signed out without a new password',
        context: 'PASSWORD_RECOVERY',
      );
    } catch (e) {
      logger.error(
        'Sign-out of the recovery session failed',
        context: 'PASSWORD_RECOVERY',
        error: e,
      );
    }
    try {
      await subscriptionStatus.clear();
    } catch (e) {
      logger.warning(
        'Pro entitlement clear after the cancelled recovery failed',
        context: 'PASSWORD_RECOVERY',
        error: e,
      );
    }
  }
}
