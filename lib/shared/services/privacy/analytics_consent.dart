import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs_provider.dart';
import 'privacy_region.dart';

const _statusKey = 'analytics_consent_status';
const _regimeKey = 'analytics_consent_regime';
const _timestampKey = 'analytics_consent_at';
const _versionKey = 'analytics_consent_version';

/// Bump to re-prompt every user — e.g. when the disclosure text changes
/// materially, or when a new processor/data type is added. A stored decision
/// taken against an older version is treated as [ConsentStatus.unknown].
const kConsentVersion = 1;

/// The user's analytics decision.
enum ConsentStatus {
  /// Never asked (new install), or asked against an older [kConsentVersion].
  /// Analytics MUST NOT run in this state.
  unknown,
  granted,
  denied;

  /// The only state in which analytics may run.
  ///
  /// Note this is `granted` in BOTH regimes. The regime decides how the choice
  /// is *presented* (toggle pre-set on vs. off), not whether a choice is
  /// needed: Apple Guideline 5.1.1(ii) requires consent for usage data "even if
  /// such data is considered to be anonymous", with no regional carve-out.
  bool get allowsAnalytics => this == ConsentStatus.granted;
}

class AnalyticsConsent {
  const AnalyticsConsent({required this.status, required this.regime});

  final ConsentStatus status;
  final ConsentRegime regime;

  bool get allowsAnalytics => status.allowsAnalytics;

  /// True when we still owe the user the disclosure.
  bool get needsPrompt => status == ConsentStatus.unknown;
}

/// Persisted analytics consent — the single gate for Mixpanel and for Sentry
/// session replay.
///
/// Applies to every user, signed-in or anonymous. Account status does not
/// change the obligation: under GDPR a registered user's analytics is *more*
/// clearly personal data, and MHMDA explicitly forbids treating acceptance of
/// the ToS as consent. What it does NOT gate is first-party processing needed
/// to deliver the service the user asked for (their profile, activities and
/// meal logs in Supabase) — that runs on contract performance, not consent.
final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>(
  AnalyticsConsentNotifier.new,
);

class AnalyticsConsentNotifier extends Notifier<AnalyticsConsent> {
  @override
  AnalyticsConsent build() {
    final prefs = ref.read(sharedPreferencesProvider);

    // A decision recorded against an older disclosure is not consent to the
    // current one — re-prompt instead of assuming it carries forward.
    final storedVersion = prefs.getInt(_versionKey) ?? 0;
    final stored =
        storedVersion == kConsentVersion ? prefs.getString(_statusKey) : null;

    final status = switch (stored) {
      'granted' => ConsentStatus.granted,
      'denied' => ConsentStatus.denied,
      _ => ConsentStatus.unknown,
    };

    // Re-resolve the regime on every launch rather than trusting the stored
    // one: a user who moves into the EEA should be governed by the stricter
    // rules from then on. The stored value is kept only as an audit record of
    // what we showed them at the time.
    return AnalyticsConsent(status: status, regime: PrivacyRegion.resolve());
  }

  /// Record the user's decision. [granted] false is a valid, final answer — and
  /// is also how withdrawal works (Apple requires an accessible way to withdraw
  /// consent, so this is callable at any time from Settings).
  Future<void> record({required bool granted}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final regime = state.regime;

    await prefs.setString(_statusKey, granted ? 'granted' : 'denied');
    await prefs.setString(_regimeKey, regime.name);
    await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
    await prefs.setInt(_versionKey, kConsentVersion);

    state = AnalyticsConsent(
      status: granted ? ConsentStatus.granted : ConsentStatus.denied,
      regime: regime,
    );
  }
}

/// Reads the stored consent directly from SharedPreferences, for the one caller
/// that runs before the Riverpod container exists: `main()`, which must decide
/// whether to arm Sentry session replay at `SentryFlutter.init` time.
///
/// Fails closed — anything other than a current-version "granted" means no.
bool analyticsConsentGrantedFromPrefs(SharedPreferences prefs) {
  if ((prefs.getInt(_versionKey) ?? 0) != kConsentVersion) return false;
  return prefs.getString(_statusKey) == 'granted';
}
