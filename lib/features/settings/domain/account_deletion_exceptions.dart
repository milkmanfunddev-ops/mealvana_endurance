/// The `delete-user` function did not confirm the delete: it could not be
/// reached, or it answered anything but 200 (testing-wave 121-007, 121-009).
///
/// A control-flow signal, not a crash: `SettingsController.deleteAccount`
/// stops before the local wipe, the RevenueCat logout and the sign-out, so
/// the athlete stays signed in with their data, and the screen says the
/// delete needs a connection. Nothing is half-deleted.
class AccountDeletionNeedsConnectionException implements Exception {
  const AccountDeletionNeedsConnectionException(this.reason);

  /// What the function answered, for the log only.
  final String reason;

  @override
  String toString() => 'AccountDeletionNeedsConnectionException: $reason';
}
