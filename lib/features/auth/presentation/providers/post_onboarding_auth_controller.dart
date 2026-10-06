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

    _report.info('Post-onboarding auth: Starting Apple Sign-In', area: 'auth');

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
          area: 'auth',
        );
        await _analytics.track(
          'auth_account_already_exists',
          properties: {'provider': 'apple', 'source': 'post_onboarding'},
        );
      } else {
        _report.fault(
          error!,
          area: 'auth',
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
        area: 'auth',
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

    _report.info('Post-onboarding auth: Starting Google Sign-In', area: 'auth');

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
          area: 'auth',
        );
        await _analytics.track(
          'auth_account_already_exists',
          properties: {'provider': 'google', 'source': 'post_onboarding'},
        );
      } else {
        _report.fault(
          error!,
          area: 'auth',
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
        area: 'auth',
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
      area: 'auth',
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
          area: 'auth',
        );
      } else {
        _report.fault(
          state.error!,
          area: 'auth',
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
      area: 'auth',
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
          area: 'auth',
        );
      } else {
        _report.fault(
          state.error!,
          area: 'auth',
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
    // Read before the first await (Riverpod 3: `ref` is unusable once the
    // provider is disposed mid-flight).
    final report = _report;
    final analytics = _analytics;
    final emailAuthService = _emailAuthService;
    state = const AsyncLoading();

    report.info(
      'Post-onboarding auth: Starting email account creation',
      area: 'auth',
    );

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding'},
    );

    state = await AsyncValue.guard(() async {
      await emailAuthService.linkEmailAccount(email: email, password: password);
    });

    if (state.hasError) {
      return _emailCreationFailed(
        report: report,
        analytics: analytics,
        source: 'post_onboarding',
        verb: 'link',
      );
    }

    report.info(
      'Post-onboarding auth: Email account created successfully',
      area: 'auth',
    );

    await analytics.track(
      'auth_flow_completed',
      properties: {'provider': 'email', 'source': 'post_onboarding'},
    );

    return true;
  }

  /// The failure half of [linkEmailAccount] and [signUpWithEmail].
  ///
  /// `state.error` is the underlying exception the service rethrew (an
  /// `AuthApiException`, a network failure), so the Fault carries the real
  /// cause and its stack. It used to be a generic
  /// `Exception('Account creation failed. Please try again.')` that hid the
  /// cause (MEALVANA-ENDURANCE-CG). The user still sees that sentence: the
  /// signup screen shows it from the content system for every failure it
  /// does not route on.
  Future<bool> _emailCreationFailed({
    required Report report,
    required AnalyticsTracker analytics,
    required String source,
    required String verb,
  }) async {
    final error = state.error!;

    // Routing signals, not failures: the screen inspects state.error and
    // pushes the verify-code screen or the "sign in instead" dialog.
    if (error is EmailVerificationRequiredException) {
      report.info(
        'Post-onboarding auth: email $verb pending verification',
        area: 'auth',
      );
      return false;
    }
    if (error is AccountAlreadyExistsException) {
      report.info(
        'Post-onboarding auth: email $verb hit an existing account',
        area: 'auth',
      );
      await analytics.track(
        'auth_account_already_exists',
        properties: {'provider': 'email', 'source': source},
      );
      return false;
    }

    report.fault(
      error,
      stackTrace: state.stackTrace,
      area: 'auth',
      message: verb == 'link'
          ? 'Post-onboarding auth: Email account creation failed'
          : 'Post-onboarding auth: Email signup failed',
    );

    await analytics.track(
      'auth_flow_failed',
      properties: {
        'provider': 'email',
        'source': source,
        'error': error.toString(),
      },
    );
    return false;
  }

  /// Sign up with email/password (creates NEW user)
  /// Used when no Supabase session exists (during onboarding)
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    // Read before the first await (see [linkEmailAccount]).
    final report = _report;
    final analytics = _analytics;
    final emailAuthService = _emailAuthService;
    state = const AsyncLoading();

    report.info(
      'Post-onboarding auth: Starting email signup (new user)',
      area: 'auth',
    );

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding_signup'},
    );

    state = await AsyncValue.guard(() async {
      await emailAuthService.signUpWithEmail(email: email, password: password);
    });

    if (state.hasError) {
      return _emailCreationFailed(
        report: report,
        analytics: analytics,
        source: 'post_onboarding_signup',
        verb: 'signup',
      );
    }

    report.info('Post-onboarding auth: Email signup successful', area: 'auth');

    await analytics.track(
      'auth_flow_completed',
      properties: {'provider': 'email', 'source': 'post_onboarding_signup'},
    );

    return true;
  }

  /// Sign in with email/password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    _report.info('Post-onboarding auth: Starting email sign in', area: 'auth');

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
        area: 'auth',
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
        area: 'auth',
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
      area: 'auth',
    );

    await _analytics.track(
      'auth_skipped',
      properties: {'source': 'post_onboarding'},
    );
  }
}
