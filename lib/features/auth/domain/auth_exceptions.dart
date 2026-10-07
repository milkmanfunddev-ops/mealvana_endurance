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

/// Signup succeeded but the address must be verified before a session exists.
///
/// Supabase returns a user with a null session when email confirmation is
/// required. This is a *control-flow* signal, not a failure: the account was
/// created. The caller must route to the verify-code screen and finish signup
/// via `EmailAuthService.verifyEmailOtp` once the user enters the code.
class EmailVerificationRequiredException implements Exception {
  const EmailVerificationRequiredException();

  @override
  String toString() =>
      'EmailVerificationRequiredException: verification code sent';
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
