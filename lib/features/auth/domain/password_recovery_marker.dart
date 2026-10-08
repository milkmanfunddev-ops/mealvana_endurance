/// The SharedPreferences marker for a password recovery in progress: a
/// recovery session is live and its new password has not been saved.
///
/// `PasswordRecoveryController.verifyResetCode` sets it, `setNewPassword`
/// and `cancelRecovery` clear it, and `AppStartupService.endAbandonedRecovery`
/// signs out a session it finds still marked at launch (testing-wave 124-003).
/// It lives in the domain layer so the application layer can read it without
/// importing presentation code.
const passwordRecoveryPendingKey = 'password_recovery_pending';
