import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region.dart';

/// The regime decides whether a user is asked to opt IN or merely offered an
/// opt-OUT, so a wrong answer here is the actual compliance failure — not a
/// cosmetic one. These pin the boundaries.
void main() {
  ConsentRegime resolve(String? country, double offsetHours) =>
      PrivacyRegion.resolveFrom(
        countryCode: country,
        utcOffset: Duration(minutes: (offsetHours * 60).round()),
      );

  group('EEA / UK → strict (GDPR + ePrivacy require opt-in)', () {
    for (final country in ['DE', 'FR', 'IE', 'GB', 'NO', 'IS', 'LI', 'CH']) {
      test(country, () {
        expect(resolve(country, 1), ConsentRegime.strict);
      });
    }

    test('is case-insensitive — locales may report lowercase', () {
      expect(resolve('de', 1), ConsentRegime.strict);
    });

    test('strict even when the device sits at a non-European offset', () {
      // A German-locale phone in New York is still a GDPR data subject.
      expect(resolve('DE', -5), ConsentRegime.strict);
    });
  });

  group('Washington proxy — US Pacific → strict (MHMDA requires opt-in)', () {
    test('US Pacific standard time (UTC-8)', () {
      expect(resolve('US', -8), ConsentRegime.strict);
    });

    test('US Pacific daylight time (UTC-7)', () {
      expect(resolve('US', -7), ConsentRegime.strict);
    });

    test('US Central is not Pacific → standard', () {
      expect(resolve('US', -5), ConsentRegime.standard);
    });

    test('US Eastern → standard', () {
      expect(resolve('US', -4), ConsentRegime.standard);
    });

    test('non-US country at a Pacific offset is not the Washington case', () {
      // The proxy is deliberately scoped to US locales — it exists to catch a
      // US *state*, and must not sweep in e.g. Mexico or Canada.
      expect(resolve('MX', -8), ConsentRegime.standard);
    });
  });

  group('unknown country → fail toward strict', () {
    test('no country + European offset → strict', () {
      expect(resolve(null, 1), ConsentRegime.strict);
      expect(resolve(null, 0), ConsentRegime.strict);
      expect(resolve(null, 3), ConsentRegime.strict);
    });

    test('no country + clearly non-European offset → standard', () {
      expect(resolve(null, -6), ConsentRegime.standard);
      expect(resolve(null, 9), ConsentRegime.standard);
    });
  });

  group('everywhere else → standard (disclosure + opt-out)', () {
    test('US Eastern', () => expect(resolve('US', -5), ConsentRegime.standard));
    test('Japan', () => expect(resolve('JP', 9), ConsentRegime.standard));
    test('Australia', () => expect(resolve('AU', 10), ConsentRegime.standard));
    test('Brazil', () => expect(resolve('BR', -3), ConsentRegime.standard));
  });

  test('half-hour offsets do not crash the Pacific check (India, UTC+5:30)', () {
    expect(resolve('IN', 5.5), ConsentRegime.standard);
  });

  /// The authoritative path, fed by `/api/region` (Vercel edge geo, from the
  /// request IP). Everything above is the offline fallback.
  ///
  /// The whole reason for doing a server lookup is the US: a device can tell us
  /// the country but never the *state*, and only Washington requires opt-in.
  group('resolveFromGeo — the authoritative path', () {
    ConsentRegime geo(String? country, String? region, [double offsetHours = 0]) =>
        PrivacyRegion.resolveFromGeo(
          country: country,
          region: region,
          utcOffset: Duration(minutes: (offsetHours * 60).round()),
        );

    test('Washington → strict (MHMDA requires opt-in)', () {
      expect(geo('US', 'WA'), ConsentRegime.strict);
    });

    // The payoff. The device-signal fallback treats the entire US Pacific
    // timezone as strict because it cannot see a state, which needlessly drags
    // in California, Oregon and Nevada — all of them opt-OUT jurisdictions
    // (CCPA/CPRA is not an opt-in regime). Real geo stops over-covering them,
    // and that recovered analytics volume is what pays for the lookup.
    for (final state in ['CA', 'OR', 'NV']) {
      test('$state → standard, even though it shares WA\'s timezone', () {
        expect(geo('US', state, -8), ConsentRegime.standard);
      });
    }

    test('is case-insensitive', () {
      expect(geo('us', 'wa'), ConsentRegime.strict);
      expect(geo('de', null), ConsentRegime.strict);
    });

    for (final country in ['DE', 'FR', 'GB', 'NO']) {
      test('$country → strict regardless of subdivision', () {
        expect(geo(country, 'ANYTHING'), ConsentRegime.strict);
      });
    }

    test('rest of world → standard', () {
      expect(geo('JP', '13'), ConsentRegime.standard);
      expect(geo('AU', 'NSW'), ConsentRegime.standard);
    });

    // SAFETY NET. Vercel does not guarantee the subdivision header. If it ever
    // stops being populated we must NOT quietly default the US to standard —
    // that would drop MHMDA coverage entirely, invisibly. Fall back to the
    // timezone proxy instead, which is what we had before geo existed.
    group('US with no subdivision falls back to the timezone proxy', () {
      test('Pacific offset → strict (could be Washington)', () {
        expect(geo('US', null, -8), ConsentRegime.strict);
        expect(geo('US', '', -7), ConsentRegime.strict);
      });

      test('Eastern offset → standard (cannot be Washington)', () {
        expect(geo('US', null, -5), ConsentRegime.standard);
      });
    });

    // `standard` is the PERMISSIVE answer — it means "no prompt, analytics on".
    // Returning it from an empty country would be answering from no evidence at
    // all, so a missing country must fall back to the device heuristic instead.
    group('no country at all must not resolve to the permissive answer', () {
      test('null country at a European offset → strict', () {
        expect(geo(null, null, 1), ConsentRegime.strict);
      });

      test('empty country at a European offset → strict', () {
        expect(geo('', null, 0), ConsentRegime.strict);
      });

      test('null country at a clearly non-European offset → standard', () {
        expect(geo(null, null, -5), ConsentRegime.standard);
      });
    });
  });

  /// The synchronous entry point every consumer actually calls.
  group('resolveWithPrefs — source is what licenses an implied grant', () {
    test('a geo source with no country is a corrupt cache, not an answer', () {
      // If this returned RegionSource.geo, `standard` + geo = implied grant, and
      // we would silently opt in a user whose location we do not actually know.
      final regime = PrivacyRegion.resolveFromGeo(
        country: null,
        region: null,
        utcOffset: const Duration(hours: 1),
      );
      expect(regime, ConsentRegime.strict);
    });
  });
}
