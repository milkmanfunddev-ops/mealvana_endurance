// QA conformance — carb-loading entryway behavior, SSOT v1 (behavior ratified
// 2026-09-24; CE-8/CE-9 + F3/F4 desk rulings 2026-09-25; bundle
// carb-loading@v1 @ f809f54).
//
// Lives in qa/conformance/; copied into <app>/test/ by run_dart.sh and run:
//   flutter test ... --dart-define=QA_VECTORS=<abs carb-loading-entryway.json>
//
// Covers the pure-decision layer only: the CE-8 feasibility gate (enumerated
// grid) and the CE-4 re-pick migration (dialog type, F3 listed-edit DATA,
// dropped-date disclosure, keep/reset plans). Strings are the copy register's
// (L2); F5's selection-time re-check is a timing behavior (L2/Patrol); CE-5
// delete is asserted as food-log survival in L2 — none of those live here.
//
// Oracle conventions: weight 149.9 lb throughout; race date 2026-09-28;
// daysUntilRace is whole days with race morning == 0; plans list day targets
// first loading day first.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_entryway_engine.dart';

const String kVectorsPath = String.fromEnvironment('QA_VECTORS');

// Oracle constants, mirrored deliberately (independent checker).
const double kBodyWeightLb = 149.9;
final DateTime kRaceDate = DateTime(2026, 9, 28);

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  final file = File(kVectorsPath);
  if (!file.existsSync()) {
    throw StateError('QA_VECTORS not found: "$kVectorsPath"');
  }
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  group('vectors: carb-loading-entryway', () {
    for (final v in vectors) {
      test(v['id'] as String, () {
        final inputs = v['inputs'] as Map<String, dynamic>;
        final expected = v['expected'] as Map<String, dynamic>;

        // Detection-power rule (2026-09-21): a clause the harness cannot assert
        // must FAIL the run, never ride silently green.
        const knownKeys = {
          'choosable', 'entryRowState', 'cardState', 'reasonN', 'dialogType',
          'listedEdits', 'droppedDates', 'keepPlanG', 'resetPlanG',
          'resultPlanG',
        };
        for (final key in expected.keys) {
          if (!knownKeys.contains(key)) {
            fail('vector ${v['id']} carries unknown expected key: $key');
          }
        }

        // CE-8 feasibility grid.
        if (expected.containsKey('choosable')) {
          final got = CarbLoadingEntrywayEngine.choosableProtocols(
            inputs['daysUntilRace'] as int,
          );
          expect(got, (expected['choosable'] as List).cast<int>());
          if (expected.containsKey('entryRowState')) {
            expect(
              CarbLoadingEntrywayEngine.entryRowStateWire(
                inputs['daysUntilRace'] as int,
              ),
              expected['entryRowState'],
            );
          }
          return;
        }

        // CE-8 disabled-card treatment.
        if (expected.containsKey('cardState')) {
          final choosable = CarbLoadingEntrywayEngine.isChoosable(
            daysUntilRace: inputs['daysUntilRace'] as int,
            protocolDays: inputs['protocolDays'] as int,
          );
          expect(choosable, isFalse, reason: 'card must be infeasible');
          expect(expected['cardState'], 'disabled-with-reason');
          // Spec: the reason names the protocol's own day count.
          expect(inputs['protocolDays'], expected['reasonN']);
          return;
        }

        // CE-4 re-pick migration.
        final edits = <DateTime, int>{};
        (inputs['edits'] as Map<String, dynamic>).forEach((k, val) {
          edits[DateTime.parse(k)] = val as int;
        });
        // Merge edits over the stored plan: unedited dates carry their
        // derivation (the engine filters stored == derived itself).
        final current = inputs['currentProtocol'] as int;
        final stored = <DateTime, int>{};
        final window = CarbLoadingEntrywayEngine.windowDates(
          protocolDays: current,
          raceDate: kRaceDate,
        );
        final derived = CarbLoadingEntrywayEngine.derivedTargetsG(
          protocolDays: current,
          bodyWeightLb: kBodyWeightLb,
        );
        for (var i = 0; i < window.length; i++) {
          stored[window[i]] = edits[window[i]] ?? derived[i];
        }

        final got = CarbLoadingEntrywayEngine.repick(
          currentProtocol: current,
          storedTargetsByDate: stored,
          targetProtocol: inputs['targetProtocol'] as int,
          bodyWeightLb: kBodyWeightLb,
          raceDate: kRaceDate,
        );

        expect(got.dialogType.wire, expected['dialogType'], reason: 'dialogType');
        if (expected.containsKey('listedEdits')) {
          final want = (expected['listedEdits'] as List)
              .cast<Map<String, dynamic>>();
          expect(got.listedEdits.length, want.length, reason: 'listedEdits');
          for (var i = 0; i < want.length; i++) {
            expect(iso(got.listedEdits[i].date), want[i]['date']);
            expect(
              got.listedEdits[i].targetDayNumber,
              want[i]['targetDayNumber'],
              reason: 'F3 relabels per the TARGET window',
            );
            expect(got.listedEdits[i].storedG, want[i]['storedG']);
          }
        }
        if (expected.containsKey('droppedDates')) {
          expect(
            got.droppedDates.map(iso).toList(),
            (expected['droppedDates'] as List).cast<String>(),
            reason: 'dropped dates must be disclosed (Q-CL10)',
          );
        }
        if (expected.containsKey('keepPlanG')) {
          expect(got.keepPlanG, (expected['keepPlanG'] as List).cast<int>());
        }
        if (expected.containsKey('resetPlanG')) {
          expect(got.resetPlanG, (expected['resetPlanG'] as List).cast<int>());
        }
        if (expected.containsKey('resultPlanG')) {
          // Notice case: the single button's outcome — keep and reset
          // coincide with the derivation.
          expect(got.keepPlanG, (expected['resultPlanG'] as List).cast<int>());
          expect(got.resetPlanG, (expected['resultPlanG'] as List).cast<int>());
        }
      });
    }
  });
}
