/// Custom authentication exception
class AuthException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  const AuthException(this.message, {this.code, this.originalException});

  @override
  String toString() {
    if (code != null) {
      return 'AuthException [$code]: $message';
    }
    return 'AuthException: $message';
  }
}

/// Common auth error codes
class AuthErrorCodes {
  static const String invalidCredentials = 'invalid_credentials';
  static const String userNotFound = 'user_not_found';
  static const String emailAlreadyInUse = 'email_already_in_use';
  static const String weakPassword = 'weak_password';
  static const String invalidEmail = 'invalid_email';
  static const String userDisabled = 'user_disabled';
  static const String tooManyRequests = 'too_many_requests';
  static const String networkError = 'network_error';
  static const String unknown = 'unknown';
}
