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
  });
}
