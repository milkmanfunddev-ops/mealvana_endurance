import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:mealvana_endurance/shared/services/privacy/analytics_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The gate: no analytics tracker may be handed out — meaning `Mixpanel.init`
/// is never reached — unless consent is explicitly on file.
///
/// Apple 5.1.1(ii) requires consent for usage data "even if such data is
/// considered to be anonymous", so `unknown` must fail closed. A regression
/// here is an App Store rejection and a GDPR/MHMDA exposure, not a bug.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A resolved geo answer, as `PrivacyRegionService` would have cached it.
  ///
  /// Tests that omit this get `RegionSource.none` and therefore fail closed —
  /// which is also what keeps this suite deterministic. Without the geo guard
  /// the regime would fall back to device signals, i.e. to the timezone of
  /// whichever machine happens to be running the tests, and these assertions
  /// would pass in Denver and fail in Seattle.
  Map<String, Object> geo(String country, String? region) => {
        'privacy_region_source': 'geo',
        'privacy_geo_country': country,
        if (region != null) 'privacy_geo_region': region,
      };

  Future<ProviderContainer> containerWith(
    Map<String, Object> prefsValues,
  ) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // A prod-shaped config, so dev-mode isn't what's doing the suppressing
        // and we're genuinely exercising the consent gate.
        appConfigProvider.overrideWithValue(
          AppConfig.forTesting(devModeEnabled: false),
        ),
      ],
    );
  }

  group('analyticsTrackerProvider consent gate', () {
    test('no decision on file → Noop (nothing initializes, nothing sends)',
        () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      expect(
        container.read(analyticsConsentProvider).status,
        ConsentStatus.unknown,
      );
      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    test('explicitly denied → Noop', () async {
      final container = await containerWith({
        'analytics_consent_status': 'denied',
        'analytics_consent_version': kConsentVersion,
      });
      addTearDown(container.dispose);

      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    test('granted → real Mixpanel tracker', () async {
      final container = await containerWith({
        'analytics_consent_status': 'granted',
        'analytics_consent_version': kConsentVersion,
      });
      addTearDown(container.dispose);

      expect(
        container.read(analyticsTrackerProvider),
        isA<MixpanelAnalyticsTracker>(),
      );
    });

    test(
      'consent recorded against an older disclosure does not carry forward',
      () async {
        final container = await containerWith({
          'analytics_consent_status': 'granted',
          'analytics_consent_version': kConsentVersion - 1,
        });
        addTearDown(container.dispose);

        // Must re-prompt rather than assume the old yes covers new collection.
        expect(
          container.read(analyticsConsentProvider).status,
          ConsentStatus.unknown,
        );
        expect(
          container.read(analyticsTrackerProvider),
          isA<NoopAnalyticsTracker>(),
        );
      },
    );

    test('withdrawal takes effect immediately (Apple requires withdraw)',
        () async {
      final container = await containerWith({
        'analytics_consent_status': 'granted',
        'analytics_consent_version': kConsentVersion,
      });
      addTearDown(container.dispose);

      expect(
        container.read(analyticsTrackerProvider),
        isA<MixpanelAnalyticsTracker>(),
      );

      await container
          .read(analyticsConsentProvider.notifier)
          .record(granted: false);

      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    test('the hidden tester exclusion still suppresses, even with consent',
        () async {
      final container = await containerWith({
        'analytics_consent_status': 'granted',
        'analytics_consent_version': kConsentVersion,
        'analytics_excluded': true,
      });
      addTearDown(container.dispose);

      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });
  });

  group('analyticsConsentGrantedFromPrefs (the main() / Sentry-replay path)',
      () {
    test('fails closed with no decision', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(analyticsConsentGrantedFromPrefs(prefs), isFalse);
    });

    test('fails closed on a stale consent version', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_consent_status': 'granted',
        'analytics_consent_version': kConsentVersion - 1,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(analyticsConsentGrantedFromPrefs(prefs), isFalse);
    });

    test('true only on a current-version grant', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_consent_status': 'granted',
        'analytics_consent_version': kConsentVersion,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(analyticsConsentGrantedFromPrefs(prefs), isTrue);
    });

    test('an implied grant arms Sentry replay (geo, non-strict, no decision)',
        () async {
      SharedPreferences.setMockInitialValues(geo('US', 'CA'));
      final prefs = await SharedPreferences.getInstance();
      expect(analyticsConsentGrantedFromPrefs(prefs), isTrue);
    });

    test('no implied grant in a strict region', () async {
      SharedPreferences.setMockInitialValues(geo('DE', null));
      final prefs = await SharedPreferences.getInstance();
      expect(analyticsConsentGrantedFromPrefs(prefs), isFalse);
    });

    test('a denial outranks the implied grant', () async {
      SharedPreferences.setMockInitialValues({
        ...geo('US', 'CA'),
        'analytics_consent_status': 'denied',
        'analytics_consent_version': kConsentVersion,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(analyticsConsentGrantedFromPrefs(prefs), isFalse);
    });
  });

  /// Outside the EEA/UK and Washington we no longer show a consent screen at
  /// all: disclosure (the privacy policy) plus an accessible opt-out (Settings
  /// → Privacy) is the standard those jurisdictions actually set. Analytics
  /// therefore defaults ON — but only under conditions that are load-bearing,
  /// and each of them is pinned below.
  group('implied grant outside strict regimes', () {
    test('known non-strict location, no decision → analytics runs, no prompt',
        () async {
      final container = await containerWith(geo('US', 'CA'));
      addTearDown(container.dispose);

      final consent = container.read(analyticsConsentProvider);
      expect(consent.status, ConsentStatus.unknown);
      expect(consent.allowsAnalytics, isTrue);
      expect(consent.needsPrompt, isFalse, reason: 'no screen outside strict');
      expect(
        container.read(analyticsTrackerProvider),
        isA<MixpanelAnalyticsTracker>(),
      );
    });

    // THE ONE THAT MATTERS. An implied grant must never resurrect analytics for
    // somebody who explicitly turned it off in Settings. If this ever goes red,
    // the app is re-enabling tracking for users who opted out.
    test('an explicit denial is sticky and is NEVER auto-granted', () async {
      final container = await containerWith({
        ...geo('US', 'CA'),
        'analytics_consent_status': 'denied',
        'analytics_consent_version': kConsentVersion,
      });
      addTearDown(container.dispose);

      final consent = container.read(analyticsConsentProvider);
      expect(consent.status, ConsentStatus.denied);
      expect(consent.allowsAnalytics, isFalse);
      expect(consent.needsPrompt, isFalse);
      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    // A version bump discards a stale GRANT (they agreed to older wording), but
    // must not discard a DENIAL — that would reset them to `unknown`, and
    // `unknown` + non-strict is an implied grant. A one-line bump would then
    // silently re-enable analytics for everyone who had opted out.
    test('a denial survives a consent-version bump', () async {
      final container = await containerWith({
        ...geo('US', 'CA'),
        'analytics_consent_status': 'denied',
        'analytics_consent_version': kConsentVersion - 1,
      });
      addTearDown(container.dispose);

      final consent = container.read(analyticsConsentProvider);
      expect(consent.status, ConsentStatus.denied);
      expect(consent.allowsAnalytics, isFalse);
    });

    test('Washington is strict → prompt, and nothing runs until answered',
        () async {
      final container = await containerWith(geo('US', 'WA'));
      addTearDown(container.dispose);

      final consent = container.read(analyticsConsentProvider);
      expect(consent.needsPrompt, isTrue);
      expect(consent.allowsAnalytics, isFalse);
      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    test('EEA is strict → prompt', () async {
      final container = await containerWith(geo('DE', null));
      addTearDown(container.dispose);

      expect(container.read(analyticsConsentProvider).needsPrompt, isTrue);
      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    // The guard that makes the implied grant safe. A device-signal regime is a
    // guess — a German in Berlin with an `en_US` phone resolves to `US` — so it
    // may decide how to PRESENT a question, never whether to ASK one. Until we
    // have a real geo answer we run nothing and prompt nobody, and try again on
    // the next launch.
    test('device-signal fallback never backs an implied grant', () async {
      final container = await containerWith({
        'privacy_region_source': 'device',
      });
      addTearDown(container.dispose);

      final consent = container.read(analyticsConsentProvider);
      expect(consent.allowsAnalytics, isFalse);
      expect(
        container.read(analyticsTrackerProvider),
        isA<NoopAnalyticsTracker>(),
      );
    });

    test('cold cache (region never resolved) fails closed', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      expect(container.read(analyticsConsentProvider).allowsAnalytics, isFalse);
    });
  });
}
