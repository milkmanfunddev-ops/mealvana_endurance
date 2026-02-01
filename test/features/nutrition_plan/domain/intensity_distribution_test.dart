import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/intensity_distribution.dart';

void main() {
  group('IntensityDistribution', () {
    group('constructor', () {
      test('creates valid distribution', () {
        final distribution = IntensityDistribution(
          conversationalPct: 70,
          tempoPct: 20,
          allOutPct: 10,
        );

        expect(distribution.conversationalPct, 70);
        expect(distribution.tempoPct, 20);
        expect(distribution.allOutPct, 10);
      });

      test('throws ArgumentError when sum is not 100', () {
        expect(
          () => IntensityDistribution.validated(
            conversationalPct: 70,
            tempoPct: 20,
            allOutPct: 5,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must sum to 100'),
            ),
          ),
        );
      });

      test('throws ArgumentError for negative percentages', () {
        expect(
          () => IntensityDistribution.validated(
            conversationalPct: -10,
            tempoPct: 60,
            allOutPct: 50,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must be between 0 and 100'),
            ),
          ),
        );
      });

      test('throws ArgumentError for percentages over 100', () {
        expect(
          () => IntensityDistribution.validated(
            conversationalPct: 110,
            tempoPct: 0,
            allOutPct: -10,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must be between 0 and 100'),
            ),
          ),
        );
      });

      test('allows zero percentages if sum is 100', () {
        final distribution = IntensityDistribution(
          conversationalPct: 100,
          tempoPct: 0,
          allOutPct: 0,
        );

        expect(distribution.conversationalPct, 100);
        expect(distribution.tempoPct, 0);
        expect(distribution.allOutPct, 0);
      });
    });

    group('defaultDistribution', () {
      test('creates 70/20/10 distribution', () {
        final distribution = IntensityDistribution.defaultDistribution();

        expect(distribution.conversationalPct, 70);
        expect(distribution.tempoPct, 20);
        expect(distribution.allOutPct, 10);
      });

      test('sum equals 100', () {
        final distribution = IntensityDistribution.defaultDistribution();
        final sum = distribution.conversationalPct +
            distribution.tempoPct +
            distribution.allOutPct;

        expect(sum, 100);
      });
    });

    group('copyWith', () {
      test('copies with valid changes that maintain sum of 100', () {
        final original = IntensityDistribution.defaultDistribution();
        final updated = original.copyWith(
          conversationalPct: 60,
          tempoPct: 30,
        );

        expect(updated.conversationalPct, 60);
        expect(updated.tempoPct, 30);
        expect(updated.allOutPct, 10);
      });

      test('copies with all fields changed to valid sum', () {
        final original = IntensityDistribution.defaultDistribution();
        final updated = original.copyWith(
          conversationalPct: 50,
          tempoPct: 40,
          allOutPct: 10,
        );

        expect(updated.conversationalPct, 50);
        expect(updated.tempoPct, 40);
        expect(updated.allOutPct, 10);
      });

      test('copies with all fields unchanged when no parameters', () {
        final original = IntensityDistribution.defaultDistribution();
        final updated = original.copyWith();

        expect(updated.conversationalPct, original.conversationalPct);
        expect(updated.tempoPct, original.tempoPct);
        expect(updated.allOutPct, original.allOutPct);
      });

      test('throws assertion error when creating invalid sum', () {
        final original = IntensityDistribution.defaultDistribution();

        // copyWith validates through const constructor assertions
        // In debug mode this throws AssertionError
        expect(
          () => original.copyWith(conversationalPct: 50),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('adjustProportionally', () {
      test('adjusts when conversational increases', () {
        // Start: 70/20/10
        final original = IntensityDistribution.defaultDistribution();

        // Increase conversational from 70 to 80
        final adjusted = original.adjustProportionally(conversationalPct: 80);

        // Delta = +10, distributed over tempo (20) and allOut (10)
        // Total remaining = 30
        // tempo -= 10 * (20/30) = 20 - 6.67 ≈ 13
        // allOut -= 10 * (10/30) = 10 - 3.33 ≈ 7
        expect(adjusted.conversationalPct, 80);
        expect(adjusted.tempoPct + adjusted.allOutPct, 20);
        expect(adjusted.conversationalPct + adjusted.tempoPct + adjusted.allOutPct, 100);
      });

      test('adjusts when tempo decreases', () {
        // Start: 70/20/10
        final original = IntensityDistribution.defaultDistribution();

        // Decrease tempo from 20 to 10
        final adjusted = original.adjustProportionally(tempoPct: 10);

        // Delta = -10, distributed over conversational (70) and allOut (10)
        // Total remaining = 80
        // conversational += 10 * (70/80) = 70 + 8.75 ≈ 79
        // allOut += 10 * (10/80) = 10 + 1.25 ≈ 11
        expect(adjusted.tempoPct, 10);
        expect(adjusted.conversationalPct + adjusted.allOutPct, 90);
        expect(adjusted.conversationalPct + adjusted.tempoPct + adjusted.allOutPct, 100);
      });

      test('adjusts when allOut increases to maximum', () {
        final original = IntensityDistribution.defaultDistribution();

        // Increase allOut from 10 to 100
        final adjusted = original.adjustProportionally(allOutPct: 100);

        expect(adjusted.allOutPct, 100);
        expect(adjusted.conversationalPct, 0);
        expect(adjusted.tempoPct, 0);
        expect(adjusted.conversationalPct + adjusted.tempoPct + adjusted.allOutPct, 100);
      });

      test('handles edge case when zone changes to 0', () {
        final original = IntensityDistribution(
          conversationalPct: 50,
          tempoPct: 30,
          allOutPct: 20,
        );

        // Change allOut from 20 to 0
        final adjusted = original.adjustProportionally(allOutPct: 0);

        expect(adjusted.allOutPct, 0);
        expect(adjusted.conversationalPct + adjusted.tempoPct, 100);
        expect(adjusted.conversationalPct + adjusted.tempoPct + adjusted.allOutPct, 100);
      });

      test('handles edge case when only one zone has value', () {
        final original = IntensityDistribution(
          conversationalPct: 100,
          tempoPct: 0,
          allOutPct: 0,
        );

        // Try to reduce conversational from 100 to 80
        final adjusted = original.adjustProportionally(conversationalPct: 80);

        // Freed 20% should be distributed equally to the other two zones (10% each)
        expect(adjusted.conversationalPct, 80);
        expect(adjusted.tempoPct, 10);
        expect(adjusted.allOutPct, 10);
        expect(adjusted.conversationalPct + adjusted.tempoPct + adjusted.allOutPct, 100);
      });

      test('normalizes when sum is not exactly 100', () {
        // Start with a distribution
        final original = IntensityDistribution(
          conversationalPct: 34,
          tempoPct: 33,
          allOutPct: 33,
        );

        // Adjust and verify normalization
        final adjusted = original.adjustProportionally(conversationalPct: 50);

        final sum = adjusted.conversationalPct + adjusted.tempoPct + adjusted.allOutPct;
        expect(sum, 100, reason: 'Sum should be normalized to 100');
      });

      test('clamps negative values to 0', () {
        final original = IntensityDistribution(
          conversationalPct: 90,
          tempoPct: 5,
          allOutPct: 5,
        );

        // Try to increase conversational beyond 100 capacity
        final adjusted = original.adjustProportionally(conversationalPct: 100);

        expect(adjusted.conversationalPct, 100);
        expect(adjusted.tempoPct, 0);
        expect(adjusted.allOutPct, 0);
      });

      test('clamps positive values to 100', () {
        final original = IntensityDistribution.defaultDistribution();

        // Try to set a value above 100 (should clamp to 100)
        final adjusted = original.adjustProportionally(conversationalPct: 150);

        expect(adjusted.conversationalPct, 100);
        expect(adjusted.tempoPct, 0);
        expect(adjusted.allOutPct, 0);
      });

      test('returns unchanged distribution when delta is 0', () {
        final original = IntensityDistribution.defaultDistribution();

        // Set to same value
        final adjusted = original.adjustProportionally(conversationalPct: 70);

        expect(adjusted, original);
      });

      test('throws ArgumentError when no zone provided', () {
        final original = IntensityDistribution.defaultDistribution();

        expect(
          () => original.adjustProportionally(),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('At least one zone must be provided'),
            ),
          ),
        );
      });

      test('maintains proportions when adjusting from equal distribution', () {
        final original = IntensityDistribution(
          conversationalPct: 34,
          tempoPct: 33,
          allOutPct: 33,
        );

        // Increase conversational
        final adjusted = original.adjustProportionally(conversationalPct: 44);

        // Delta = +10, should be distributed equally over tempo and allOut
        expect(adjusted.conversationalPct, 44);
        expect(adjusted.tempoPct, closeTo(28, 1));
        expect(adjusted.allOutPct, closeTo(28, 1));
      });

      test('handles rapid successive adjustments', () {
        var distribution = IntensityDistribution.defaultDistribution();

        // Adjust multiple times
        distribution = distribution.adjustProportionally(conversationalPct: 80);
        distribution = distribution.adjustProportionally(tempoPct: 15);
        distribution = distribution.adjustProportionally(allOutPct: 20);

        final sum = distribution.conversationalPct +
            distribution.tempoPct +
            distribution.allOutPct;

        expect(sum, 100);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final distribution = IntensityDistribution.defaultDistribution();
        final json = distribution.toJson();

        expect(json, {
          'conversationalPct': 70,
          'tempoPct': 20,
          'allOutPct': 10,
        });
      });

      test('serializes custom distribution', () {
        final distribution = IntensityDistribution(
          conversationalPct: 50,
          tempoPct: 30,
          allOutPct: 20,
        );
        final json = distribution.toJson();

        expect(json['conversationalPct'], 50);
        expect(json['tempoPct'], 30);
        expect(json['allOutPct'], 20);
      });
    });

    group('fromJson', () {
      test('deserializes correctly', () {
        final json = {
          'conversationalPct': 70,
          'tempoPct': 20,
          'allOutPct': 10,
        };
        final distribution = IntensityDistribution.fromJson(json);

        expect(distribution.conversationalPct, 70);
        expect(distribution.tempoPct, 20);
        expect(distribution.allOutPct, 10);
      });

      test('round-trip serialization preserves data', () {
        final original = IntensityDistribution(
          conversationalPct: 60,
          tempoPct: 25,
          allOutPct: 15,
        );
        final json = original.toJson();
        final deserialized = IntensityDistribution.fromJson(json);

        expect(deserialized, original);
      });
    });

    group('equality', () {
      test('equal distributions are equal', () {
        final dist1 = IntensityDistribution.defaultDistribution();
        final dist2 = IntensityDistribution.defaultDistribution();

        expect(dist1, dist2);
        expect(dist1.hashCode, dist2.hashCode);
      });

      test('different distributions are not equal', () {
        final dist1 = IntensityDistribution.defaultDistribution();
        final dist2 = IntensityDistribution(
          conversationalPct: 60,
          tempoPct: 30,
          allOutPct: 10,
        );

        expect(dist1, isNot(dist2));
      });

      test('same instance is equal to itself', () {
        final distribution = IntensityDistribution.defaultDistribution();

        expect(distribution, distribution);
      });
    });

    group('toString', () {
      test('provides readable string representation', () {
        final distribution = IntensityDistribution.defaultDistribution();
        final string = distribution.toString();

        expect(string, contains('70%'));
        expect(string, contains('20%'));
        expect(string, contains('10%'));
        expect(string, contains('IntensityDistribution'));
      });
    });
  });
}
