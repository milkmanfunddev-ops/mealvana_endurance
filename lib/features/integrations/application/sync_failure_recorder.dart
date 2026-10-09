import '../data/integrations_repository.dart';
import '../domain/integration.dart';
import '../domain/integration_exceptions.dart';

/// The one step every provider's sync failure goes through (testing-wave
/// develop-2026-10 ticket 73). TrainingPeaks, Final Surge, V.O2, Runna and
/// the Garmin mirror all call it, so the same failure leaves the same code
/// on the integration row and Connected Apps shows the same line.
///
/// The rule lives here and nowhere else:
/// - the code is [syncErrorCode] of the error (`network`, `rate_limited`,
///   `http_<status>`, `reauth_required`, `not_a_calendar`, `unknown`);
/// - `reauth_required` stores status `requires_reauth`; every other code
///   stores status `error`.
///
/// What the write does on the row (no write on an inactive or missing row,
/// a stored `requires_reauth` kept over a later `error`) stays inside
/// [IntegrationsRepository.updateSyncStatus] (tickets 64 and 138), and that
/// guard notes its own skip to Sentry (D9).
extension SyncFailureRecorder on IntegrationsRepository {
  /// Records [error] as [provider]'s failed sync and returns the code it
  /// stored (for the sync result and analytics).
  Future<String> recordSyncFailure(
    String userId,
    String provider,
    Object error,
  ) async {
    final code = syncErrorCode(error);
    await updateSyncStatus(
      userId,
      provider,
      status: code == reauthRequiredCode ? requiresReauthStatus : 'error',
      error: code,
    );
    return code;
  }

  /// Records that [provider] refused the connection's token for good, when
  /// the caller knows it without an exception in hand (TrainingPeaks after a
  /// 401 on a fresh token, the server's Garmin `requires_reauth`). Goes
  /// through [recordSyncFailure], so the rule above still decides.
  Future<String> recordReauthRequired(String userId, String provider) =>
      recordSyncFailure(
        userId,
        provider,
        TokenRefreshException(
          'The provider refused the token',
          provider: provider,
          requiresReauth: true,
        ),
      );
}
