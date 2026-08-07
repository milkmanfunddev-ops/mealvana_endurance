// Unit tests for the integration-profile value used to pre-fill onboarding.
//
// The name splitting and gender parsing are small, but they are the parts
// that write a stranger's data into someone's personal details, so the
// edge cases are pinned here rather than left to the widget layer.

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_integration_profile.dart';

void main() {
  group('splitFullName', () {
    test('splits a normal two-part name', () {
      final name = OnboardingIntegrationProfile.splitFullName('Lee Martin');
      expect(name.first, 'Lee');
      expect(name.last, 'Martin');
    });

    test('keeps multi-word given names together, last token is the surname', () {
      final name = OnboardingIntegrationProfile.splitFullName(
        'Mary Anne Van Dyke',
      );
      expect(name.first, 'Mary Anne Van');
      expect(name.last, 'Dyke');
    });

    test('a single-word name has no surname', () {
      final name = OnboardingIntegrationProfile.splitFullName('Xuan');
      expect(name.first, 'Xuan');
      expect(name.last, isNull);
    });

    test('null, empty and whitespace produce nothing', () {
      for (final input in [null, '', '   ']) {
        final name = OnboardingIntegrationProfile.splitFullName(input);
        expect(name.first, isNull, reason: 'input: "$input"');
        expect(name.last, isNull, reason: 'input: "$input"');
      }
    });

    test('collapses irregular whitespace instead of making empty parts', () {
      final name = OnboardingIntegrationProfile.splitFullName(
        '  Lee   Martin  ',
      );
      expect(name.first, 'Lee');
      expect(name.last, 'Martin');
    });
  });

  group('parseGender', () {
    test('maps the codes TrainingPeaks actually sends', () {
      expect(OnboardingIntegrationProfile.parseGender('m'), Gender.male);
      expect(OnboardingIntegrationProfile.parseGender('f'), Gender.female);
      expect(OnboardingIntegrationProfile.parseGender('M'), Gender.male);
      expect(OnboardingIntegrationProfile.parseGender('Female'), Gender.female);
    });

    test('unknown values yield null rather than Gender.other', () {
      // Gender.other is a real answer someone may choose for themselves;
      // an unparseable provider value must not be silently recorded as it.
      for (final input in [null, '', ' ', 'x', 'unspecified', 'nonbinary']) {
        expect(
          OnboardingIntegrationProfile.parseGender(input),
          isNull,
          reason: 'input: "$input"',
        );
      }
    });
  });

  test('hasAnything is false only for a genuinely empty profile', () {
    expect(OnboardingIntegrationProfile.empty.hasAnything, isFalse);
    expect(
      const OnboardingIntegrationProfile(weightLbs: 161).hasAnything,
      isTrue,
    );
    expect(
      const OnboardingIntegrationProfile(firstName: 'Lee').hasAnything,
      isTrue,
    );
    // Source labels alone are not data worth pre-filling from.
    expect(
      const OnboardingIntegrationProfile(detailsSource: 'Garmin Connect')
          .hasAnything,
      isFalse,
    );
  });
}
