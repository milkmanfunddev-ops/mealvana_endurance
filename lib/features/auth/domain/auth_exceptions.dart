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

  final String message;

  @override
  String toString() => 'InvalidVerificationCodeException: $message';
}
