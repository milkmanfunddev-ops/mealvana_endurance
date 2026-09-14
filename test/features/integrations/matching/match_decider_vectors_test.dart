/// Dart-twin conformance — the 41 ratified matching vectors against
/// lib/features/integrations/application/matching/match_decider.dart.
///
/// D-005 twin discipline: the TS twin runs the SAME vectors in
/// supabase/functions/_shared/garmin/matcher.test.ts; a divergence between
/// the two suites is a twin break, not a vector problem. Vector authority:
/// docs/ssot/vectors/integrations/matching.json @ tag data-integrations@v1.
///
/// The single translation liberty (documented in both twins): the prose
/// `context` line on brick-b5-no-double-import becomes stamp state on the
/// brick candidate (stamp storage is implementation freedom, Q-INT23).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/matching/match_decider.dart';

int _toMs(String naiveLocal) {
  final withSeconds =
      naiveLocal.length == 16 ? '$naiveLocal:00' : naiveLocal;
  return DateTime.parse('${withSeconds}Z').millisecondsSinceEpoch;
}

MatcherIncomingActivity _toActivity(Map<String, dynamic> a) {
  return MatcherIncomingActivity(
    summaryId: a['summaryId'] as String?,
    sport: (a['sport'] as String?) ?? 'other',
    startMs: _toMs(a['startLocal'] as String),
    durationMin: (a['durationMin'] as num).toDouble(),
    parentSummaryId: a['parentSummaryId'] as String?,
    isParent: a['isParent'] as bool?,
  );
}

MatcherIncoming _toIncoming(Map<String, dynamic> incoming) {
  if (incoming['source'] == 'platform') {
    return MatcherIncomingKeyed(
      provider: (incoming['provider'] as String?) ?? 'unknown',
      planId: (incoming['planId'] as String?) ?? '',
      signalKind: incoming['signalKind'] == 'planned-import'
          ? KeyedSignalKind.plannedImport
          : KeyedSignalKind.completion,
      sport: (incoming['sport'] as String?) ?? 'other',
      startMs: _toMs(incoming['startLocal'] as String),
      durationMin: (incoming['durationMin'] as num).toDouble(),
    );
  }
  final sequence = incoming['sequence'] as List?;
  if (sequence != null) {
    return MatcherIncomingSequence(
      sequence
          .map((a) => _toActivity((a as Map).cast<String, dynamic>()))
          .toList(),
      parentMatchedRowId: incoming['parentMatchedRowId'] as String?,
    );
  }
  return MatcherIncomingGarmin(_toActivity(incoming));
}

MatcherCandidate _toCandidate(Map<String, dynamic> c) {
  final segments = c['segments'] as List?;
  return MatcherCandidate(
    rowId: c['rowId'] as String,
    status: c['status'] as String,
    sport: c['sport'] as String,
    slotMs: c['slotLocal'] != null
        ? _toMs(c['slotLocal'] as String)
        : segments != null
            ? _toMs('2026-09-10T07:00') // brick vectors omit the slot
            : c['matchedStartLocal'] != null
                ? _toMs(c['matchedStartLocal'] as String)
                : null,
    garminSummaryId: c['garminSummaryId'] as String?,
    providerWorkoutId: c['providerWorkoutId'] as String?,
    deletedAt: false,
    plannedDurationMin: (c['plannedDurationMin'] as num?)?.toDouble(),
    recordedDurationMin: ((c['recordedDurationMin'] ??
            c['matchedDurationMin']) as num?)
        ?.toDouble(),
    matchedStartMs: c['matchedStartLocal'] != null
        ? _toMs(c['matchedStartLocal'] as String)
        : null,
    createdOrder: (c['createdOrder'] as num?)?.toInt() ?? 0,
    segments: segments
        ?.map((s) {
          final seg = (s as Map).cast<String, dynamic>();
          return MatcherSegment(
            order: (seg['order'] as num).toInt(),
            sport: seg['sport'] as String,
            durationMin: (seg['durationMin'] as num?)?.toDouble(),
          );
        })
        .toList(),
    totalDurationMin: (c['totalDurationMin'] as num?)?.toDouble(),
  );
}

/// Translate a vector `context` prose line into candidate state.
List<MatcherCandidate> _applyContext(
  Map<String, dynamic> incoming,
  List<MatcherCandidate> candidates,
) {
  final context = incoming['context'] as String?;
  if (context == null) return candidates;
  final parentMatch =
      RegExp(r'parent (\S+) already matched (\S+)').firstMatch(context);
  final legMatch =
      RegExp(r'leg (\d+) already stamped (\S+)').firstMatch(context);
  if (parentMatch == null) return candidates;
  final parentSummaryId = parentMatch.group(1)!;
  final rowId = parentMatch.group(2)!;
  return candidates.map((c) {
    if (c.rowId != rowId) return c;
    return MatcherCandidate(
      rowId: c.rowId,
      status: c.status,
      sport: c.sport,
      slotMs: c.slotMs,
      garminSummaryId: c.garminSummaryId,
      providerWorkoutId: c.providerWorkoutId,
      deletedAt: c.deletedAt,
      plannedDurationMin: c.plannedDurationMin,
      recordedDurationMin: c.recordedDurationMin,
      matchedStartMs: c.matchedStartMs,
      createdOrder: c.createdOrder,
      totalDurationMin: c.totalDurationMin,
      parentStampSummaryId: parentSummaryId,
      segments: c.segments?.map((s) {
        if (legMatch != null && s.order == int.parse(legMatch.group(1)!)) {
          return MatcherSegment(
            order: s.order,
            sport: s.sport,
            durationMin: s.durationMin,
            stampedSummaryId: legMatch.group(2),
          );
        }
        return s;
      }).toList(),
    );
  }).toList();
}

Map<String, dynamic> _decisionToMap(MatchDecision d) => {
      'gate': d.gate,
      'action': d.action,
      'matchedRowId': d.matchedRowId,
      'insertedSport': d.insertedSport,
      'parentVerified': d.parentVerified,
      'legStamps': d.legStamps,
      'reboundPlanId': d.reboundPlanId,
      'displacedRescoredTo': d.displacedRescoredTo,
      'standaloneRow': d.standaloneRow,
    };

void main() {
  final file = File('docs/ssot/vectors/integrations/matching.json');
  final vectors = ((jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['vectors'] as List)
      .cast<Map<String, dynamic>>();

  test('41 matching vectors present at the pinned tag', () {
    expect(vectors, hasLength(41));
  });

  for (final vector in vectors) {
    test('matching vector: ${vector['id']}', () {
      final inputs = vector['inputs'] as Map<String, dynamic>;
      final incoming = inputs['incoming'] as Map<String, dynamic>;
      var candidates = (inputs['candidates'] as List)
          .map((c) => _toCandidate((c as Map).cast<String, dynamic>()))
          .toList();
      candidates = _applyContext(incoming, candidates);

      final observed = _decisionToMap(
        decideMatch(_toIncoming(incoming), candidates),
      );
      final expected = vector['expected'] as Map<String, dynamic>;

      for (final entry in expected.entries) {
        expect(
          observed[entry.key],
          equals(entry.value),
          reason:
              '${vector['id']} ${entry.key}\nwhy: ${vector['why']}',
        );
      }
    });
  }
}
