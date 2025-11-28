class AccountAlreadyExistsException implements Exception {
  final String message;
  final String? email;

  AccountAlreadyExistsException(this.message, {this.email});

  @override
  String toString() => 'AccountAlreadyExistsException: $message';
}

