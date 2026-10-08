import 'dart:async';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../domain/auth_exceptions.dart';
import '../domain/signup_code.dart';
import 'auth_migration_service.dart';

part 'email_auth_service.g.dart';

/// Service for handling Email/Password authentication
/// Uses Supabase's built-in updateUser() to link email to anonymous account
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
@riverpod
class EmailAuthService extends _$EmailAuthService {
  Report get _report => ref.report;
  SupabaseClient get _supabase =>
      ref.read(appExternalDepsProvider).supabaseClient;
  AnalyticsTracker get _analytics => ref.read(analyticsTrackerProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed for this service
  }

  /// Link email/password to existing anonymous user
  /// Preserves the same auth.uid() and all existing user data
  Future<void> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    final report = _report;
    final supabase = _supabase;
    final analytics = _analytics;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      // Defensive check - this should never happen but adding for safety
      if (email.isEmpty || password.isEmpty) {
        report.fault(
          LoggedFault(
            'Empty email or password received',
            context: 'EMAIL_AUTH',
          ),
          area: 'auth',
          extra: {
            'email_length': email.length,
            'password_length': password.length,
            'email_value': email,
          },
        );
        throw Exception('Email and password are required');
      }

      report.info(
        'Starting email account linking',
        area: 'auth',
        data: {
          'email_length': email.length,
          'email_value': email,
          'password_length': password.length,
        },
      );

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        report.fault(
          LoggedFault('Email validation failed', context: 'EMAIL_AUTH'),
          area: 'auth',
          extra: {'email': email, 'validation_error': emailValidation},
        );
        throw Exception(emailValidation);
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation != null) {
        report.fault(
          LoggedFault('Password validation failed', context: 'EMAIL_AUTH'),
          area: 'auth',
          extra: {'validation_error': passwordValidation},
        );
        throw Exception(passwordValidation);
      }

      // Get current anonymous user before linking
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link email account');
      }

      final anonymousUserId = currentUser.id;
      report.info(
        'Linking email account to user',
        area: 'auth',
        data: {
          'current_user_id': anonymousUserId,
          'is_anonymous': currentUser.isAnonymous,
        },
      );

      // CRITICAL: Supabase requires a two-step process for anonymous users:
      // 1. First update with email only
      // 2. Then update with password
      // If done in one step, email gets stripped (known Supabase behavior)
      //
      // Neither step changes auth.uid() — updateUser() mutates the *current*
      // session's user. That is the whole point of this path: `public.users.id`
      // equals `auth.uid()` for an anonymous account, so preserving the uid
      // means every user-scoped row (activities, events, formula_pins,
      // integrations, food_preferences, ...) stays addressable with zero
      // migration.

      report.info(
        'Step 1: Setting email address',
        area: 'auth',
        data: {
          'email': email,
          'email_is_empty': email.isEmpty,
          'email_length': email.length,
        },
      );

      // Create UserAttributes and log what will be sent
      final userAttributes = UserAttributes(email: email);

      report.info(
        'Step 1: UserAttributes created',
        area: 'auth',
        data: {
          'attributes_json': userAttributes.toJson(),
          'email_param': email,
        },
      );

      // Step 1: Update user with email only
      final emailResponse = await supabase.auth.updateUser(userAttributes);

      if (emailResponse.user == null) {
        throw Exception('Email linking failed - no user returned');
      }

      final updatedUser = emailResponse.user!;

      // With email confirmation enabled (production) GoTrue does NOT move the
      // address onto the account here. It parks it in `new_email`, mails a
      // 6-digit code, and leaves the session anonymous with the same uid. Only
      // `verifyOTP(type: emailChange)` completes the upgrade.
      //
      // Dev auto-confirms signups, so this branch is not observable there —
      // hence the belt-and-braces check on both `new_email` and `email`.
      final confirmationPending =
          (updatedUser.newEmail?.isNotEmpty ?? false) ||
          (updatedUser.email ?? '').toLowerCase() != email.toLowerCase();

      report.info(
        'Step 1 complete: Email set',
        area: 'auth',
        data: {
          'user_id': updatedUser.id,
          'email': updatedUser.email,
          'new_email': updatedUser.newEmail,
          'confirmation_pending': confirmationPending,
        },
      );

      // Verify the user ID didn't change (critical for data preservation)
      if (updatedUser.id != anonymousUserId) {
        report.fault(
          LoggedFault('User ID changed during linking', context: 'EMAIL_AUTH'),
          area: 'auth',
          extra: {'old_id': anonymousUserId, 'new_id': updatedUser.id},
        );
        throw Exception('Account linking failed - user ID mismatch');
      }

      if (confirmationPending) {
        // The account is NOT upgraded yet, and the password CANNOT be set here.
        // GoTrue rejects it outright while the address is still parked in
        // `new_email`:
        //   422 validation_failed — "Updating password of an anonymous user
        //   without an email or phone is not allowed"
        // (verified against the dev project on 2026-07-31; see also
        // supabase.com/docs/guides/auth/auth-anonymous — "To add a password for
        // the anonymous user, the user's email or phone number needs to be
        // verified first"). The password is therefore carried to
        // [verifyEmailOtp] and applied once the code is accepted.
        //
        // Stopping here also leaves the local profile untouched on purpose:
        // until the code is verified the session is still anonymous, so an
        // abandoned confirmation must leave a fully usable anonymous account
        // rather than a half-upgraded one.
        report.info(
          'Email link pending verification — password deferred until verify',
          area: 'auth',
          data: {'user_id': anonymousUserId},
        );
        await analytics.track(
          'email_verification_required',
          properties: {'user_id': anonymousUserId, 'flow': 'link'},
        );
        throw const EmailVerificationRequiredException();
      }

      // Auto-confirm path only (no confirmation pending): the address is
      // already on the account, so the password is accepted now.
      report.info('Step 2: Setting password', area: 'auth');

      final response = await supabase.auth.updateUser(
        UserAttributes(password: password),
      );

      if (response.user == null) {
        throw Exception('Password linking failed - no user returned');
      }

      report.info('Step 2 complete: Password set successfully', area: 'auth');

      report.info(
        'Email account linked successfully',
        area: 'auth',
        data: {
          'user_id': response.user!.id,
          'email': response.user!.email,
          'is_anonymous': response.user!.isAnonymous,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      await _completeEmailLink(anonymousUserId);
    });

    // Re-throw errors for UI to handle
    if (result.hasError) {
      final error = result.error;

      // Not a failure — the account exists and the uid is intact; the caller
      // must collect the emailed code. Surface it verbatim so the UI can
      // route to the verify screen instead of showing "creation failed".
      // The Riverpod net files it as an `auth.flow` breadcrumb (01-005).
      if (error is EmailVerificationRequiredException) {
        if (ref.mounted) state = result;
        throw error;
      }

      // Report first, then write state (01-005): the observer then finds the
      // error already captured, so the one event carries `area: auth`.
      try {
        await _failAccountCreation(
          error!,
          result.stackTrace,
          email: email,
          report: report,
          analytics: analytics,
          reportMessage: 'Email account linking failed',
          analyticsEvent: 'email_account_linking_failed',
        );
      } catch (thrown, stack) {
        _writeFailedCreation(result, thrown, stack);
        rethrow;
      }
    }

    if (ref.mounted) state = result;
  }

  /// Ends a failed signup or link: reports [error] once and rethrows it, or
  /// the [AccountAlreadyExistsException] the UI routes on.
  ///
  /// The cause itself is rethrown, never a generic wrapper. A wrapper like the
  /// old `Exception('Account creation failed. Please try again.')` was a new
  /// object, so `Report`'s identity dedupe could not match it to the cause:
  /// it became its own Sentry issue with no cause in it
  /// (MEALVANA-ENDURANCE-CG, DEV-8Q, DEV-8X), next to the real one (CH,
  /// DEV-8P, DEV-8W). The user-facing text belongs to the signup screen
  /// (`auth.post_onboarding.error_email_failed`), which never read the
  /// wrapper's message.
  Future<Never> _failAccountCreation(
    Object error,
    StackTrace? stackTrace, {
    required String email,
    required Report report,
    required AnalyticsTracker analytics,
    required String reportMessage,
    required String analyticsEvent,
  }) async {
    final trace = stackTrace ?? StackTrace.current;

    if (error is AuthApiException &&
        (error.message.contains('already registered') ||
            error.message.contains('already been registered'))) {
      // An athlete's own turn, not a failure (ticket 41, 30-005): a note and
      // one `expected_failure` count, no event. The caller writes the
      // outcome, not GoTrue's 422, into state.
      final outcome = AccountAlreadyExistsException(
        'This email is already registered',
        email: email,
      );
      await report.noteExpected(
        '$reportMessage: email already registered',
        area: 'auth',
        reason: authOutcomeReason(outcome),
        analytics: analytics,
      );
      throw outcome;
    }

    report.fault(
      error,
      stackTrace: trace,
      area: 'auth',
      message: reportMessage,
    );

    await analytics.track(
      analyticsEvent,
      properties: {'error': error.toString()},
    );

    Error.throwWithStackTrace(error, trace);
  }

  /// The state a failed signup or link leaves (ticket 41, 30-005): the
  /// [AccountAlreadyExistsException] [_failAccountCreation] threw in place of
  /// GoTrue's 422, so the Riverpod net files an `auth.flow` breadcrumb and
  /// not a fault with no area; for anything else the original [result],
  /// which [_failAccountCreation] has already reported, so the net skips it.
  /// Runs after the report, never before it.
  void _writeFailedCreation(
    AsyncValue<void> result,
    Object thrown,
    StackTrace stack,
  ) {
    if (!ref.mounted) return;
    state = thrown is AccountAlreadyExistsException
        ? AsyncError<void>(thrown, stack)
        : result;
  }

  /// Finish an anonymous -> email upgrade once the uid-preserving link is real.
  ///
  /// Reached from two places that differ only in *when* the email became real:
  /// immediately (auto-confirm, i.e. dev) or after the user enters the emailed
  /// code (confirmation on, i.e. prod). Both end in the same place, which is
  /// the point: one completion path, one set of side effects.
  ///
  /// `preservedUserId: true` tells [AuthMigrationService] there is nothing to
  /// migrate — the uid never moved — so it only flips the identity fields
  /// (`auth_provider`, `is_anonymous: false`) locally and in Supabase.
  Future<void> _completeEmailLink(String userId) async {
    final report = _report;
    final analytics = _analytics;
    final authMigrationService = await ref.read(
      authMigrationServiceProvider.future,
    );
    await authMigrationService.completeAuthentication(
      previousUserId: userId,
      wasAnonymous: true,
      newUserId: userId, // Same ID for linking
      authProvider: 'email',
      preservedUserId: true, // ID was preserved during linking
    );

    // CRITICAL: Invalidate userIdProvider to force re-read with updated
    // authUserId. Without this, the provider remains cached with old data.
    ref.invalidate(userIdProvider);

    await analytics.track(
      'email_account_linked',
      properties: {'user_id': userId},
    );

    report.info('Email account linking complete', area: 'auth');
  }

  /// Sign up with email/password (creates NEW user)
  /// Used when no Supabase session exists (during onboarding)
  /// This creates a brand new Supabase auth user with email/password credentials
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final report = _report;
    final supabase = _supabase;
    final analytics = _analytics;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info(
        'Starting email signup (new user)',
        area: 'auth',
        data: {'email_length': email.length},
      );

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        throw Exception(emailValidation);
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation != null) {
        throw Exception(passwordValidation);
      }

      // Create NEW Supabase auth user with email/password
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to create account - no user returned');
      }

      final newUserId = response.user!.id;

      // Email confirmation required: Supabase returns the user but NO session
      // until the address is verified. Everything below this point (and the
      // onboarding-data migration the caller runs afterwards) assumes an
      // authenticated session — without one, every RLS-protected write fails.
      //
      // So stop here and tell the caller to collect the code. The rest of the
      // signup completes in [verifyEmailOtp] once a session exists.
      if (response.session == null) {
        report.info(
          'Email signup pending verification',
          area: 'auth',
          data: {'user_id': newUserId},
        );
        await analytics.track(
          'email_verification_required',
          properties: {'user_id': newUserId},
        );
        throw EmailVerificationRequiredException(userId: newUserId);
      }

      report.info(
        'Email signup successful',
        area: 'auth',
        data: {
          'user_id': newUserId,
          'email': response.user!.email,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      // NOTE: Do NOT call completeAuthentication() or clear onboarding_temp_user_id here.
      // During onboarding, activities/integrations synced from Final Surge / Training Peaks
      // are stored locally under a temp UUID and were never uploaded to Supabase.
      // completeAuthentication() checks Supabase for data (finds none) and skips migration.
      // Instead, onboardingController.saveAllOnboardingData() handles migration via
      // _migrateOnboardingDataToNewUser() which correctly migrates LOCAL database data
      // and clears the temp user ID afterward.

      // CRITICAL: Invalidate userIdProvider to force re-read with new user
      ref.invalidate(userIdProvider);
      report.info('Invalidated userIdProvider after signup', area: 'auth');

      // Track successful signup in analytics
      await analytics.track(
        'email_account_created',
        properties: {
          'user_id': newUserId,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      report.info('Email signup complete', area: 'auth');
    });

    // Re-throw errors for UI to handle
    if (result.hasError) {
      final error = result.error;

      // Control-flow signal, not a failure: the account was created and the
      // caller must collect the emailed code. Rethrowing it verbatim is what
      // lets the UI tell "verify me" apart from "creation failed" — the
      // generic wrapper below would erase that distinction. The Riverpod net
      // files it as an `auth.flow` breadcrumb (01-005).
      if (error is EmailVerificationRequiredException) {
        if (ref.mounted) state = result;
        throw error;
      }

      // Report first, then write state (01-005): see [linkEmailAccount].
      try {
        await _failAccountCreation(
          error!,
          result.stackTrace,
          email: email,
          report: report,
          analytics: analytics,
          reportMessage: 'Email signup failed',
          analyticsEvent: 'email_signup_failed',
        );
      } catch (thrown, stack) {
        _writeFailedCreation(result, thrown, stack);
        rethrow;
      }
    }

    if (ref.mounted) state = result;
  }

  /// Sign in with email/password
  /// This will replace the current anonymous session with the email user's session
  /// Complete a pending signup by verifying the 6-digit code that was emailed.
  ///
  /// On success Supabase issues the session that [signUpWithEmail] could not,
  /// so this is where the post-signup work actually lands: invalidating
  /// [userIdProvider] so every downstream read picks up the new authenticated
  /// id. The caller then runs the onboarding-data migration, exactly as it
  /// would have done for an auto-confirmed signup.
  ///
  /// [type] selects which pending flow the code belongs to:
  /// - [OtpType.signup] — a brand-new account (no prior session).
  /// - [OtpType.emailChange] — an anonymous account being upgraded in place.
  ///   GoTrue treats "attach an email to an existing user" as an email change,
  ///   so this is the type the uid-preserving path must use. On success the
  ///   session comes back with the SAME uid, now non-anonymous, and the link
  ///   completion runs here.
  /// [pendingPassword] applies only to [OtpType.emailChange]. GoTrue refuses to
  /// set a password on an anonymous user whose email is still unconfirmed, so
  /// [linkEmailAccount] defers it to here and it is applied immediately after
  /// the code is accepted.
  ///
  /// [codeSentAt] is when the code being entered was sent (the verify screen
  /// records it). GoTrue refuses a wrong and a stale code alike, so the
  /// code's age against [signupCodeLifetime] decides which one the athlete
  /// is told (01-002). Null reads a refusal as wrong.
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
    String? pendingPassword,
    DateTime? codeSentAt,
  }) async {
    final report = _report;
    final supabase = _supabase;
    final analytics = _analytics;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      final code = token.trim();
      if (code.length != 6 || int.tryParse(code) == null) {
        throw const InvalidVerificationCodeException(
          VerificationCodeRejection.malformed,
        );
      }

      report.info(
        'Verifying email code',
        area: 'auth',
        data: {'otp_type': type.name},
      );

      // Captured before the verify so the uid assertion below has something to
      // compare against on the upgrade path.
      final priorUserId = supabase.auth.currentUser?.id;

      final AuthResponse response;
      try {
        response = await supabase.auth.verifyOTP(
          email: email.trim(),
          token: code,
          type: type,
        );
      } on AuthApiException catch (e) {
        // A 5xx is GoTrue failing, not the code being refused: it stays a
        // real failure and is reported below.
        final status = int.tryParse(e.statusCode ?? '');
        if (status != null && status >= 500) rethrow;
        // GoTrue reports a wrong and a stale code with one answer; the code's
        // age tells them apart (see fromGoTrue).
        throw InvalidVerificationCodeException.fromGoTrue(
          code: e.code,
          statusCode: e.statusCode,
          message: e.message,
          codeAge: codeSentAt == null
              ? null
              : DateTime.now().difference(codeSentAt),
        );
      }

      if (response.session == null) {
        // GoTrue accepted the code but issued no session: not the athlete's
        // doing, so a real failure (the screen shows its generic line).
        throw StateError('verifyOTP accepted the code but returned no session');
      }

      ref.invalidate(userIdProvider);

      await analytics.track(
        'email_verification_completed',
        properties: {'user_id': response.user?.id, 'otp_type': type.name},
      );
      report.info('Email verified; session established', area: 'auth');

      if (type == OtpType.emailChange) {
        final newUserId = response.user!.id;

        // The upgrade is only safe if the uid survived. If GoTrue ever hands
        // back a different user here, completing the link would silently
        // orphan every row keyed by the old id — fail loudly instead.
        if (priorUserId != null && priorUserId != newUserId) {
          report.fault(
            LoggedFault(
              'User ID changed during email verification',
              context: 'EMAIL_AUTH',
            ),
            area: 'auth',
            extra: {'old_id': priorUserId, 'new_id': newUserId},
          );
          throw Exception('Account linking failed - user ID mismatch');
        }

        // The email is confirmed and on the account now, so the password
        // deferred by [linkEmailAccount] is finally accepted. This runs before
        // the profile flip so a password failure is still surfaced to the user
        // — without it they would finish the flow unable to sign back in.
        if (pendingPassword != null && pendingPassword.isNotEmpty) {
          report.info(
            'Applying deferred password after verification',
            area: 'auth',
          );
          final pwResponse = await supabase.auth.updateUser(
            UserAttributes(password: pendingPassword),
          );
          if (pwResponse.user == null) {
            throw Exception('Password could not be set after verification');
          }
          if (pwResponse.user!.id != newUserId) {
            throw Exception('Account linking failed - user ID mismatch');
          }
        }

        // The auth-level upgrade is already durable at this point (GoTrue has
        // issued a non-anonymous session for the same uid). A failure while
        // flipping the profile fields must NOT fail the verification: the code
        // is single-use, so rethrowing would strand the user on the verify
        // screen with a spent code. `updateUserProfile` leaves the row dirty on
        // a failed write, so background sync retries it.
        try {
          await _completeEmailLink(newUserId);
        } catch (e, stackTrace) {
          report.fault(
            e,
            stackTrace: stackTrace,
            area: 'auth',
            message:
                'Email link completion failed after verification — session is '
                'upgraded, profile flip will retry via sync',
          );
        }
      }
    });

    if (result.hasError) {
      final error = result.error!;
      // A refused code is the athlete's turn, not a failure (01-005): the
      // screen notes it and the Riverpod net leaves an `auth.flow`
      // breadcrumb. Anything else is reported first, then written to state,
      // so the one event carries `area: auth`.
      if (error is! AuthFlowOutcome) {
        report.fault(
          error,
          stackTrace: result.stackTrace,
          area: 'auth',
          message: 'Email verification failed',
        );
      }
      if (ref.mounted) state = result;
      Error.throwWithStackTrace(error, result.stackTrace ?? StackTrace.current);
    }

    if (ref.mounted) state = result;
  }

  /// Re-send the signup verification code.
  ///
  /// Rate limits are enforced server-side (and are tight on the default
  /// mailer), so a failure here is expected and must read as "wait a moment",
  /// not "something is broken".
  ///
  /// The server allows one email per address per 60 s (`smtp_max_frequency`).
  /// Its 429 is raised as [ResendRateLimitedException] with the wait its
  /// message names, so the screen counts that down instead of saying the
  /// resend failed (testing-wave 121-001, 124-004).
  ///
  /// Every other failure, a network one included, comes back as
  /// [VerificationResendFailedException], never as an escaped error (01-003).
  /// [lastSentAt] is when the previous code went out; the note carries the
  /// gap, so a resend that answered 200 but sent nothing can be lined up
  /// against the mailbox.
  ///
  /// Running twice at once: the screen disables Resend while it counts down,
  /// and GoTrue answers the second request inside its gap with a 429, which
  /// becomes a countdown. Nothing here holds state between calls.
  Future<void> resendVerificationCode({
    required String email,
    OtpType type = OtpType.signup,
    DateTime? lastSentAt,
  }) async {
    final report = _report;
    final supabase = _supabase;
    final analytics = _analytics;
    try {
      // OtpType.emailChange belongs to the anonymous upgrade and goes with
      // its removal (Lee's ruling 2026-10-07); left as it is.
      await supabase.auth.resend(type: type, email: email.trim());
    } on AuthApiException catch (e, st) {
      if (ResendRateLimitedException.matches(
        code: e.code,
        statusCode: e.statusCode,
        message: e.message,
      )) {
        throw ResendRateLimitedException(
          ResendRateLimitedException.secondsFrom(e.message) ??
              ResendRateLimitedException.serverGapSeconds,
        );
      }
      // GoTrue answered and refused: worth a warning event (D9).
      await report.degraded(
        e,
        stackTrace: st,
        area: 'auth',
        message: 'Verification code resend refused',
        extra: {'otp_type': type.name},
      );
      throw VerificationResendFailedException(e);
    } catch (e) {
      // No connection (AuthRetryableFetchException, SocketException,
      // ClientException) or anything else: the screen says the resend
      // failed, and the note records it (D9).
      await report.note(
        'Verification code resend failed',
        area: 'auth',
        data: {'otp_type': type.name, 'error_type': e.runtimeType.toString()},
      );
      throw VerificationResendFailedException(e);
    }
    await analytics.track('email_verification_resent');
    await report.note(
      'Verification code resent',
      area: 'auth',
      data: {
        'otp_type': type.name,
        'seconds_since_last_send': lastSentAt == null
            ? null
            : DateTime.now().difference(lastSentAt).inSeconds,
      },
    );
  }

  /// Ask the server to delete a fresh signup the athlete walked away from
  /// before entering its code (testing-wave 121-003): "Use a different
  /// email" or "Log in" on Verify your email. Best effort and fire-and-forget:
  /// there is no session, so this goes through `discard-signup`, which
  /// deletes only a matching unconfirmed, never-signed-in, recent user and
  /// answers the same 200 whatever happened. A failure here is logged and
  /// changes nothing on the screen.
  ///
  /// Running twice: the second call finds no user and deletes nothing.
  Future<void> discardSignup({
    required String userId,
    required String email,
  }) async {
    final report = _report;
    final supabase = _supabase;
    try {
      await supabase.functions.invoke(
        'discard-signup',
        body: {'user_id': userId, 'email': email.trim()},
      );
      report.info(
        'Abandoned signup discarded',
        area: 'auth',
        data: {'user_id': userId},
      );
    } catch (e, st) {
      // Nothing on screen changes; recorded (D9).
      await report.degraded(
        e,
        stackTrace: st,
        area: 'auth',
        message:
            'discard-signup failed; the unconfirmed login stays until it is '
            'cleaned up',
      );
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final report = _report;
    final supabase = _supabase;
    final analytics = _analytics;
    final prefs = ref.read(sharedPreferencesProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      report.info(
        'Starting email sign in',
        area: 'auth',
        data: {'email_length': email.length},
      );

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        throw Exception(emailValidation);
      }

      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      // CRITICAL: Capture anonymous user ID BEFORE signing in
      // This allows us to migrate their data after the session switch
      var previousUserId = supabase.auth.currentUser?.id;
      var wasAnonymous = supabase.auth.currentUser?.isAnonymous ?? false;

      // Also check for temp onboarding user ID (used when no Supabase session exists)
      // This handles the case where user synced with TP/FS during onboarding then signs in
      final tempUserId = prefs.getString('onboarding_temp_user_id');
      if (previousUserId == null && tempUserId != null) {
        previousUserId = tempUserId;
        wasAnonymous = true;
      }

      report.info(
        'Capturing user state before sign-in',
        area: 'auth',
        data: {
          'previous_user_id': previousUserId,
          'was_anonymous': wasAnonymous,
          'had_temp_user_id': tempUserId != null,
        },
      );

      // Sign in with Supabase
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw Exception('Sign in failed - no session returned');
      }

      final newUserId = response.user!.id;

      report.info(
        'Email sign in successful',
        area: 'auth',
        data: {'user_id': newUserId, 'email': response.user!.email},
      );

      // Complete authentication (unified flow for all providers)
      final authMigrationService = await ref.read(
        authMigrationServiceProvider.future,
      );
      final dataMigrated = await authMigrationService.completeAuthentication(
        previousUserId: previousUserId,
        wasAnonymous: wasAnonymous,
        newUserId: newUserId,
        authProvider: 'email',
        preservedUserId: false, // ID changed during sign-in
      );

      // Clear temp user ID after successful migration
      if (tempUserId != null) {
        await prefs.remove('onboarding_temp_user_id');
        report.info(
          'Cleared onboarding temp user ID after sign-in migration',
          area: 'auth',
        );
      }

      // CRITICAL: Invalidate userIdProvider to force re-read after auth change
      ref.invalidate(userIdProvider);
      report.info('Invalidated userIdProvider after sign-in', area: 'auth');

      report.info(
        'Sign-in completion handled',
        area: 'auth',
        data: {'data_migrated': dataMigrated},
      );

      // Track successful sign in
      await analytics.track(
        'email_sign_in_success',
        properties: {'user_id': newUserId, 'migrated_data': dataMigrated},
      );

      // Trigger sync after sign-in to pull user data from Supabase
      // This is essential for new device logins where local DB is empty
      report.info(
        'Triggering post-sign-in sync',
        area: 'auth',
        data: {'user_id': newUserId},
      );

      try {
        // CRITICAL: Clear sync timestamp to force full sync (not incremental)
        // Otherwise, if user logs out and back in on same device, we might send
        // an old timestamp and get no data back (because local DB was cleared)
        await prefs.remove('last_sync_timestamp_$newUserId');

        // Sync all data including coach status (handled by edge function)
        await syncCoordinator.sync(
          userId: newUserId,
          trigger: SyncTrigger.oauthSignIn,
        );
        report.info('Post-sign-in sync completed', area: 'auth');
      } catch (e) {
        report.fault(e, area: 'auth', message: 'Post-sign-in sync failed');
        // Don't rethrow - sign-in was successful, user can pull-to-refresh
      }
    });

    // Re-throw errors for UI to handle, told apart (125-002, 125-007).
    // Map and report BEFORE writing state (ticket 41, 30-005, 32-007): the
    // Riverpod net then sees the mapped outcome (a breadcrumb) or an error
    // already captured with `area: auth`, never GoTrue's raw exception.
    if (result.hasError) {
      final mapped = mapSignInError(result.error!, email: email);
      if (mapped is AuthFlowOutcome) {
        // A wrong password, no connection, or an address that wants its
        // code (124-001): the athlete's turn, not a failure. One note, one
        // `expected_failure` count, no event.
        await report.noteExpected(
          'Email sign in: ${mapped.runtimeType}',
          area: 'auth',
          reason: authOutcomeReason(mapped),
          analytics: analytics,
        );
        if (ref.mounted) {
          state = AsyncError<void>(
            mapped,
            result.stackTrace ?? StackTrace.current,
          );
        }
      } else {
        report.fault(
          result.error!,
          stackTrace: result.stackTrace,
          area: 'auth',
          message: 'Email sign in failed',
        );
        // The wrapper is the same failure as its cause: the controller and
        // the Riverpod net, which only ever see the wrapper, must not send a
        // second event for it.
        SentryReport.markReported(mapped);
        if (ref.mounted) state = result;
      }
      throw mapped;
    }

    if (ref.mounted) state = result;
  }

  /// GoTrue's answer to a password sign-in, as one of the
  /// [EmailSignInException] kinds (125-002, 125-007, 124-001):
  /// `invalid_credentials` is a wrong email or password; a socket or
  /// retryable fetch failure is no connection; `email_not_confirmed` is an
  /// account waiting for its code; anything else is a general failure. An
  /// already-typed exception passes through.
  static EmailSignInException mapSignInError(
    Object error, {
    required String email,
  }) {
    if (error is EmailSignInException) return error;
    if (error is AuthRetryableFetchException ||
        error is SocketException ||
        error is http.ClientException) {
      return NoConnectionException(error);
    }
    if (error is AuthApiException) {
      final message = error.message.toLowerCase();
      if (error.code == 'invalid_credentials' ||
          message.contains('invalid login credentials')) {
        return const WrongCredentialsException();
      }
      if (error.code == 'email_not_confirmed' ||
          message.contains('email not confirmed')) {
        return EmailNotConfirmedException(email.trim());
      }
    }
    return SignInFailedException(error);
  }

  /// Validate email format
  String? validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email is required';
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null; // Valid
  }

  /// Validate password strength
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Optional: Add more validation rules
    // - Uppercase letter
    // - Number
    // - Special character

    return null; // Valid
  }
}
