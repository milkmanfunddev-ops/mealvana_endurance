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

  /// Google Play services failed inside the Google Sign-In flow
  /// (`ApiException` status 8, `INTERNAL_ERROR`). Not a client
  /// misconfiguration: that is status 10, `DEVELOPER_ERROR`, which stays a
  /// Fault.
  playServicesTransient('play_services_transient'),

  /// A control-flow signal, not a failure: the account exists but its email
  /// address is not verified yet, so the athlete is sent to the code screen.
  verificationPending('verification_pending'),

  /// The email or provider identity already belongs to an account; the UI
  /// offers to sign in to it instead.
  accountExists('account_exists'),

  /// GoTrue refused a resend inside its cooldown (the athlete tapped Resend
  /// again too soon).
  rateLimited('rate_limited'),
  debugAssertion('debug_assertion'),
  webDomTeardown('web_dom_teardown'),

  /// The SDK reported an HTTP failure whose caller already substitutes a
  /// fallback (today: the weather forecast). Not offline; handled.
  handledFallback('handled_fallback'),

  /// An edge function answered 502 because ITS upstream failed (Garmin's
  /// backfill API for `garmin-backfill`, Kroger for `kroger`) and said so;
  /// the caller already degrades. Ticket 19.
  upstreamUnavailable('upstream_unavailable'),

  /// A gateway between the app and Supabase answered 504: Supabase's own
  /// gateway during a platform blip or row-lock pile-up, or a network
  /// middlebox on the athlete's side that never reached Supabase at all.
  /// Never the app's code. Ticket 19.
  gatewayTimeout('gateway_timeout');

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
  // 2026-10-06 (MEALVANA-ENDURANCE-CX, CW): Android's ECONNABORTED. The OS
  // dropped the socket mid-request (network switch, app backgrounded) during
  // a token refresh; supabase retries the refresh on the next tick.
  MapEntry('Software caused connection abort', ExpectedFailure.connectionReset),
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
  // 2026-10-06 (DEV-95, DEV-9P): a mistyped or expired 6-digit code, from the
  // email-verify and password-reset screens. The screen says so and offers
  // Resend.
  MapEntry(
    'InvalidVerificationCodeException',
    ExpectedFailure.invalidCredentials,
  ),
  MapEntry('otp_expired', ExpectedFailure.invalidCredentials),
  // --- Control-flow signals from the auth flows (the UI routes on them) ---
  // 2026-10-06 (DEV-8R, DEV-9N): signup or login before the email code was
  // entered. The controller logs it as info, but the Riverpod net still
  // reports the AsyncError it routes on, so the type has to be listed here.
  MapEntry(
    'EmailVerificationRequiredException',
    ExpectedFailure.verificationPending,
  ),
  MapEntry('email_not_confirmed', ExpectedFailure.verificationPending),
  // 2026-10-06 (DEV-8D): the address or provider is already registered; the
  // signup screen offers "sign in instead".
  MapEntry('AccountAlreadyExistsException', ExpectedFailure.accountExists),
  MapEntry('User already registered', ExpectedFailure.accountExists),
  // 2026-10-06 (DEV-9Q): "you can only request this after N seconds".
  MapEntry('over_email_send_rate_limit', ExpectedFailure.rateLimited),
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

/// Expected failures whose message has a part that changes per build, so a
/// plain needle cannot match it. Checked after [expectedFailureNeedles].
final List<MapEntry<RegExp, ExpectedFailure>>
expectedFailurePatterns = <MapEntry<RegExp, ExpectedFailure>>[
  // 2026-10-06 (MEALVANA-ENDURANCE-CF): google_sign_in on Android reports
  // `PlatformException(sign_in_failed, <ApiException>: <status>: ...)`.
  // R8 renames the ApiException class per build (`K3.a` in 1.28.0+146),
  // so the class is matched loosely and the status code exactly.
  // Status 7 is NETWORK_ERROR. Status 8 is INTERNAL_ERROR: on CF the same
  // device signed in with Google 48 s later, so it is transient. Status
  // 10 (DEVELOPER_ERROR, a SHA-1 / OAuth client mismatch) and 12500 are
  // real misconfigurations and stay Faults.
  MapEntry(RegExp(r'sign_in_failed, [\w.$]+: 7: '), ExpectedFailure.offline),
  MapEntry(
    RegExp(r'sign_in_failed, [\w.$]+: 8: '),
    ExpectedFailure.playServicesTransient,
  ),
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
  for (final entry in expectedFailurePatterns) {
    if (entry.key.hasMatch(text)) return entry.value;
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
