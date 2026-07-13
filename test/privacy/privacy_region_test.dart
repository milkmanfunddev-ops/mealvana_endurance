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
}
