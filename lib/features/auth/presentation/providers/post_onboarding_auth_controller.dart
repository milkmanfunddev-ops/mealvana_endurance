import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/report/report.dart';
import '../../application/oauth_service.dart';
import '../../application/email_auth_service.dart';
import '../../domain/auth_exceptions.dart';

part 'post_onboarding_auth_controller.g.dart';

/// Controller for managing post-onboarding authentication flow
/// Handles native Apple Sign-In, native Google Sign-In, and Email/Password signup
@riverpod
class PostOnboardingAuthController extends _$PostOnboardingAuthController {
  Report get _report => ref.read(reportProvider);
  AnalyticsTracker get _analytics => ref.read(analyticsTrackerProvider);
  OAuthService get _oauthService => ref.read(oAuthServiceProvider.notifier);
  EmailAuthService get _emailAuthService =>
      ref.read(emailAuthServiceProvider.notifier);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Link Apple account using native Apple Sign-In
  Future<bool> linkAppleAccount() async {
    state = const AsyncLoading();

    _report.info('Post-onboarding auth: Starting Apple Sign-In', area: 'AUTH');

    await _analytics.track(
      'auth_flow_started',
      properties: {'provider': 'apple', 'source': 'post_onboarding'},
    );

    state = await AsyncValue.guard(() async {
      await _oauthService.linkAppleAccount();
    });

    if (state.hasError) {
      final error = state.error;

      // Don't log account exists exception as an error - it's a valid flow
      if (error is AccountAlreadyExistsException) {
        _report.info(
          'Post-onboarding auth: Apple account already exists',
          area: 'AUTH',
        );
        await _analytics.track(
          'auth_account_already_exists',
          properties: {'provider': 'apple', 'source': 'post_onboarding'},
        );
      } else {
        _report.fault(
          error!,
          area: 'AUTH',
          message: 'Post-onboarding auth: Apple Sign-In failed',
        );

        await _analytics.track(
          'auth_flow_failed',
          properties: {
            'provider': 'apple',
            'source': 'post_onboarding',
            'error': error.toString(),
          },
        );
      }
    } else {
      _report.info(
        'Post-onboarding auth: Apple Sign-In completed successfully',
        area: 'AUTH',
      );

      await _analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'apple', 'source': 'post_onboarding'},
      );
    }

    return !state.hasError;
  }

  /// Link Google account using native Google Sign-In
  Future<bool> linkGoogleAccount() async {
    state = const AsyncLoading();

    _report.info('Post-onboarding auth: Starting Google Sign-In', area: 'AUTH');

    await _analytics.track(
      'auth_flow_started',
      properties: {'provider': 'google', 'source': 'post_onboarding'},
    );

    state = await AsyncValue.guard(() async {
      await _oauthService.linkGoogleAccount();
    });

    if (state.hasError) {
      final error = state.error;

      // Don't log account exists exception as an error - it's a valid flow
      if (error is AccountAlreadyExistsException) {
        _report.info(
          'Post-onboarding auth: Google account already exists',
          area: 'AUTH',
        );
        await _analytics.track(
          'auth_account_already_exists',
          properties: {'provider': 'google', 'source': 'post_onboarding'},
        );
      } else {
        _report.fault(
          error!,
          area: 'AUTH',
          message: 'Post-onboarding auth: Google Sign-In failed',
        );

        await _analytics.track(
          'auth_flow_failed',
          properties: {
            'provider': 'google',
            'source': 'post_onboarding',
            'error': error.toString(),
          },
        );
      }
    } else {
      _report.info(
        'Post-onboarding auth: Google Sign-In completed successfully',
        area: 'AUTH',
      );

      await _analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'google', 'source': 'post_onboarding'},
      );
    }

    return !state.hasError;
  }

  /// Sign in with Apple (replaces current user)
  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    _report.info(
      'Post-onboarding auth: Switching to existing Apple account',
      area: 'AUTH',
    );

    state = await AsyncValue.guard(() async {
      await _oauthService.signInWithApple();
    });

    if (state.hasError) {
      // Expected control-flow signal: this Apple identity has no account.
      // The screen turns it into "try the provider you signed up with".
      if (state.error is OAuthAccountNotFoundException) {
        _report.info(
          'Post-onboarding auth: no existing account for this Apple identity',
          area: 'AUTH',
        );
      } else {
        _report.fault(
          state.error!,
          area: 'AUTH',
          message: 'Post-onboarding auth: Apple Sign-In failed',
        );
      }
    }

    return !state.hasError;
  }

  /// Sign in with Google (replaces current user)
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    _report.info(
      'Post-onboarding auth: Switching to existing Google account',
      area: 'AUTH',
    );

    state = await AsyncValue.guard(() async {
      await _oauthService.signInWithGoogle();
    });

    if (state.hasError) {
      // Expected control-flow signal: this Google identity has no account.
      // The screen turns it into "try the provider you signed up with".
      if (state.error is OAuthAccountNotFoundException) {
        _report.info(
          'Post-onboarding auth: no existing account for this Google identity',
          area: 'AUTH',
        );
      } else {
        _report.fault(
          state.error!,
          area: 'AUTH',
          message: 'Post-onboarding auth: Google Sign-In failed',
        );
      }
    }

    return !state.hasError;
  }

  /// Link email/password account
  Future<bool> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    _report.info(
      'Post-onboarding auth: Starting email account creation',
      area: 'AUTH',
    );

    await _analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding'},
    );

    state = await AsyncValue.guard(() async {
      await _emailAuthService.linkEmailAccount(
        email: email,
        password: password,
      );
    });

    if (state.hasError) {
      // Pending verification is a routing signal, not a failure — the caller
      // inspects state.error and pushes the verify-code screen.
      if (state.error is EmailVerificationRequiredException) {
        _report.info(
          'Post-onboarding auth: email link pending verification',
          area: 'AUTH',
        );
        return false;
      }

      _report.fault(
        state.error!,
        area: 'AUTH',
        message: 'Post-onboarding auth: Email account creation failed',
      );

      await _analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding',
          'error': state.error.toString(),
        },
      );
    } else {
      _report.info(
        'Post-onboarding auth: Email account created successfully',
        area: 'AUTH',
      );

      await _analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'email', 'source': 'post_onboarding'},
      );
    }

    return !state.hasError;
  }

  /// Sign up with email/password (creates NEW user)
  /// Used when no Supabase session exists (during onboarding)
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    _report.info(
      'Post-onboarding auth: Starting email signup (new user)',
      area: 'AUTH',
    );

    await _analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding_signup'},
    );

    state = await AsyncValue.guard(() async {
      await _emailAuthService.signUpWithEmail(email: email, password: password);
    });

    if (state.hasError) {
      // Pending verification is a routing signal, not a failure.
      if (state.error is EmailVerificationRequiredException) {
        _report.info(
          'Post-onboarding auth: email signup pending verification',
          area: 'AUTH',
        );
        return false;
      }

      _report.fault(
        state.error!,
        area: 'AUTH',
        message: 'Post-onboarding auth: Email signup failed',
      );

      await _analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding_signup',
          'error': state.error.toString(),
        },
      );
    } else {
      _report.info(
        'Post-onboarding auth: Email signup successful',
        area: 'AUTH',
      );

      await _analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'email', 'source': 'post_onboarding_signup'},
      );
    }

    return !state.hasError;
  }

  /// Sign in with email/password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    _report.info('Post-onboarding auth: Starting email sign in', area: 'AUTH');

    await _analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding_login'},
    );

    state = await AsyncValue.guard(() async {
      await _emailAuthService.signInWithEmail(email: email, password: password);
    });

    if (state.hasError) {
      _report.fault(
        state.error!,
        area: 'AUTH',
        message: 'Post-onboarding auth: Email sign in failed',
      );

      await _analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding_login',
          'error': state.error.toString(),
        },
      );
    } else {
      _report.info(
        'Post-onboarding auth: Email sign in successful',
        area: 'AUTH',
      );

      await _analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'email', 'source': 'post_onboarding_login'},
      );
    }

    return !state.hasError;
  }

  /// Track when user skips authentication
  Future<void> skipAuthentication() async {
    _report.info(
      'Post-onboarding auth: User skipped authentication',
      area: 'AUTH',
    );

    await _analytics.track(
      'auth_skipped',
      properties: {'source': 'post_onboarding'},
    );
  }
}
