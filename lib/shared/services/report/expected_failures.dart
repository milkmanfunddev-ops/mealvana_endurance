/// The expected-failure allow-list (glossary: CONTEXT.md § Error reporting,
/// "Expected failure").
///
/// One list of exception types and message patterns that `Report` downgrades
/// from Fault to Degraded on its own, so no call site has to remember what is
/// noise. These used to be the `isSentryNoise` *drop* list; since 2026-10-05
/// they arrive as warnings instead, so Lee can count how often athletes are
/// offline or failing login. Only test-only patterns are dropped outright.
///
/// Each entry carries the originating audit or issue id where one exists.
library;

/// Why a failure is expected. The value is the `expected_failure` tag on the
/// downgraded event, so it must stay stable once it has landed in Sentry.
enum ExpectedFailure {
  offline('offline'),
  timeout('timeout'),
  handshake('handshake'),
  connectionReset('connection_reset'),
  cancelledSignIn('cancelled_sign_in'),
  invalidCredentials('invalid_credentials'),
  expiredSession('expired_session'),
  cancelledPurchase('cancelled_purchase'),
  accountNotFound('account_not_found'),
  storeNetwork('store_network'),
  debugAssertion('debug_assertion'),
  webDomTeardown('web_dom_teardown'),

  /// The SDK reported an HTTP failure whose caller already substitutes a
  /// fallback (today: the weather forecast). Not offline; handled.
  handledFallback('handled_fallback');

  const ExpectedFailure(this.tag);

  final String tag;
}

/// Message patterns that mean an expected failure. Order matters only where two
/// needles could both match; the first wins.
const List<MapEntry<String, ExpectedFailure>>
expectedFailureNeedles = <MapEntry<String, ExpectedFailure>>[
  // --- Offline / DNS lookup failures (device has no connectivity) ---
  MapEntry('Failed host lookup', ExpectedFailure.offline),
  MapEntry('nodename nor servname provided', ExpectedFailure.offline),
  MapEntry('errno = 8', ExpectedFailure.offline),
  MapEntry('SocketException', ExpectedFailure.offline),
  MapEntry('Network is unreachable', ExpectedFailure.offline),
  // --- Transient TLS / connection resets (not actionable) ---
  MapEntry('HandshakeException', ExpectedFailure.handshake),
  MapEntry('Connection terminated during handshake', ExpectedFailure.handshake),
  MapEntry(
    'Connection closed before full header',
    ExpectedFailure.connectionReset,
  ),
  // 2026-07-11 audit (DEV-5N): HttpException during response-body
  // streaming phrases the same drop as "while receiving data".
  MapEntry(
    'Connection closed while receiving data',
    ExpectedFailure.connectionReset,
  ),
  // 2026-07-11 audit (DEV-5M, DEV-5B): the OS tears the socket down when
  // the app is backgrounded mid-request.
  MapEntry('Bad file descriptor', ExpectedFailure.connectionReset),
  MapEntry('Connection reset by peer', ExpectedFailure.connectionReset),
  // --- Timeouts ---
  MapEntry('TimeoutException', ExpectedFailure.timeout),
  // 2026-07-11 audit (DEV-4W): `http.ClientException` wraps a plain
  // `Future.timeout()` as "Operation timed out".
  MapEntry('Operation timed out', ExpectedFailure.timeout),
  // --- User-cancelled sign-in (expected user action) ---
  MapEntry('Sign-In was cancelled', ExpectedFailure.cancelledSignIn),
  MapEntry('Sign-In cancelled', ExpectedFailure.cancelledSignIn),
  MapEntry('sign_in_canceled', ExpectedFailure.cancelledSignIn),
  MapEntry(
    'SignInWithAppleAuthorizationException',
    ExpectedFailure.cancelledSignIn,
  ),
  MapEntry('AuthorizationErrorCode.canceled', ExpectedFailure.cancelledSignIn),
  MapEntry('AuthorizationErrorCode.unknown', ExpectedFailure.cancelledSignIn),
  // --- User input errors ---
  // 2026-07-11 audit (DEV-5Q): mistyped password on manual login,
  // Supabase `AuthApiException(code: invalid_credentials)`.
  MapEntry('Invalid login credentials', ExpectedFailure.invalidCredentials),
  MapEntry('invalid_credentials', ExpectedFailure.invalidCredentials),
  // --- Expired session (refresh token gone; the athlete signs in again) ---
  MapEntry('refresh_token_not_found', ExpectedFailure.expiredSession),
  MapEntry('Invalid Refresh Token', ExpectedFailure.expiredSession),
  MapEntry('JWT expired', ExpectedFailure.expiredSession),
  MapEntry('session_expired', ExpectedFailure.expiredSession),
  // --- Sign-in with a provider account that has no Mealvana account ---
  MapEntry('OAuthAccountNotFoundException', ExpectedFailure.accountNotFound),
  // --- RevenueCat / StoreKit: cancelled purchase, store unreachable ---
  // Qualified enum names so a bare "networkError" elsewhere is not swept up;
  // the upper-case forms are the PlatformException codes.
  MapEntry(
    'PurchasesErrorCode.purchaseCancelledError',
    ExpectedFailure.cancelledPurchase,
  ),
  MapEntry('PURCHASE_CANCELLED', ExpectedFailure.cancelledPurchase),
  MapEntry('PurchasesErrorCode.networkError', ExpectedFailure.storeNetwork),
  MapEntry('NETWORK_ERROR', ExpectedFailure.storeNetwork),
  // --- Debug-only Flutter assertions (never fire in release builds) ---
  MapEntry('ink splashes may be invisible', ExpectedFailure.debugAssertion),
  // --- Benign Flutter-web engine DOM teardown races ---
  MapEntry("reading 'removeChild'", ExpectedFailure.webDomTeardown),
  MapEntry("reading 'insertBefore'", ExpectedFailure.webDomTeardown),
];

/// Patterns that only the test runner produces. These never reach Sentry.
const List<String> testOnlyNeedles = <String>[
  'TestFailure',
  'matching candidate',
  'could not find any matching widgets',
  'Required widget not found',
];

/// Classifies [text] (an exception's `toString()`, type name and message
/// joined) as an expected failure, or `null` when it is a real Fault.
ExpectedFailure? classifyExpectedFailure(String text) {
  if (text.isEmpty) return null;
  for (final entry in expectedFailureNeedles) {
    if (text.contains(entry.key)) return entry.value;
  }
  return null;
}

/// `true` when [text] came from the test runner and must be dropped.
bool isTestOnlyFailure(String text) {
  if (text.isEmpty) return false;
  for (final needle in testOnlyNeedles) {
    if (text.contains(needle)) return true;
  }
  return false;
}

/// The text `Report` and the `beforeSend` filter both classify on: the
/// runtime type and `toString()` of [error].
String describeThrowable(Object error) =>
    '${error.runtimeType} ${error.toString()}';
