import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/report/report.dart';
import '../../../onboarding/domain/onboarding_draft.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../../application/oauth_service.dart';
import '../../application/email_auth_service.dart';
import '../../data/pending_signup_store.dart';
import '../../domain/auth_exceptions.dart';
import '../../domain/pending_signup.dart';

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
  PendingSignupStore get _pendingSignups =>
      ref.read(pendingSignupStoreProvider);
  OnboardingController get _onboarding =>
      ref.read(onboardingControllerProvider.notifier);

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
      } else if (error is OAuthCancelledException) {
        // The sheet was closed (125-003): not a failure, nothing to report.
        report.info(
          'Post-onboarding auth: Apple sign-in cancelled',
          area: 'auth',
        );
      } else if (error is AppleNoAccountException) {
        // No Apple account on the device (ticket 55): the service noted and
        // counted it; iOS's own sheet told the athlete what to do.
        report.info(
          'Post-onboarding auth: no Apple account on this device',
          area: 'auth',
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

    // State last (ticket 41): the failure is reported above, so the
    // Riverpod net finds it already captured, or files an outcome as an
    // `auth.flow` breadcrumb.
    if (ref.mounted) state = result;
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
      } else if (error is OAuthCancelledException) {
        // The sheet was closed (125-003): not a failure, nothing to report.
        report.info(
          'Post-onboarding auth: Google sign-in cancelled',
          area: 'auth',
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

    // State last (ticket 41): the failure is reported above, so the
    // Riverpod net finds it already captured, or files an outcome as an
    // `auth.flow` breadcrumb.
    if (ref.mounted) state = result;
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
    if (result.hasError) {
      // Expected control-flow signal: this Apple identity has no account.
      // The screen turns it into "try the provider you signed up with".
      if (result.error is OAuthAccountNotFoundException) {
        report.info(
          'Post-onboarding auth: no existing account for this Apple identity',
          area: 'auth',
        );
      } else if (result.error is OAuthCancelledException) {
        // The sheet was closed (125-003): not a failure, nothing to report.
        report.info(
          'Post-onboarding auth: Apple sign-in cancelled',
          area: 'auth',
        );
      } else if (result.error is AppleNoAccountException) {
        // No Apple account on the device (ticket 55): noted by the service.
        report.info(
          'Post-onboarding auth: no Apple account on this device',
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

    // State last (ticket 41): the failure is reported above, so the
    // Riverpod net finds it already captured, or files an outcome as an
    // `auth.flow` breadcrumb.
    if (ref.mounted) state = result;
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
    if (result.hasError) {
      // Expected control-flow signal: this Google identity has no account.
      // The screen turns it into "try the provider you signed up with".
      if (result.error is OAuthAccountNotFoundException) {
        report.info(
          'Post-onboarding auth: no existing account for this Google identity',
          area: 'auth',
        );
      } else if (result.error is OAuthCancelledException) {
        // The sheet was closed (125-003): not a failure, nothing to report.
        report.info(
          'Post-onboarding auth: Google sign-in cancelled',
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

    // State last (ticket 41): the failure is reported above, so the
    // Riverpod net finds it already captured, or files an outcome as an
    // `auth.flow` breadcrumb.
    if (ref.mounted) state = result;
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
    final pending = _pendingSignupDraft(
      email: email,
      password: password,
      verb: 'link',
    );

    report.info(
      'Post-onboarding auth: Starting email account creation',
      area: 'auth',
    );

    await analytics.track(
      'auth_flow_started',
      properties: {'provider': 'email', 'source': 'post_onboarding'},
    );

    final result = await AsyncValue.guard(() async {
      await emailAuth.linkEmailAccount(email: email, password: password);
    });
    if (result.hasError) {
      final ok = await _emailCreationFailed(
        result,
        report: report,
        analytics: analytics,
        source: 'post_onboarding',
        verb: 'link',
        pending: pending,
      );
      // State last (ticket 41): see [linkAppleAccount].
      if (ref.mounted) state = result;
      return ok;
    }
    if (ref.mounted) state = result;

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
  /// `result.error` is the underlying exception the service rethrew (an
  /// `AuthApiException`, a network failure), so the Fault carries the real
  /// cause and its stack. It used to be a generic
  /// `Exception('Account creation failed. Please try again.')` that hid the
  /// cause (MEALVANA-ENDURANCE-CG). The user still sees that sentence: the
  /// signup screen shows it from the content system for every failure it
  /// does not route on.
  ///
  /// A code that went out is written down as a [PendingSignup] before this
  /// returns, so the record exists before the screen pushes Verify your
  /// email and a relaunch from there resumes it (ticket 42, 30-007).
  Future<bool> _emailCreationFailed(
    AsyncValue<void> result, {
    required Report report,
    required AnalyticsTracker analytics,
    required String source,
    required String verb,
    required _PendingSignupDraft pending,
  }) async {
    final error = result.error!;

    // Routing signals, not failures: the screen inspects state.error and
    // pushes the verify-code screen, the "sign in instead" dialog, or the
    // Create Account countdown.
    if (error is EmailVerificationRequiredException) {
      report.info(
        'Post-onboarding auth: email $verb pending verification',
        area: 'auth',
      );
      await pending.write(error);
      return false;
    }
    if (error is ResendRateLimitedException) {
      // GoTrue's gap between two emails to one address (30-008): the
      // service noted it; the form counts it down. No fault, no
      // `auth_flow_failed`.
      report.info(
        'Post-onboarding auth: email $verb rate limited',
        area: 'auth',
        data: {'retry_after_s': error.retryAfterSeconds},
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
      stackTrace: result.stackTrace,
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
    state = const AsyncLoading();
    final report = _report;
    final analytics = _analytics;
    final emailAuth = _emailAuthService;
    final pending = _pendingSignupDraft(
      email: email,
      password: password,
      verb: 'signup',
    );

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
    if (result.hasError) {
      final ok = await _emailCreationFailed(
        result,
        report: report,
        analytics: analytics,
        source: 'post_onboarding_signup',
        verb: 'signup',
        pending: pending,
      );
      // State last (ticket 41): see [linkAppleAccount].
      if (ref.mounted) state = result;
      return ok;
    }
    if (ref.mounted) state = result;

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
    if (result.hasError) {
      final error = result.error!;
      if (error is AuthFlowOutcome) {
        // A wrong password, no connection, an unconfirmed address: the
        // athlete's turn (ticket 41, 30-005). The service already sent its
        // `expected_failure` count; this is the controller's breadcrumb.
        await report.note(
          'Post-onboarding auth: Email sign in: ${error.runtimeType}',
          area: 'auth',
        );
      } else {
        // The service reported the cause and marked its wrapper; reporting
        // the cause again only leaves an "already captured" breadcrumb.
        report.fault(
          error is SignInFailedException ? error.cause : error,
          stackTrace: result.stackTrace,
          area: 'auth',
          message: 'Post-onboarding auth: Email sign in failed',
        );
      }

      await analytics.track(
        'auth_flow_failed',
        properties: {
          'provider': 'email',
          'source': 'post_onboarding_login',
          'error': error is AuthFlowOutcome
              ? error.runtimeType.toString()
              : error.toString(),
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

    // State last (ticket 41): the failure is reported above, so the
    // Riverpod net finds it already captured, or files an outcome as an
    // `auth.flow` breadcrumb.
    if (ref.mounted) state = result;
    return !result.hasError;
  }

  /// What [_emailCreationFailed] needs to write the pending signup, read
  /// before the first await (this controller can be disposed mid-call).
  _PendingSignupDraft _pendingSignupDraft({
    required String email,
    required String password,
    required String verb,
  }) => _PendingSignupDraft(
    store: _pendingSignups,
    email: email,
    password: password,
    isLink: verb == 'link',
    draft: _onboarding.draft,
    anonymousUserId: verb == 'link'
        ? ref.read(appExternalDepsProvider).supabaseClient.auth.currentUser?.id
        : null,
  );

  /// The pending signup a relaunch found (ticket 42, 30-007), with its
  /// onboarding answers put back into the draft so the verified signup saves
  /// them; null when there is none any more (verified or abandoned since).
  ///
  /// Running twice: the second call reads the same record and restores the
  /// same answers.
  Future<PendingSignup?> resumePendingSignup() async {
    final report = _report;
    final onboarding = _onboarding;
    final lookup = await _pendingSignups.read();
    final record = lookup.record;
    if (record == null) {
      await report.note(
        'Resume verify found no pending signup',
        area: 'auth',
        data: {'unreadable': lookup.unreadable},
      );
      return null;
    }
    onboarding.restoreDraft(OnboardingDraft.fromJson(record.draft));
    report.info(
      'Pending signup resumed',
      area: 'auth',
      data: {'otp_type': record.otpType},
    );
    return record;
  }

  /// The upgrade path's deferred password for a resumed [record], from
  /// secure storage; null on the plain path or when it cannot be read.
  Future<String?> resumedPassword(PendingSignup record) async {
    if (!record.isEmailChange) return null;
    return _pendingSignups.readPassword();
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

/// A pending signup about to be written: everything but the answer that
/// decides it (the [EmailVerificationRequiredException]).
class _PendingSignupDraft {
  const _PendingSignupDraft({
    required this.store,
    required this.email,
    required this.password,
    required this.isLink,
    required this.draft,
    required this.anonymousUserId,
  });

  final PendingSignupStore store;
  final String email;
  final String password;
  final bool isLink;
  final OnboardingDraft draft;
  final String? anonymousUserId;

  /// Never throws: the store notes its own failures.
  Future<bool> write(EmailVerificationRequiredException sent) => store.write(
    PendingSignup(
      email: email.trim(),
      otpType: isLink ? PendingSignup.otpEmailChange : PendingSignup.otpSignup,
      codeSentAt: DateTime.now().toUtc(),
      pendingUserId: isLink ? null : sent.userId,
      anonymousUserId: isLink ? anonymousUserId : null,
      draft: draft.toJson(),
    ),
    // GoTrue refuses the upgrade's password until the address is
    // confirmed; the plain path's is already set.
    password: isLink ? password : null,
  );
}
