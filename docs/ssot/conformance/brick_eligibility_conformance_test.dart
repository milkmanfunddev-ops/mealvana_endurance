// QA conformance — brick eligibility, spec/domain/brick.md v1 (ratified
// 2026-08-31). FIRST domain-family slice: vectors live at
// vectors/domain/brick-eligibility.json.
//
// Lives in qa/conformance/; copied into <app>/test/ by run_dart.sh and run with
//   flutter test ... --dart-define=QA_VECTORS=<abs path to the vectors json>
//
// Runs against the app's PUBLISHED predicate (brick_eligibility.dart):
//   - offer vectors: hasBrickCandidates + brickCandidateIds over the day
//   - create vectors: evaluateBrickCreate over pickedLegIds — gate IDENTITY
//     is part of the contract (a rejection for the wrong reason fails)
//
// Input mapping (vector wire → app domain):
//   sport  run|bike|swim → ActivityType.running|cycling|swimming;
//          strength|other → ActivityType.other (never a leg, R3)
//   isBrick true → ActivityType.brick (a brick row IS the brick type)
//   status planned|skipped → ActivityStatus.planned|skipped;
//          done_confirmed → completed; done_verified → completed (the
//          verification flag lives outside eligibility — Q-BR1 tripwire
//          vector pins current linkable behaviour as characterization)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_eligibility.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

ActivityType _sportToType(String sport, bool isBrick) {
  if (isBrick) return ActivityType.brick;
  switch (sport) {
    case 'run':
      return ActivityType.running;
    case 'bike':
      return ActivityType.cycling;
    case 'swim':
      return ActivityType.swimming;
    default:
      return ActivityType.other;
  }
}

ActivityStatus _statusFromWire(String status) {
  switch (status) {
    case 'skipped':
      return ActivityStatus.skipped;
    case 'done_confirmed':
    case 'done_verified':
      return ActivityStatus.completed;
    default:
      return ActivityStatus.planned;
  }
}

Activity _activityFromWire(Map<String, dynamic> row) => Activity(
  id: row['id'] as String,
  userId: 'qa',
  title: row['id'] as String,
  activityType: _sportToType(
    row['sport'] as String,
    row['isBrick'] as bool? ?? false,
  ),
  status: _statusFromWire(row['status'] as String? ?? 'planned'),
  scheduledDateTime: DateTime(2026, 9, 1, 8),
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');

  final file = File(vectorsPath);
  if (vectorsPath.isEmpty || !file.existsSync()) {
    throw StateError(
      'QA_VECTORS not provided or missing: "$vectorsPath" — run via '
      'qa/conformance/run_dart.sh brick-eligibility',
    );
  }

  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  group('vectors: brick-eligibility (${vectors.length})', () {
    test('vector count sanity', () {
      expect(vectors.length, greaterThanOrEqualTo(14),
          reason: 'vector file unexpectedly small — wrong file?');
    });

    for (final vector in vectors) {
      final id = vector['id'] as String;
      final status = vector['status'] as String? ?? 'ratified';
      final inputs = vector['inputs'] as Map<String, dynamic>;
      final expected = vector['expected'] as Map<String, dynamic>;

      test('[$status] $id', () {
        final day = (inputs['day'] as List)
            .cast<Map<String, dynamic>>()
            .map(_activityFromWire)
            .toList();
        final byId = {for (final a in day) a.id: a};

        final pickedIds = (inputs['pickedLegIds'] as List?)?.cast<String>();
        if (pickedIds == null) {
          // Offer vector: {offered, candidateIds} — candidateIds preserve
          // day order (oracle convention; brickCandidateIds iterates in day
          // order, so list conversion keeps it).
          expect(
            hasBrickCandidates(day),
            expected['offered'],
            reason: '$id: offered (${vector['why']})',
          );
          final expectedIds = (expected['candidateIds'] as List)
              .cast<String>();
          if (expected['offered'] == true) {
            expect(
              brickCandidateIds(day).toList(),
              expectedIds,
              reason: '$id: candidateIds in day order',
            );
          } else {
            // Not offered ⇒ nothing selectable; the vector's candidateIds
            // enumerate the eligible-but-insufficient rows, which the app
            // deliberately does not expose (offer gate first). Assert the
            // gate instead: fewer than 2 of the day's rows are eligible,
            // and every vector-listed candidate is individually eligible.
            expect(brickCandidateIds(day), isEmpty, reason: '$id: no offer');
            final eligible = day.where((a) => a.isBrickEligible).toList();
            expect(eligible.length, lessThan(2), reason: '$id: gate reason');
            for (final cid in expectedIds) {
              expect(
                byId[cid]!.isBrickEligible,
                isTrue,
                reason: '$id: $cid should be individually eligible',
              );
            }
            for (final a in day) {
              if (!expectedIds.contains(a.id)) {
                expect(
                  a.isBrickEligible,
                  isFalse,
                  reason: '$id: ${a.id} should be ineligible',
                );
              }
            }
          }
        } else {
          // Create vector: {createAllowed, gate, legOrder}.
          final picked = [for (final pid in pickedIds) byId[pid]!];
          final verdict = evaluateBrickCreate(picked);
          expect(
            verdict.createAllowed,
            expected['createAllowed'],
            reason: '$id: createAllowed (${vector['why']})',
          );
          expect(
            verdict.gate?.wireName,
            expected['gate'],
            reason: '$id: gate identity is part of the contract',
          );
          expect(
            verdict.legOrder,
            expected['legOrder'],
            reason: '$id: legOrder = pick order (R6)',
          );
        }
      });
    }
  });
}
