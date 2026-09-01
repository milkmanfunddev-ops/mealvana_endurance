import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/intraday_display.dart';

/// Conformance runner for the intraday-display slice: feeds the ratified
/// vectors (docs/ssot/vectors/daily-macros/intraday-display.json, verbatim
/// mirror of the QA repo) to the real display consumer. The vectors are the
/// contract — never edit them to make code pass. `kind` routes the
/// assertion style: so_far (numeric, abs tol), net_band (exact string or
/// null), intake (numeric), flags (booleans).
void main() {
  final file =
      jsonDecode(
            File(
              'docs/ssot/vectors/daily-macros/intraday-display.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final tol = (file['toleranceKcal'] as num).toDouble();

  List<IntradaySession> sessions(Map<String, dynamic> inputs) {
    return [
      for (final raw in (inputs['sessions'] as List? ?? const []))
        IntradaySession(
          kcal: ((raw as Map)['kcal'] as num).toDouble(),
          actualTimeMin: (raw['actualTimeMin'] as num?)?.toInt(),
          status: raw['status'] as String?,
          wearableRecorded: (raw['wearableRecorded'] as bool?) ?? false,
        ),
    ];
  }

  for (final raw in file['vectors'] as List) {
    final v = raw as Map<String, dynamic>;
    final id = v['id'] as String;
    final kind = v['kind'] as String;
    final inputs = v['inputs'] as Map<String, dynamic>;
    final expected = v['expected'] as Map<String, dynamic>;

    test('$kind · $id', () {
      switch (kind) {
        case 'so_far':
          final accrual = IntradayDisplay.burnedSoFar(
            minutesSinceMidnight: (inputs['minutesSinceMidnight'] as num)
                .toInt(),
            rmr: (inputs['rmr'] as num).toDouble(),
            neatKcal: (inputs['neatKcal'] as num).toDouble(),
            eatenKcal: (inputs['eatenKcal'] as num).toDouble(),
            sessions: sessions(inputs),
            wearableConnected: (inputs['wearableConnected'] as bool?) ?? false,
            syncedToday: (inputs['syncedToday'] as bool?) ?? false,
            lastSyncMin: (inputs['lastSyncMin'] as num?)?.toInt(),
            activeEnergyThroughSync: (inputs['activeEnergyThroughSync'] as num?)
                ?.toDouble(),
          );
          if (expected.containsKey('resting')) {
            expect(
              accrual.resting,
              closeTo((expected['resting'] as num).toDouble(), tol),
            );
          }
          if (expected.containsKey('movement')) {
            expect(
              accrual.movement,
              closeTo((expected['movement'] as num).toDouble(), tol),
            );
          }
          if (expected.containsKey('workout')) {
            expect(
              accrual.workout,
              closeTo((expected['workout'] as num).toDouble(), tol),
            );
          }
          if (expected.containsKey('digestion')) {
            expect(
              accrual.digestion,
              closeTo((expected['digestion'] as num).toDouble(), tol),
            );
          }
          if (expected.containsKey('burned')) {
            expect(
              accrual.burned,
              closeTo((expected['burned'] as num).toDouble(), tol),
            );
          }
          if (expected.containsKey('rendered')) {
            final deleted = sessions(
              inputs,
            ).where((s) => s.status == 'deleted');
            expect(
              deleted,
              isNotEmpty,
              reason: 'rendered expectation targets the deleted session',
            );
            expect(deleted.every((s) => s.renders), expected['rendered']);
          }
          break;

        case 'net_band':
          final copy = IntradayDisplay.netBandCopy(
            netKcal: (inputs['netKcal'] as num).toDouble(),
            energyBasis: inputs['energyBasis'] as String,
          );
          expect(copy, expected['copy']);
          break;

        case 'intake':
          final summary = IntradayDisplay.intakeSummary(
            targetKcal: (inputs['targetKcal'] as num).toDouble(),
            entries: [
              for (final e in inputs['entries'] as List)
                IntakeEntry(
                  kcal: ((e as Map)['kcal'] as num).toDouble(),
                  consumed: e['consumed'] as bool,
                ),
            ],
          );
          expect(
            summary.logged,
            closeTo((expected['logged'] as num).toDouble(), tol),
          );
          expect(
            summary.planned,
            closeTo((expected['planned'] as num).toDouble(), tol),
          );
          expect(
            summary.remaining,
            closeTo((expected['remaining'] as num).toDouble(), tol),
          );
          expect(
            summary.projected,
            closeTo((expected['projected'] as num).toDouble(), tol),
          );
          break;

        case 'flags':
          final visibility = IntradayDisplay.trackingVisibility(
            trackingOff: inputs['trackingOff'] as bool,
            eaStatus: inputs['eaStatus'] as String?,
          );
          expect(visibility.quantitiesRendered, expected['quantitiesRendered']);
          expect(visibility.blockRendered, expected['blockRendered']);
          break;

        default:
          fail('unhandled vector kind "$kind" for $id');
      }
    });
  }

  test('no deficit copy is congratulatory (string-level check)', () {
    // Spec conformance check 6: enumerate the copy strings; deficit-side
    // copy always points toward food, never toward achievement.
    const congratulatory = ['great', 'nice', 'well done', 'good job', 'crush'];
    for (final net in [-201.0, -500.0, -501.0, -2000.0]) {
      final copy = IntradayDisplay.netBandCopy(
        netKcal: net,
        energyBasis: 'as_computed',
      );
      expect(copy, isNotNull);
      for (final word in congratulatory) {
        expect(
          copy!.toLowerCase().contains(word),
          isFalse,
          reason: 'deficit copy "$copy" must not celebrate under-eating',
        );
      }
    }
  });
}
