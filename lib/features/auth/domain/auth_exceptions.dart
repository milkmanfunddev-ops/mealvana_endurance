class AccountAlreadyExistsException implements Exception {
  final String message;
  final String? email;

  AccountAlreadyExistsException(this.message, {this.email});

  @override
  String toString() => 'AccountAlreadyExistsException: $message';
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
