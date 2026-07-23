import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs_provider.dart';
import 'privacy_region.dart';

const _statusKey = 'analytics_consent_status';
const _regimeKey = 'analytics_consent_regime';
const _timestampKey = 'analytics_consent_at';
const _versionKey = 'analytics_consent_version';

/// Bump to re-prompt users whose consent was given against an older disclosure
/// — e.g. when a new processor or data type is added.
///
/// A bump invalidates a GRANT (they agreed to something we no longer do). It
/// deliberately does NOT invalidate a DENIAL: see [resolveConsentFromPrefs].
/// Shortening or rewording the copy without changing what we collect is not a
/// reason to bump — nothing new is being consented to.
const kConsentVersion = 1;

/// The user's recorded analytics decision.
enum ConsentStatus {
  /// Never asked, or a grant given against an older [kConsentVersion].
  ///
  /// This does NOT by itself mean "no analytics" — outside strict regimes an
  /// unknown status resolves to an implied grant. See
  /// [AnalyticsConsent.allowsAnalytics], which is the only correct place to ask
  /// the question.
  unknown,
  granted,
  denied,
}

/// The resolved consent position: what the user said, where they are, and how
/// much we trust the "where".
class AnalyticsConsent {
  const AnalyticsConsent({
    required this.status,
    required this.regime,
    required this.source,
  });

  final ConsentStatus status;
  final ConsentRegime regime;
  final RegionSource source;

  /// The single gate for Mixpanel and for Sentry session replay.
  ///
  /// Three ways to be allowed to run analytics, and the reasoning for each:
  ///
  /// - An explicit [ConsentStatus.granted]. Always sufficient, everywhere.
  ///
  /// - [ConsentStatus.unknown] in a non-strict region, but ONLY when we know
  ///   where the user is from an authoritative geo lookup
  ///   ([RegionSource.geo]). Outside the EEA/UK and Washington, disclosure plus
  ///   an accessible opt-out is the legal standard — the privacy policy and the
  ///   always-available Settings → Privacy toggle provide both — so these users
  ///   are not interrupted with a screen.
  ///
  /// - Never on [ConsentStatus.denied]. A denial is sticky and outranks
  ///   everything, including a [kConsentVersion] bump.
  ///
  /// The [RegionSource.geo] requirement is load-bearing, not belt-and-braces.
  /// The device-signal fallback resolves a German in Berlin holding an `en_US`
  /// phone to `US` → `standard`, which under an implied-grant rule would
  /// silently opt a GDPR data subject into analytics without ever asking. A
  /// device-derived regime is precise enough to choose how to *present* a
  /// question; it is not precise enough to decide not to *ask* one. So when the
  /// lookup has failed we run no analytics and show no screen, and try again
  /// next launch.
  bool get allowsAnalytics {
    if (status == ConsentStatus.denied) return false;
    if (status == ConsentStatus.granted) return true;
    return !regime.isStrict && source == RegionSource.geo;
  }

  /// True only when we still owe the user an explicit, affirmative choice.
  ///
  /// Strict regimes only — GDPR/ePrivacy and Washington's MHMDA require an
  /// affirmative act, and MHMDA specifically forbids inferring consent from
  /// acceptance of the ToS. Everyone else is covered by disclosure + opt-out
  /// and is never shown the screen.
  bool get needsPrompt => status == ConsentStatus.unknown && regime.isStrict;
}

/// Resolve the full consent position from persisted state.
///
/// The single source of truth, shared by the Riverpod notifier and by the
/// pre-Riverpod reader below, so the two can never drift apart.
AnalyticsConsent resolveConsentFromPrefs(SharedPreferences prefs) {
  final storedStatus = prefs.getString(_statusKey);
  final storedVersion = prefs.getInt(_versionKey) ?? 0;

  // A version bump invalidates a grant — consent to an older disclosure is not
  // consent to the current one. It must NEVER invalidate a denial: discarding a
  // "no" would reset the user to `unknown`, and `unknown` in a non-strict region
  // is an implied grant. That path would silently re-enable analytics for
  // someone who had explicitly opted out, which is exactly the failure this
  // whole gate exists to prevent.
  final status = switch (storedStatus) {
    'denied' => ConsentStatus.denied,
    'granted' when storedVersion == kConsentVersion => ConsentStatus.granted,
    _ => ConsentStatus.unknown,
  };

  // Re-resolve the region on every read rather than trusting the one we stored
  // at decision time: a user who moves into the EEA is governed by the stricter
  // rules from then on. The stored `_regimeKey` is kept only as an audit record
  // of what we showed them at the time.
  final resolved = PrivacyRegion.resolveWithPrefs(prefs);

  return AnalyticsConsent(
    status: status,
    regime: resolved.regime,
    source: resolved.source,
  );
}

/// Persisted analytics consent — the single gate for Mixpanel and for Sentry
/// session replay.
///
/// What it does NOT gate is first-party processing needed to deliver the
/// service the user asked for (their profile, activities and meal logs in
/// Supabase). That runs on contract performance, not consent — which is why
/// product metrics in SQL keep working for 100% of users regardless.
final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>(
      AnalyticsConsentNotifier.new,
    );

class AnalyticsConsentNotifier extends Notifier<AnalyticsConsent> {
  @override
  AnalyticsConsent build() =>
      resolveConsentFromPrefs(ref.read(sharedPreferencesProvider));

  /// Record an explicit decision.
  ///
  /// [granted] false is a valid, final answer — and is also how withdrawal
  /// works. Apple 5.1.1(ii) requires an accessible way to withdraw consent, so
  /// this is callable at any time from Settings → Privacy, by any user in any
  /// region.
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
      source: state.source,
    );
  }
}

/// Reads consent directly from SharedPreferences, for the callers that run
/// before the Riverpod container exists: the four `main*.dart` entrypoints,
/// which must decide whether to arm Sentry session replay at
/// `SentryFlutter.init` time.
///
/// Fails closed. On a cold first launch the geo cache is empty, so
/// [RegionSource.none] means no implied grant and replay stays off — the
/// implied grant only takes effect from the second launch, once we actually
/// know where the user is.
bool analyticsConsentGrantedFromPrefs(SharedPreferences prefs) =>
    resolveConsentFromPrefs(prefs).allowsAnalytics;
