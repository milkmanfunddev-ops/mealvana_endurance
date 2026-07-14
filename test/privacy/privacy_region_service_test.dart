import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This service is the only thing in the consent stack that touches the
/// network, and every downstream reader is synchronous — so its job is to fill
/// a cache and, above all, to never throw and never lie.
///
/// A failure here does not merely lose analytics: `RegionSource` decides
/// whether a user is silently opted in, so a service that reports `geo` when it
/// actually guessed would opt in EU users without asking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  PrivacyRegionService serviceWith(
    SharedPreferences prefs,
    http.Client client,
  ) =>
      PrivacyRegionService(prefs: prefs, client: client);

  group('successful lookup', () {
    test('caches country + region and marks the source authoritative',
        () async {
      final prefs = await prefsWith({});
      final client = MockClient(
        (_) async => http.Response('{"country":"US","region":"WA"}', 200),
      );

      await serviceWith(prefs, client).ensureResolved();

      expect(prefs.getString(kGeoCountryKey), 'US');
      expect(prefs.getString(kGeoRegionKey), 'WA');
      expect(prefs.getString(kRegionSourceKey), 'geo');
      expect(
        PrivacyRegion.resolveWithPrefs(prefs).source,
        RegionSource.geo,
      );
    });

    // A US answer with no subdivision must not leave a previously-cached "WA"
    // sitting there, or a user who moved would keep being treated as strict on
    // stale data.
    test('a null region clears a previously cached subdivision', () async {
      final prefs = await prefsWith({
        kRegionSourceKey: 'geo',
        kGeoCountryKey: 'US',
        kGeoRegionKey: 'WA',
      });
      final client = MockClient(
        (_) async => http.Response('{"country":"US","region":null}', 200),
      );

      // Warm cache refreshes in the background — await it directly.
      await serviceWith(prefs, client).ensureResolved();
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString(kGeoRegionKey), isNull);
    });
  });

  group('failure degrades to the device fallback, never to a throw', () {
    for (final (name, client) in <(String, http.Client)>[
      (
        'non-200',
        MockClient((_) async => http.Response('nope', 500)),
      ),
      (
        'malformed body',
        MockClient((_) async => http.Response('not json', 200)),
      ),
      (
        'empty country',
        MockClient((_) async => http.Response('{"country":null}', 200)),
      ),
      (
        'socket error',
        MockClient((_) async => throw http.ClientException('offline')),
      ),
    ]) {
      test(name, () async {
        final prefs = await prefsWith({});

        // Must not throw — a failure here cannot be allowed to take down
        // startup, which awaits this.
        await serviceWith(prefs, client).ensureResolved();

        expect(prefs.getString(kRegionSourceKey), 'device');
        expect(prefs.getString(kGeoCountryKey), isNull);
        expect(
          PrivacyRegion.resolveWithPrefs(prefs).source,
          RegionSource.device,
          reason: 'device signals may present a question, never skip one',
        );
      });
    }

    test('a timeout is a failure, not a hang', () async {
      final prefs = await prefsWith({});
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return http.Response('{"country":"US"}', 200);
      });

      await serviceWith(prefs, client)
          .ensureResolved(timeout: const Duration(milliseconds: 50));

      expect(prefs.getString(kRegionSourceKey), 'device');
    });

    // The important one. A user who resolved to DE last week and opens the app
    // on a plane must stay DE — clobbering a good answer with a device guess
    // would flip them out of `strict` and silently opt them in.
    test('a failed refresh never clobbers a good cached geo answer', () async {
      final prefs = await prefsWith({
        kRegionSourceKey: 'geo',
        kGeoCountryKey: 'DE',
      });
      final client = MockClient(
        (_) async => throw http.ClientException('offline'),
      );

      await serviceWith(prefs, client).ensureResolved();
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString(kRegionSourceKey), 'geo');
      expect(prefs.getString(kGeoCountryKey), 'DE');
      expect(
        PrivacyRegion.resolveWithPrefs(prefs).regime,
        ConsentRegime.strict,
      );
    });
  });

  test('a warm cache does not block startup on the network', () async {
    final prefs = await prefsWith({
      kRegionSourceKey: 'geo',
      kGeoCountryKey: 'US',
      kGeoRegionKey: 'CA',
    });
    // Never completes. If ensureResolved awaited it, this test would time out.
    final client = MockClient((_) async => Completer<http.Response>().future);

    await serviceWith(prefs, client)
        .ensureResolved()
        .timeout(const Duration(seconds: 1));

    expect(prefs.getString(kGeoCountryKey), 'US');
  });
}
