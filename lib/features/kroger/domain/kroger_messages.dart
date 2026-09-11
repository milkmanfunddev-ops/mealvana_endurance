import '../../content/domain/content_keys.dart';

/// Message codes carried by `KrogerState.message` — raised by the edge
/// function as `error`/`reason`, by `KrogerException`, or set by the
/// controller — mapped to the content key that explains them to the shopper.
///
/// Every code the server can return has an entry; a test reads them out of
/// the function's source. Codes that describe a request this app built wrong
/// (`invalid_body`, `invalid_action` from a function out of step with the app,
/// and their kin) share [ContentKeys.krogerUnexpected]: there is nothing a
/// shopper can do differently about any of them, and Kroger is not the cause.
/// Only `kroger_unavailable` and `unavailable` (a request that never got an
/// answer, or a hand-off no app would open) say Kroger could not be reached.
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
  'no_delivery_area': ContentKeys.krogerNoDeliveryArea,
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
  'unauthenticated': ContentKeys.krogerSignedOut,
  'unavailable': ContentKeys.krogerUnavailable,
  'unexpected': ContentKeys.krogerUnexpected,
  // Mealvana's own mistakes, never Kroger's.
  'export_unknown': ContentKeys.krogerUnexpected,
  'internal_error': ContentKeys.krogerUnexpected,
  'invalid_action': ContentKeys.krogerUnexpected,
  'invalid_body': ContentKeys.krogerUnexpected,
  'invalid_id': ContentKeys.krogerUnexpected,
  'invalid_input': ContentKeys.krogerUnexpected,
  'invalid_modality': ContentKeys.krogerUnexpected,
  'invalid_token_response': ContentKeys.krogerUnexpected,
  'method_not_allowed': ContentKeys.krogerUnexpected,
};

/// The content key explaining [code], or null for a code this app has never
/// heard of; callers fall back to [ContentKeys.krogerUnexpected].
String? krogerMessageKey(String code) => _messageKeys[code];
