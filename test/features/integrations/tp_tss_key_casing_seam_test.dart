/// Seam test — TrainingPeaks TSS key casing (Critical bug, 2026-09-17/18).
///
/// TP spells its TSS keys inconsistently across API surfaces: the published
/// spec and by-id examples show `TSSPlanned`, but the live `/v2/workouts`
/// range endpoint — the one the sync actually calls — sends `TssPlanned`
/// (and `TssActual`). Proven on the real prod wire 2026-09-18 (qa-70 probe:
/// athlete 4297587, 21 workouts, all with populated decimal `TssPlanned`
/// stored as null). The parser read only `TSSPlanned`, so `tss_planned`
/// never populated and the ratified §7.1 TSS/hr intensity rung never ran.
///
/// Per docs/test/README.md §Seam tests, every fixture here is
/// PRODUCER-shaped: real wire casing as captured from the live endpoint
/// (`TssPlanned`) and from the spec surface (`TSSPlanned`) — never the
/// casing the parser happens to read. Fixtures written from the parser's
/// own key list are equal by construction and cannot catch this class
/// of bug — which is exactly how the existing capture tests stayed green
/// while prod dropped the field daily.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';

void main() {
  const userId = 'tss-casing-seam-user';
  const transformer = TrainingPeaksTransformer();

  group('live range-endpoint casing (TssPlanned) — the prod wire shape', () {
    test('populated TssPlanned reaches Activity.tssPlanned and the '
        'TransformResult', () {
      // Wire-shaped: decimal TssPlanned/IFPlanned as the premium athletes
      // on prod carry them (qa-70, 2026-09-18). Keys as captured, verbatim.
      final workout = {
        'Id': 429758701,
        'WorkoutDay': '2026-09-18T00:00:00',
        'WorkoutType': 'Bike',
        'Title': 'Sweet Spot Intervals',
        'TotalTimePlanned': 1.5,
        'DistancePlanned': 40000.0,
        'TssPlanned': 85.2,
        'IFPlanned': 0.84,
      };

      final result = transformer.transform(workout, userId)!;

      expect(
        result.activity.tssPlanned,
        85.2,
        reason: 'live wire sends TssPlanned; parser must not drop it',
      );
      expect(result.tssPlanned, 85.2);
    });

    test('TSS/hr intensity rung fires on live casing when IF is null — '
        '"Endurance Ride" is priced by its load, not its name', () {
      // The exact harm from the bug report: a workout carrying TSS but no
      // IF fell through to title keywords, so "Endurance Ride" stored
      // moderate regardless of load. 110 TSS in 1.0h = 110 TSS/hr → hard.
      // Old code: TssPlanned unread → keyword "endurance" → moderate.
      final workout = {
        'Id': 429758702,
        'WorkoutDay': '2026-09-19T00:00:00',
        'WorkoutType': 'Bike',
        'Title': 'Endurance Ride',
        'TotalTimePlanned': 1.0,
        'TssPlanned': 110.0,
        'IFPlanned': null,
      };

      final activity = transformer.transform(workout, userId)!.activity;

      expect(
        activity.intensityLevel,
        IntensityLevel.hard,
        reason: 'the §7.1 TSS/hr rung must run on the live wire casing',
      );
    });

    test('TssActual on the live casing still lands (was already correct); '
        'spec casing TSSActual is tolerated too', () {
      final liveCasing = {
        'Id': 429758703,
        'WorkoutDay': '2026-09-17T00:00:00',
        'WorkoutType': 'Run',
        'Title': 'Threshold Run',
        'TotalTime': 1.02,
        'Distance': 14200.0,
        'TssActual': 74.6,
      };
      expect(
        transformer.transform(liveCasing, userId)!.activity.tssActual,
        74.6,
      );

      final specCasing = {...liveCasing, 'Id': 429758704}
        ..remove('TssActual')
        ..['TSSActual'] = 74.6;
      expect(
        transformer.transform(specCasing, userId)!.activity.tssActual,
        74.6,
        reason: 'accept both casings — the untested surface is the one '
            'that breaks (bug report, suggested fix)',
      );
    });
  });

  group('spec-surface casing (TSSPlanned) keeps working — regression', () {
    test('TSSPlanned still reaches storage and the TSS/hr rung', () {
      final workout = {
        'Id': 111222444,
        'WorkoutDay': '2026-09-18T00:00:00',
        'WorkoutType': 'Bike',
        'Title': 'Endurance Ride',
        'TotalTimePlanned': 1.0,
        'TSSPlanned': 110.0,
        'IFPlanned': null,
      };

      final result = transformer.transform(workout, userId)!;
      expect(result.activity.tssPlanned, 110.0);
      expect(result.activity.intensityLevel, IntensityLevel.hard);
    });
  });

  group('DI-13 null-tolerance unchanged', () {
    test('both casings present as keys with null values (basic athlete) '
        'stores null, never throws, never fabricates', () {
      final workout = {
        'Id': 111222445,
        'WorkoutDay': '2026-09-18T00:00:00',
        'WorkoutType': 'Run',
        'Title': 'Easy Run',
        'TotalTimePlanned': 0.75,
        'TssPlanned': null,
        'TSSPlanned': null,
        'TssActual': null,
        'IFPlanned': null,
        'IF': null,
      };

      final activity = transformer.transform(workout, userId)!.activity;
      expect(activity.tssPlanned, isNull);
      expect(activity.tssActual, isNull);
    });
  });
}
