import 'signup_code.dart';

/// An expected turn in the signup and verify flows, not a failure (01-005):
/// the screen routes on it or shows a line. The Riverpod net turns one it
/// finds in a notifier's state into an `auth.flow` breadcrumb, never a Fault,
/// and `EmailAuthService.verifyEmailOtp` does not report it; the verify
/// screen's note is its record.
abstract interface class AuthFlowOutcome implements Exception {}

class AccountAlreadyExistsException implements Exception {
  final String message;
  final String? email;

  AccountAlreadyExistsException(this.message, {this.email});

  @override
  String toString() => 'AccountAlreadyExistsException: $message';
}

/// A LOGIN-mode OAuth sign-in reached no existing account.
///
/// Supabase's id-token grant has no "sign in only" mode: when the provider
/// identity is unknown it silently MINTS a brand-new user. For someone who
/// registered with a different provider (Apple vs Google — private-relay
/// emails defeat server-side email matching) that mint looks like total data
/// loss: they land in an empty account with no hint their data lives
/// elsewhere. The sign-in flow detects the mint, signs the empty account back
/// out, and throws this instead — a *control-flow* signal the UI turns into
/// "no account found for this provider; try the one you signed up with".
class OAuthAccountNotFoundException implements Exception {
  const OAuthAccountNotFoundException({required this.provider, this.email});

  /// Lowercase provider slug ('apple' | 'google').
  final String provider;
  final String? email;

  @override
  String toString() =>
      'OAuthAccountNotFoundException: no existing account for $provider';
}

/// The athlete closed the provider's sheet without signing in (testing-wave
/// 125-003): Google's picker dismissed (`signIn()` answered null), or Apple's
/// `ASAuthorizationError.canceled` (1001). A *control-flow* signal, never an
/// error: the service throws it in place of a generic failure, the controller
/// logs it at info, and the screen returns quietly with no "Sign in failed".
/// The simulator's `unknown` Apple error is not a cancel and stays a failure.
class OAuthCancelledException implements Exception {
  const OAuthCancelledException({required this.provider});

  /// Lowercase provider slug ('apple' | 'google').
  final String provider;

  @override
  String toString() => 'OAuthCancelledException: $provider sign-in cancelled';
}

/// Signup succeeded but the address must be verified before a session exists.
///
/// Supabase returns a user with a null session when email confirmation is
/// required. This is a *control-flow* signal, not a failure: the account was
/// created. The caller must route to the verify-code screen and finish signup
/// via `EmailAuthService.verifyEmailOtp` once the user enters the code.
class EmailVerificationRequiredException implements AuthFlowOutcome {
  const EmailVerificationRequiredException({this.userId});

  /// The auth user the signup created (null on the anonymous-upgrade path,
  /// whose uid is the session's). "Use a different email" hands it to
  /// `discard-signup` so an abandoned fresh signup leaves no unconfirmed
  /// login behind (testing-wave 121-003).
  final String? userId;

  @override
  String toString() =>
      'EmailVerificationRequiredException: verification code sent';
}

/// Why an email Log In failed, told apart so the line under the form can say
/// so (testing-wave 125-002, 125-007). Mapped once, in
/// `EmailAuthService.mapSignInError`, from GoTrue's answer.
sealed class EmailSignInException implements Exception {
  const EmailSignInException();
}

/// GoTrue's `invalid_credentials`: the email or the password is wrong.
class WrongCredentialsException extends EmailSignInException {
  const WrongCredentialsException();

  @override
  String toString() => 'WrongCredentialsException';
}

/// The sign-in never reached GoTrue (a socket failure, a retryable fetch).
class NoConnectionException extends EmailSignInException {
  const NoConnectionException(this.cause);

  final Object cause;

  @override
  String toString() => 'NoConnectionException: $cause';
}

/// GoTrue's `email_not_confirmed`: the account exists, its code was never
/// entered. The app resends the signup code and opens Verify your email
/// (testing-wave 124-001).
class EmailNotConfirmedException extends EmailSignInException {
  const EmailNotConfirmedException(this.email);

  final String email;

  @override
  String toString() => 'EmailNotConfirmedException: $email';
}

