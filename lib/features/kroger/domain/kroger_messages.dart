import '../../content/domain/content_keys.dart';

/// Message codes carried by `KrogerState.message` — raised by the edge
/// function as `error`/`reason`, by `KrogerException`, or set by the
/// controller — mapped to the content key that explains them to the shopper.
///
/// Codes the server can raise that have no shopper-facing explanation of
/// their own (`invalid_body`, `invalid_action`, `invalid_token_response`,
/// and their kin) are deliberately absent: they describe a request this app
/// built wrong, and there is nothing a shopper can do about one. They resolve
/// to null and the caller shows [ContentKeys.krogerUnavailable].
const Map<String, String> _messageKeys = {
  'all_skipped': ContentKeys.krogerAllSkipped,
  'authorization_cancelled': ContentKeys.krogerAuthorizationCancelled,
  'choose_store': ContentKeys.krogerChooseStore,
  'connection_busy': ContentKeys.krogerConnectionBusy,
  'draft_conflict': ContentKeys.krogerDraftConflict,
  'invalid_items': ContentKeys.krogerInvalidItems,
  'invalid_oauth_state': ContentKeys.krogerInvalidOauthState,
  'invalid_zip': ContentKeys.krogerInvalidZip,
  'kroger_unavailable': ContentKeys.krogerUpstreamUnavailable,
  'local_save_failed': ContentKeys.krogerLocalSaveFailed,
  'mobile_only': ContentKeys.krogerMobileOnly,
  'no_products': ContentKeys.krogerNoProducts,
  'not_configured': ContentKeys.krogerNotConfigured,
  'plan_not_found': ContentKeys.krogerPlanNotFound,
  'pro_required': ContentKeys.krogerProRequired,
  'product_unavailable': ContentKeys.krogerProductUnavailable,
  'products_changed': ContentKeys.krogerProductsChanged,
  'rate_limited': ContentKeys.krogerRateLimited,
  'reconnect_required': ContentKeys.krogerReconnectRequired,
  'redirect_mismatch': ContentKeys.krogerRedirectMismatch,
  'review_matches': ContentKeys.krogerReviewMatches,
  'review_required': ContentKeys.krogerReviewRequired,
  'session_changed': ContentKeys.krogerSessionChanged,
  'storage_unavailable': ContentKeys.krogerStorageUnavailable,
  'unavailable': ContentKeys.krogerUnavailable,
};

/// The content key explaining [code], or null when this app has nothing
/// specific to say about it.
String? krogerMessageKey(String code) => _messageKeys[code];
