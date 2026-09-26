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
class EmailVerificationRequiredException implements Exception {
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
class ResendRateLimitedException implements Exception {
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

/// The 6-digit code was wrong, expired, or already used.
class InvalidVerificationCodeException implements Exception {
  const InvalidVerificationCodeException(this.message);

  /// Maps GoTrue's refusal of a code to text the athlete can act on.
  ///
  /// GoTrue answers a mistyped code, a superseded one and a stale one alike
  /// (403, `otp_expired`, "Token has expired or is invalid"), so the answer
  /// alone cannot tell them apart. Saying "expired" sent people who had
  /// mistyped to Resend instead of back to the digits (Finding 32-001), so
  /// that answer reads wrong first and names both ways out.
  factory InvalidVerificationCodeException.fromGoTrue({
    String? code,
    String? statusCode,
    required String message,
  }) {
    if (code == 'over_request_rate_limit' || statusCode == '429') {
      return const InvalidVerificationCodeException(tooManyTriesText);
    }
    final lower = message.toLowerCase();
    if (code == 'otp_expired' || lower.contains('expired')) {
      return const InvalidVerificationCodeException(wrongOrExpiredText);
    }
    return const InvalidVerificationCodeException(notRightText);
  }

  /// Whether this is GoTrue's one refusal for a wrong, stale or superseded
  /// code; after a Resend the screen reads it as "use the newest email"
  /// (testing-wave 121-002).
  bool get isWrongOrExpired => message == wrongOrExpiredText;

  static const wrongOrExpiredText =
      'That code is wrong or has expired. Check the digits, or tap Resend '
      'for a new one.';
  static const notRightText = 'That code is not right. Check it and try again.';
  static const tooManyTriesText =
      'Too many tries. Wait a minute and try again.';

  final String message;

  @override
  String toString() => 'InvalidVerificationCodeException: $message';
}