/// Anything else: GoTrue answered, but not with one of the above.
class SignInFailedException extends EmailSignInException {
  const SignInFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'SignInFailedException: $cause';
}

/// GoTrue refused to send another email yet (429
/// `over_email_send_rate_limit`, "you can only request this after N
/// seconds"). The screens count down [retryAfterSeconds] instead of showing
/// a failure (testing-wave 121-001, 124-004).
///
/// On Verify your email it is the rate-limited kind of
/// [VerificationResendException]; Enter Reset Code uses only its helpers.
class ResendRateLimitedException extends VerificationResendException {
  const ResendRateLimitedException(this.retryAfterSeconds);

  /// Seconds GoTrue asked for; the server's own gap (60 s on dev) when its
  /// message named none.
  final int retryAfterSeconds;

  /// The server's minimum gap between two emails to one address
  /// (`smtp_max_frequency`), which both code screens count down from.
  static const serverGapSeconds = 60;

  /// The wait GoTrue's message names ("after 37 seconds"), or null when it
  /// names none.
  static int? secondsFrom(String message) {
    final match = RegExp(r'after (\d+) seconds?').firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Whether a GoTrue answer is the email rate limit, by code, status or
  /// message.
  static bool matches({String? code, String? statusCode, String? message}) =>
      code == 'over_email_send_rate_limit' ||
      statusCode == '429' ||
      (message ?? '').toLowerCase().contains('rate limit') ||
      (message ?? '').toLowerCase().contains('only request this after');

  @override
  String toString() =>
      'ResendRateLimitedException(retryAfterSeconds: $retryAfterSeconds)';
}

/// Why a 6-digit code was refused (01-002). The screen turns each into its
/// own line from the content system (`auth.verify_email.error_*`).
enum VerificationCodeRejection {
  /// GoTrue refused a code younger than [signupCodeLifetime]: mistyped, or
  /// from an earlier email.
  wrong,

  /// GoTrue refused a code at or past [signupCodeLifetime].
  expired,

  /// Not six digits; never sent.
  malformed,

  /// GoTrue's 429 on verify (`over_request_rate_limit`).
  tooManyTries,
}

/// The 6-digit code was refused. Carries the reason, never the words.
class InvalidVerificationCodeException implements AuthFlowOutcome {
  const InvalidVerificationCodeException(this.reason);

  /// Maps GoTrue's refusal of a code to a reason.
  ///
  /// GoTrue answers a mistyped code, a superseded one and a stale one alike
  /// (403, `otp_expired`, "Token has expired or is invalid"), so the answer
  /// alone cannot tell them apart. The code's age decides: under
  /// [signupCodeLifetime] it is [VerificationCodeRejection.wrong], at or past
  /// it [VerificationCodeRejection.expired] (Lee's ruling on 01-002: each
  /// case gets its own message). An unknown age reads as wrong.
  factory InvalidVerificationCodeException.fromGoTrue({
    String? code,
    String? statusCode,
    required String message,
    Duration? codeAge,
  }) {
    if (code == 'over_request_rate_limit' || statusCode == '429') {
      return const InvalidVerificationCodeException(
        VerificationCodeRejection.tooManyTries,
      );
    }
    final staleAnswer =
        code == 'otp_expired' || message.toLowerCase().contains('expired');
    if (staleAnswer && codeAge != null && codeAge >= signupCodeLifetime) {
      return const InvalidVerificationCodeException(
        VerificationCodeRejection.expired,
      );
    }
    return const InvalidVerificationCodeException(
      VerificationCodeRejection.wrong,
    );
  }

  final VerificationCodeRejection reason;

  @override
  String toString() => 'InvalidVerificationCodeException: ${reason.name}';
}

/// A Resend of the verification code did not send one (01-003). Never a
/// wrong code: the screen shows a countdown or a resend failure, not a code
/// error.
sealed class VerificationResendException implements AuthFlowOutcome {
  const VerificationResendException();
}

/// The Resend went nowhere: no connection, or GoTrue refused it for a reason
/// other than its rate limit. The screen says so
/// (`auth.verify_email.error_resend_failed`).
class VerificationResendFailedException extends VerificationResendException {
  const VerificationResendFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'VerificationResendFailedException: $cause';
}
