/// DI-26 — the fabricating fallbacks are DELETED, and an unparseable step
/// makes the WHOLE structure unparseable (qa-33's DI-16 wording, RULED).
///
/// Two families were fabricating:
///   (a) `_classifyIntensity`'s default arm treated any value <= 1.5 as a
///       %FTP fraction, so a threshold-pace target became an FTP-derived
///       zone and was reported as though measured.
///   (b) the length-unit default assumed SECONDS for anything it did not
///       recognise, so a distance step ("1.00 km") weighed as 1 second.
///
/// The governing rule is stricter than deleting those branches: a step we
/// cannot parse must condemn the entire structure to NULL, because silently
/// SKIPPING it yields a confident distribution computed only from the steps
/// we happened to understand — which is worse than refusing, since nothing
/// downstream can tell it apart from a real one.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';

const _t = TrainingPeaksTransformer();

/// A workout with no IF/TSS, so the structure is the only rung that could
/// contribute a step-derived split.
Map<String, dynamic> workoutWithStructure(String? structureJson) => {
      'Id': 1,
      'WorkoutType': 'Run',
      'Title': 'Steady',
      'WorkoutDay': '2026-09-21T00:00:00',
      'TotalTimePlanned': 1.0,
      if (structureJson != null) 'Structure': structureJson,
    };

/// What this workout classifies as with NO structure at all — i.e. purely
/// from the title/default rungs. A REFUSED structure must land here exactly:
/// the rule is that the steps contribute nothing, not that classification
/// stops (the fallback rungs are ruled to keep working).
String baselineSplit() =>
    _t.transform(workoutWithStructure(null), 'u1')!
        .intensityDistribution
        .toString();

/// The split produced for [structureJson]; compare against baselineSplit().
String splitFor(String structureJson) =>
    _t.transform(workoutWithStructure(structureJson), 'u1')!
        .intensityDistribution
        .toString();

String step({
  required String lengthUnit,
  required num lengthValue,
  String? intensityUnit,
  num? intensityValue,
}) {
  final target = intensityUnit == null
      ? ''
      : ',"IntensityTarget":{"Unit":"$intensityUnit",'
          '"Value":${intensityValue ?? 0}}';
  return '{"Type":"Step","Length":{"Unit":"$lengthUnit",'
      '"Value":$lengthValue}$target}';
}

void main() {
  group('family (a): no zone is invented from an unknown intensity unit', () {
    test('a threshold-pace step yields NO %FTP-derived zone', () {
      // Value 0.95 is exactly the shape the deleted branch misread as 95% FTP.
      expect(
        splitFor(
          '[${step(lengthUnit: 'Minute', lengthValue: 20, intensityUnit: 'PercentOfThresholdPace', intensityValue: 0.95)}]',
        ),
        baselineSplit(),
        reason: 'the step must contribute NOTHING — no %FTP conversion',
      );
    });

    test('a step with NO intensity target is refused, not parked in '
        'conversational', () {
      expect(
        splitFor('[${step(lengthUnit: 'Minute', lengthValue: 30)}]'),
        baselineSplit(),
      );
    });
  });

  group('family (b): no duration is invented from a non-time unit', () {
    test('a distance-length step yields no seconds-weighted split', () {
      // The deleted arm read this as 1 second of training.
      expect(
        splitFor(
          '[${step(lengthUnit: 'Kilometer', lengthValue: 1.0, intensityUnit: 'PercentOfFtp', intensityValue: 0.75)}]',
        ),
        baselineSplit(),
      );
    });

    test('an absent length unit is refused', () {
      expect(
        splitFor('[{"Type":"Step","Length":{"Value":600},'
            '"IntensityTarget":{"Unit":"PercentOfFtp","Value":0.7}}]'),
        baselineSplit(),
      );
    });
  });

  group('whole-structure refusal, not per-step skip', () {
    test('ONE bad step condemns an otherwise parseable structure', () {
      final good = step(
        lengthUnit: 'Minute',
        lengthValue: 40,
        intensityUnit: 'PercentOfFtp',
        intensityValue: 0.65,
      );
      final bad = step(
        lengthUnit: 'Kilometer',
        lengthValue: 5,
        intensityUnit: 'PercentOfFtp',
        intensityValue: 0.9,
      );
      expect(
        splitFor('[$good,$bad]'),
        baselineSplit(),
        reason: 'the good step must NOT be silently kept on its own',
      );
      expect(
        splitFor('[$good,$bad]'),
        isNot(splitFor('[$good]')),
        reason: 'and the result must differ from keeping only the good step',
      );
    });

    test('a bad step nested inside a Repetition also condemns the whole', () {
      final inner = step(
        lengthUnit: 'Kilometer',
        lengthValue: 1,
        intensityUnit: 'PercentOfFtp',
        intensityValue: 0.9,
      );
      expect(
        splitFor('[{"Type":"Repetition","RepeatCount":4,"Steps":[$inner]}]'),
        baselineSplit(),
      );
    });
  });

  group('positive control — a fully understood structure still parses', () {
    test('time-based steps with known intensity units produce a split', () {
      final a = step(
        lengthUnit: 'Minute',
        lengthValue: 10,
        intensityUnit: 'PercentOfFtp',
        intensityValue: 0.60,
      );
      final b = step(
        lengthUnit: 'Minute',
        lengthValue: 20,
        intensityUnit: 'PercentOfFtp',
        intensityValue: 1.05,
      );
      expect(
        splitFor('[$a,$b]'),
        isNot(baselineSplit()),
        reason: 'refusal must be targeted — a good structure still counts',
      );
    });
  });
}
