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
  // Each method reads these once, before its first await: the screens reach
  // this auto-dispose controller with `ref.read(...notifier)`, so it can be
  // disposed mid sign-in (Sentry MEALVANA-ENDURANCE-DEV-A0), and the result
  // still has to reach the caller.
  Report get _report => ref.report;
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
    final report = _report;
    final analytics = _analytics;
    final oauth = _oauthService;

    report.info('Post-onboarding auth: Starting Apple Sign-In', area: 'auth');

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'apple', 'source': 'post_onboarding'},
    );

    final result = await AsyncValue.guard(() async {
      await oauth.linkAppleAccount();
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      final error = result.error;

      // Don't log account exists exception as an error - it's a valid flow
      if (error is AccountAlreadyExistsException) {
        report.info(
          'Post-onboarding auth: Apple account already exists',
          area: 'auth',
        );
        await analytics.track(
          'auth_account_already_exists',
          properties: {'provider': 'apple', 'source': 'post_onboarding'},
        );
      } else {
        report.fault(
          error!,
          area: 'auth',
          message: 'Post-onboarding auth: Apple Sign-In failed',
        );

        await analytics.track(
          'auth_flow_failed',
          properties: {
            'provider': 'apple',
            'source': 'post_onboarding',
            'error': error.toString(),
          },
        );
      }
    } else {
      report.info(
        'Post-onboarding auth: Apple Sign-In completed successfully',
        area: 'auth',
      );

      await analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'apple', 'source': 'post_onboarding'},
      );
    }

    return !result.hasError;
  }

  /// Link Google account using native Google Sign-In
  Future<bool> linkGoogleAccount() async {
    state = const AsyncLoading();
    final report = _report;
    final analytics = _analytics;
    final oauth = _oauthService;

    report.info('Post-onboarding auth: Starting Google Sign-In', area: 'auth');

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'google', 'source': 'post_onboarding'},
    );

    final result = await AsyncValue.guard(() async {
      await oauth.linkGoogleAccount();
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      final error = result.error;

      // Don't log account exists exception as an error - it's a valid flow
      if (error is AccountAlreadyExistsException) {
        report.info(
          'Post-onboarding auth: Google account already exists',
          area: 'auth',
        );
        await analytics.track(
          'auth_account_already_exists',
          properties: {'provider': 'google', 'source': 'post_onboarding'},
        );
      } else {
        report.fault(
          error!,
          area: 'auth',
          message: 'Post-onboarding auth: Google Sign-In failed',
        );

        await analytics.track(
          'auth_flow_failed',
          properties: {
            'provider': 'google',
            'source': 'post_onboarding',
            'error': error.toString(),
          },
        );
      }
    } else {
      report.info(
        'Post-onboarding auth: Google Sign-In completed successfully',
        area: 'auth',
      );

      await analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'google', 'source': 'post_onboarding'},
      );
    }

    return !result.hasError;
  }

  /// Sign in with Apple (replaces current user)
  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    final report = _report;
    final oauth = _oauthService;
    report.info(
      'Post-onboarding auth: Switching to existing Apple account',
      area: 'auth',
    );

    final result = await AsyncValue.guard(() async {
      await oauth.signInWithApple();
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      // Expected control-flow signal: this Apple identity has no account.
      // The screen turns it into "try the provider you signed up with".
      if (result.error is OAuthAccountNotFoundException) {
        report.info(
          'Post-onboarding auth: no existing account for this Apple identity',
          area: 'auth',
        );
      } else {
        report.fault(
          result.error!,
          area: 'auth',
          message: 'Post-onboarding auth: Apple Sign-In failed',
        );
      }
    }

    return !result.hasError;
  }

  /// Sign in with Google (replaces current user)
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    final report = _report;
    final oauth = _oauthService;
    report.info(
      'Post-onboarding auth: Switching to existing Google account',
      area: 'auth',
    );

    final result = await AsyncValue.guard(() async {
      await oauth.signInWithGoogle();
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      // Expected control-flow signal: this Google identity has no account.
      // The screen turns it into "try the provider you signed up with".
      if (result.error is OAuthAccountNotFoundException) {
        report.info(
          'Post-onboarding auth: no existing account for this Google identity',
          area: 'auth',
        );
      } else {
        report.fault(
          result.error!,
          area: 'auth',
          message: 'Post-onboarding auth: Google Sign-In failed',
        );
      }
    }

    return !result.hasError;
  }

  /// Link email/password account
  Future<bool> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final report = _report;
    final analytics = _analytics;
    final emailAuth = _emailAuthService;

    report.info(
      'Post-onboarding auth: Starting email account creation',
      area: 'auth',
    );

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding'},
    );

    final result = await AsyncValue.guard(() async {
      await emailAuth.linkEmailAccount(
        email: email,
        password: password,
      );
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      // Pending verification is a routing signal, not a failure — the caller
      // inspects state.error and pushes the verify-code screen.
      if (result.error is EmailVerificationRequiredException) {
        report.info(
          'Post-onboarding auth: email link pending verification',
          area: 'auth',
        );
        return false;
      }

      report.fault(
        result.error!,
        area: 'auth',
        message: 'Post-onboarding auth: Email account creation failed',
      );

      await analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding',
          'error': result.error.toString(),
        },
      );
    } else {
      report.info(
        'Post-onboarding auth: Email account created successfully',
        area: 'auth',
      );

      await analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'email', 'source': 'post_onboarding'},
      );
    }

    return !result.hasError;
  }

  /// Sign up with email/password (creates NEW user)
  /// Used when no Supabase session exists (during onboarding)
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final report = _report;
    final analytics = _analytics;
    final emailAuth = _emailAuthService;

    report.info(
      'Post-onboarding auth: Starting email signup (new user)',
      area: 'auth',
    );

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding_signup'},
    );

    final result = await AsyncValue.guard(() async {
      await emailAuth.signUpWithEmail(email: email, password: password);
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      // Pending verification is a routing signal, not a failure.
      if (result.error is EmailVerificationRequiredException) {
        report.info(
          'Post-onboarding auth: email signup pending verification',
          area: 'auth',
        );
        return false;
      }

      report.fault(
        result.error!,
        area: 'auth',
        message: 'Post-onboarding auth: Email signup failed',
      );

      await analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding_signup',
          'error': result.error.toString(),
        },
      );
    } else {
      report.info(
        'Post-onboarding auth: Email signup successful',
        area: 'auth',
      );

      await analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'email', 'source': 'post_onboarding_signup'},
      );
    }

    return !result.hasError;
  }

  /// Sign in with email/password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final report = _report;
    final analytics = _analytics;
    final emailAuth = _emailAuthService;

    report.info('Post-onboarding auth: Starting email sign in', area: 'auth');

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding_login'},
    );

    final result = await AsyncValue.guard(() async {
      await emailAuth.signInWithEmail(email: email, password: password);
    });
    if (ref.mounted) state = result;

    if (result.hasError) {
      report.fault(
        result.error!,
        area: 'auth',
        message: 'Post-onboarding auth: Email sign in failed',
      );

      await analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding_login',
          'error': result.error.toString(),
        },
      );
    } else {
      report.info(
        'Post-onboarding auth: Email sign in successful',
        area: 'auth',
      );

      await analytics.track(
        'auth_flow_completed',
        properties: {'provider': 'email', 'source': 'post_onboarding_login'},
      );
    }

    return !result.hasError;
  }

  /// Track when user skips authentication
  Future<void> skipAuthentication() async {
    final analytics = _analytics;
    _report.info(
      'Post-onboarding auth: User skipped authentication',
      area: 'auth',
    );

    await analytics.track(
      'auth_skipped',
      properties: {'source': 'post_onboarding'},
    );
  }
}
