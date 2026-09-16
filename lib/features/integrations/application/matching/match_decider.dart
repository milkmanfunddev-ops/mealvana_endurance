/// The matcher tier, Dart twin — data-integrations@v1
/// (docs/ssot/spec/integrations/matching.md, RATIFIED Xuan 2026-09-10).
///
/// D-005 twin discipline: this file mirrors
/// `supabase/functions/_shared/garmin/matcher.ts` clause for clause; the
/// two move together and both are pinned by the same 41 vectors
/// (docs/ssot/vectors/integrations/matching.json — the Dart side runs them
/// in test/features/integrations/matching/match_decider_vectors_test.dart).
///
/// PURE DECISION LAYER: given an incoming signal and the candidate rows,
/// return what must happen — gate identity AND action — without touching
/// a database. Executors (change detection / repositories client-side,
/// the edge functions server-side) apply the decision; write-time effects
/// belong to them.
///
/// See the TS twin's header for the full gate ordering and the
/// vector-pinned conventions (inclusive ±15 and 30-min bounds, strict
/// guard thresholds, best-fit tie ladder, instant-resolved comparison
/// with naive-local storage per L-9.2).
library;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

class MatcherIncomingActivity {
  const MatcherIncomingActivity({
    required this.summaryId,
    required this.sport,
    required this.startMs,
    required this.durationMin,
    this.parentSummaryId,
    this.isParent,
  });

  final String? summaryId;
  final String sport;
  final int startMs;
  final double durationMin;
  final String? parentSummaryId;
  final bool? isParent;
}

sealed class MatcherIncoming {
  const MatcherIncoming();
}

class MatcherIncomingGarmin extends MatcherIncoming {
  const MatcherIncomingGarmin(this.activity);
  final MatcherIncomingActivity activity;
}

class MatcherIncomingSequence extends MatcherIncoming {
  const MatcherIncomingSequence(this.activities, {this.parentMatchedRowId});
  final List<MatcherIncomingActivity> activities;
  final String? parentMatchedRowId;
}

enum KeyedSignalKind { completion, plannedImport }

class MatcherIncomingKeyed extends MatcherIncoming {
  const MatcherIncomingKeyed({
    required this.provider,
    required this.planId,
    required this.signalKind,
    required this.sport,
    required this.startMs,
    required this.durationMin,
  });

  final String provider;
  final String planId;
  final KeyedSignalKind signalKind;
  final String sport;
  final int startMs;
  final double durationMin;
}

class MatcherSegment {
  const MatcherSegment({
    required this.order,
    required this.sport,
    required this.durationMin,
    this.stampedSummaryId,
    this.stampedEndMs,
  });

  final int order; // 1-based
  final String sport;
  final double? durationMin;
  final String? stampedSummaryId;
  final int? stampedEndMs;
}

class MatcherCandidate {
  const MatcherCandidate({
    required this.rowId,
    required this.status,
    required this.sport,
    required this.slotMs,
    this.garminSummaryId,
    this.providerWorkoutId,
    this.deletedAt = false,
    this.plannedDurationMin,
    this.recordedDurationMin,
    this.matchedStartMs,
    this.createdOrder = 0,
    this.segments,
    this.totalDurationMin,
    this.parentStampSummaryId,
  });

  final String rowId;
  final String status;
  final String sport;
  final int? slotMs;
  final String? garminSummaryId;
  final String? providerWorkoutId;
  final bool deletedAt;
  final double? plannedDurationMin;
  final double? recordedDurationMin;
  final int? matchedStartMs;
  final int createdOrder;
  final List<MatcherSegment>? segments;
  final double? totalDurationMin;
  final String? parentStampSummaryId;
}

class MatchDecision {
  const MatchDecision({
    required this.gate,
    required this.action,
    this.matchedRowId,
    this.insertedSport,
    this.parentVerified,
    this.legStamps,
    this.reboundPlanId,
    this.displacedRescoredTo,
    this.standaloneRow,
  });

  final String gate;
  final String action;
  final String? matchedRowId;
  final String? insertedSport;
  final bool? parentVerified;
  final Map<String, String>? legStamps;
  final String? reboundPlanId;
  final String? displacedRescoredTo;
  final bool? standaloneRow;
}

// ---------------------------------------------------------------------------
// Constants + helpers (twin of matcher.ts)
// ---------------------------------------------------------------------------

const _minMs = 60000;
const _narrowWindowMin = 15; // inclusive
const _brickGapMin = 30; // inclusive
const _signatureStartToleranceMin = 2;
const _signatureDurationTolerancePct = 0.05;
const _tzDriftDurationTolerancePct = 0.10;

const _matchableStatuses = {'planned', 'draft', 'skipped'};
const _brickEquivalentSports = {'multisport', 'triathlon', 'duathlon'};

/// The plausibility guard (M-1.1 / Q-INT21, DI-2). Strict bounds — exactly
/// 20% and exactly 2 min PASS.
bool guardRefuses(double measuredMin, double? plannedMin) {
  if (measuredMin < 2) return true;
  if (plannedMin != null && plannedMin > 0 && measuredMin / plannedMin < 0.2) {
    return true;
  }
  return false;
}

bool _sameLocalDay(int aMs, int bMs) {
  String day(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
          .toIso8601String()
          .substring(0, 10);
  return day(aMs) == day(bMs);
}

double _absMin(int aMs, int bMs) => (aMs - bMs).abs() / _minMs;

/// M-1.1 timezone defense (twin of isProbableTzDrift).
bool isProbableTzDrift(
  double deltaMin,
  double measuredMin,
  double? candidateMin,
) {
  if (deltaMin < 29) return false;
  if (candidateMin == null || candidateMin <= 0) return false;
  final durationOff = (measuredMin - candidateMin).abs() /
      (measuredMin > candidateMin ? measuredMin : candidateMin);
  if (durationOff > _tzDriftDurationTolerancePct) return false;
  final remainder = deltaMin % 30;
  return remainder < 1 || remainder > 29;
}

bool _signatureMatches(
  int aStartMs,
  double aDurationMin,
  int? bStartMs,
  double? bDurationMin,
) {
  if (bStartMs == null || bDurationMin == null) return false;
  if (_absMin(aStartMs, bStartMs) > _signatureStartToleranceMin) return false;
  final maxDur = [aDurationMin, bDurationMin, 1.0].reduce((a, b) => a > b ? a : b);
  final durOff = (aDurationMin - bDurationMin).abs() / maxDur;
  return durOff <= _signatureDurationTolerancePct;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

MatchDecision decideMatch(
  MatcherIncoming incoming,
  List<MatcherCandidate> candidates,
) {
  return switch (incoming) {
    MatcherIncomingGarmin(:final activity) =>
      _decideGarminSingle(activity, candidates),
    MatcherIncomingSequence() => _decideGarminSequence(incoming, candidates),
    MatcherIncomingKeyed() => _decideKeyed(incoming, candidates),
  };
}

// ---------------------------------------------------------------------------
// Garmin single-activity decision (twin of decideGarminSingle)
// ---------------------------------------------------------------------------

MatchDecision _decideGarminSingle(
  MatcherIncomingActivity incoming,
  List<MatcherCandidate> candidates,
) {
  final summaryId = incoming.summaryId;
  final sport = incoming.sport;
  final startMs = incoming.startMs;
  final durationMin = incoming.durationMin;
  var guardEliminated = false;

  // Gate 0 — tombstone T1 (id tier before the 'other' refusal).
  if (summaryId != null) {
    final t1 = candidates.where(
      (c) => c.status == 'deleted' && c.garminSummaryId == summaryId,
    );
    if (t1.isNotEmpty) {
      return const MatchDecision(gate: 'tombstone-T1', action: 'drop');
    }
  }

  // Gate 0 — tombstone T2 (skipped for 'other').
  if (sport != 'other' && sport != 'transition') {
    final t2 = candidates.where(
      (c) =>
          c.status == 'deleted' &&
          c.sport == sport &&
          c.slotMs != null &&
          _absMin(c.slotMs!, startMs) <= _narrowWindowMin,
    );
    if (t2.isNotEmpty) {
      return const MatchDecision(gate: 'tombstone-T2', action: 'drop');
    }
  }

  // B-4 — transitions never become standalone rows.
  if (sport == 'transition') {
    final brick = candidates.where((c) => c.sport == 'brick').firstOrNull;
    if (brick != null) {
      return MatchDecision(
        gate: 'transition-folded',
        action: 'fold-metadata',
        matchedRowId: brick.rowId,
        standaloneRow: false,
      );
    }
    return const MatchDecision(
      gate: 'transition-dropped',
      action: 'noop',
      standaloneRow: false,
    );
  }

  // Gate 1a — 'other' refusal.
  if (sport == 'other') {
    final hadMatchableCandidate =
        candidates.any((c) => _matchableStatuses.contains(c.status));
    return MatchDecision(
      gate: hadMatchableCandidate ? 'other-refusal' : 'insert',
      action: 'insert',
      insertedSport: 'other',
    );
  }

  // B-5 / duplicate: the brick (or another live row) already owns this id.
  if (summaryId != null) {
    final stampedOwner = candidates.where(
      (c) =>
          c.segments?.any((s) => s.stampedSummaryId == summaryId) ?? false,
    );
    if (stampedOwner.isNotEmpty) {
      return const MatchDecision(gate: 'duplicate', action: 'noop');
    }
    final owner = candidates.where(
      (c) =>
          c.garminSummaryId == summaryId &&
          c.status != 'deleted' &&
          c.status != 'skipped',
    );
    if (owner.isNotEmpty) {
      return const MatchDecision(gate: 'duplicate', action: 'noop');
    }
  }

  // Gate 1b — skipped T1 (id, provable fact: no window, no guard).
  if (summaryId != null) {
    final s1 = candidates
        .where(
          (c) => c.status == 'skipped' && c.garminSummaryId == summaryId,
        )
        .firstOrNull;
    if (s1 != null) {
      return MatchDecision(
        gate: 'skipped-T1',
        action: 'complete',
        matchedRowId: s1.rowId,
      );
    }
  }

  // Gate 1b — skipped T2 (±15 inclusive, guard applies, earliest wins).
  {
    final inWindow = candidates.where(
      (c) =>
          c.status == 'skipped' &&
          c.sport == sport &&
          !c.deletedAt &&
          c.slotMs != null &&
          _absMin(c.slotMs!, startMs) <= _narrowWindowMin,
    );
    final survivors = <MatcherCandidate>[];
    for (final c in inWindow) {
      if (guardRefuses(durationMin, c.plannedDurationMin)) {
        guardEliminated = true;
      } else {
        survivors.add(c);
      }
    }
    if (survivors.isNotEmpty) {
      survivors.sort((a, b) => (a.slotMs ?? 0).compareTo(b.slotMs ?? 0));
      return MatchDecision(
        gate: 'skipped-T2',
        action: 'complete',
        matchedRowId: survivors.first.rowId,
      );
    }
  }

  // B-1 — MULTI_SPORT parent completes a planned brick.
  if (_brickEquivalentSports.contains(sport)) {
    final bricks = candidates.where(
      (c) =>
          c.sport == 'brick' &&
          _matchableStatuses.contains(c.status) &&
          !c.deletedAt &&
          (c.slotMs == null || _sameLocalDay(c.slotMs!, startMs)),
    );
    final survivors = <MatcherCandidate>[];
    for (final c in bricks) {
      if (guardRefuses(durationMin, c.totalDurationMin)) {
        guardEliminated = true;
      } else {
        survivors.add(c);
      }
    }
    if (survivors.isNotEmpty) {
      return MatchDecision(
        gate: 'brick-parent',
        action: 'complete',
        matchedRowId: survivors.first.rowId,
        parentVerified: false,
      );
    }
  }

  MatchDecision? brickLeg() {
    final bricks = candidates.where(
      (c) =>
          c.sport == 'brick' &&
          !c.deletedAt &&
          c.segments != null &&
          (_matchableStatuses.contains(c.status) || c.status == 'completed'),
    );
    for (final brick in bricks) {
      final result = _tryExtendBrickChain(brick, incoming);
      if (result != null) return result;
    }
    return null;
  }

  // A child leg with lineage is never a standalone session.
  if (incoming.parentSummaryId != null) {
    final viaLineage = brickLeg();
    if (viaLineage != null) return viaLineage;
  }

  // Gate 1c — planned best-fit (day-wide, guard filters candidates).
  {
    final dayCandidates = candidates.where(
      (c) =>
          (c.status == 'planned' || c.status == 'draft') &&
          c.sport == sport &&
          !c.deletedAt &&
          c.slotMs != null &&
          _sameLocalDay(c.slotMs!, startMs),
    );
    final survivors = <MatcherCandidate>[];
    for (final c in dayCandidates) {
      if (guardRefuses(durationMin, c.plannedDurationMin)) {
        guardEliminated = true;
      } else {
        survivors.add(c);
      }
    }
    if (survivors.isNotEmpty) {
      final winner = _pickBestFit(survivors, startMs, durationMin);
      return MatchDecision(
        gate: 'planned',
        action: 'complete',
        matchedRowId: winner.rowId,
      );
    }
  }

  // Sequential brick leg without lineage — only now that 1b/1c missed.
  {
    final viaSequence = brickLeg();
    if (viaSequence != null) return viaSequence;
  }

  // Gate 2 — upgrade (M-3/Q-INT24).
  {
    final upgradeTargets = candidates.where(
      (c) =>
          c.status == 'completed' &&
          c.garminSummaryId == null &&
          c.sport == sport &&
          !c.deletedAt &&
          c.slotMs != null &&
          _sameLocalDay(c.slotMs!, startMs),
    );
    final survivors = <MatcherCandidate>[];
    for (final c in upgradeTargets) {
      if (guardRefuses(
        durationMin,
        c.recordedDurationMin ?? c.plannedDurationMin,
      )) {
        guardEliminated = true;
      } else {
        survivors.add(c);
      }
    }
    if (survivors.isNotEmpty) {
      survivors.sort(
        (a, b) => _absMin(a.slotMs!, startMs).compareTo(
          _absMin(b.slotMs!, startMs),
        ),
      );
      return MatchDecision(
        gate: 'upgrade',
        action: 'upgrade',
        matchedRowId: survivors.first.rowId,
      );
    }
  }

  // Gate 3 — insert.
  return MatchDecision(
    gate: guardEliminated ? 'guard-refused' : 'insert',
    action: 'insert',
    insertedSport: sport,
  );
}

MatcherCandidate _pickBestFit(
  List<MatcherCandidate> survivors,
  int startMs,
  double durationMin,
) {
  final scored = survivors.map((c) {
    var slotDistance =
        c.slotMs != null ? _absMin(c.slotMs!, startMs) : double.infinity;
    if (c.slotMs != null &&
        isProbableTzDrift(slotDistance, durationMin, c.plannedDurationMin)) {
      slotDistance = 0;
    }
    final durationFit =
        (c.plannedDurationMin != null && c.plannedDurationMin! > 0)
            ? (1 - durationMin / c.plannedDurationMin!).abs()
            : double.infinity;
    return (c: c, slotDistance: slotDistance, durationFit: durationFit);
  }).toList();
  scored.sort((a, b) {
    if (a.slotDistance != b.slotDistance) {
      return a.slotDistance.compareTo(b.slotDistance);
    }
    if (a.durationFit != b.durationFit) {
      return a.durationFit.compareTo(b.durationFit);
    }
    final aSlot = a.c.slotMs ?? 1 << 62;
    final bSlot = b.c.slotMs ?? 1 << 62;
    if (aSlot != bSlot) return aSlot.compareTo(bSlot);
    return a.c.createdOrder.compareTo(b.c.createdOrder);
  });
  return scored.first.c;
}

MatchDecision? _tryExtendBrickChain(
  MatcherCandidate brick,
  MatcherIncomingActivity incoming,
) {
  final segments = [...(brick.segments ?? <MatcherSegment>[])]
    ..sort((a, b) => a.order.compareTo(b.order));
  if (segments.isEmpty) return null;

  final nextIndex = segments.indexWhere((s) => s.stampedSummaryId == null);
  if (nextIndex == -1) return null;
  final expected = segments[nextIndex];
  if (expected.sport != incoming.sport) return null;

  if (incoming.parentSummaryId != null &&
      brick.parentStampSummaryId != null &&
      incoming.parentSummaryId != brick.parentStampSummaryId) {
    return null;
  }

  if (nextIndex == 0) {
    if (brick.slotMs != null &&
        !_sameLocalDay(brick.slotMs!, incoming.startMs)) {
      return null;
    }
  } else {
    final prev = segments[nextIndex - 1];
    final prevEndMs = prev.stampedEndMs;
    if (prevEndMs == null) return null;
    final gapMin = (incoming.startMs - prevEndMs) / _minMs;
    if (gapMin < 0 || gapMin > _brickGapMin) return null;
  }

  if (guardRefuses(incoming.durationMin, expected.durationMin)) return null;

  final stamps = <String, String>{};
  for (final s in segments) {
    if (s.stampedSummaryId != null) {
      stamps['${s.order}'] = s.stampedSummaryId!;
    }
  }
  if (incoming.summaryId != null) {
    stamps['${expected.order}'] = incoming.summaryId!;
  }
  final allStamped = segments.every(
    (s) => s.order == expected.order || s.stampedSummaryId != null,
  );
  return MatchDecision(
    gate: allStamped ? 'brick-sequential' : 'brick-partial',
    action: 'complete',
    matchedRowId: brick.rowId,
    parentVerified: allStamped,
    legStamps: stamps,
  );
}

// ---------------------------------------------------------------------------
// Garmin sequence decision (twin of decideGarminSequence)
// ---------------------------------------------------------------------------

MatchDecision _decideGarminSequence(
  MatcherIncomingSequence incoming,
  List<MatcherCandidate> candidates,
) {
  final activities = [...incoming.activities]
    ..sort((a, b) => a.startMs.compareTo(b.startMs));

  if (incoming.parentMatchedRowId != null) {
    final brick = candidates
        .where((c) => c.rowId == incoming.parentMatchedRowId)
        .firstOrNull;
    if (brick?.segments != null) {
      final segments = [...brick!.segments!]
        ..sort((a, b) => a.order.compareTo(b.order));
      final endurance =
          segments.where((s) => s.sport != 'transition').toList();
      final stamps = <String, String>{};
      var position = 0;
      for (final child in activities) {
        if (position >= endurance.length) break;
        if (endurance[position].sport != child.sport) {
          return const MatchDecision(
            gate: 'brick-not-matched',
            action: 'per-activity-gates',
            parentVerified: false,
          );
        }
        if (child.summaryId != null) {
          stamps['${endurance[position].order}'] = child.summaryId!;
        }
        position++;
      }
      final allStamped = endurance.every(
        (s) =>
            stamps.containsKey('${s.order}') || s.stampedSummaryId != null,
      );
      return MatchDecision(
        gate: 'brick-children',
        action: 'complete',
        matchedRowId: brick.rowId,
        parentVerified: allStamped,
        legStamps: stamps,
      );
    }
  }

  final bricks = candidates.where(
    (c) =>
        c.sport == 'brick' &&
        _matchableStatuses.contains(c.status) &&
        !c.deletedAt &&
        c.segments != null,
  );
  for (final brick in bricks) {
    final segments = [...brick.segments!]
      ..sort((a, b) => a.order.compareTo(b.order));
    final endurance = segments.where((s) => s.sport != 'transition').toList();
    if (activities.length > endurance.length) continue;

    var ok = true;
    final stamps = <String, String>{};
    for (var i = 0; i < activities.length; i++) {
      final leg = activities[i];
      final segment = endurance[i];
      if (segment.sport != leg.sport) {
        ok = false;
        break;
      }
      if (i == 0) {
        if (brick.slotMs != null &&
            !_sameLocalDay(brick.slotMs!, leg.startMs)) {
          ok = false;
          break;
        }
      } else {
        final prev = activities[i - 1];
        final gapMin =
            (leg.startMs - (prev.startMs + prev.durationMin * _minMs)) /
                _minMs;
        if (gapMin < 0 || gapMin > _brickGapMin) {
          ok = false;
          break;
        }
      }
      if (guardRefuses(leg.durationMin, segment.durationMin)) {
        ok = false;
        break;
      }
      if (leg.summaryId != null) {
        stamps['${segment.order}'] = leg.summaryId!;
      }
    }

    if (!ok) continue;

    final allMatched = activities.length == endurance.length;
    return MatchDecision(
      gate: allMatched ? 'brick-sequential' : 'brick-partial',
      action: 'complete',
      matchedRowId: brick.rowId,
      parentVerified: allMatched,
      legStamps: stamps,
    );
  }

  return const MatchDecision(
    gate: 'brick-not-matched',
    action: 'per-activity-gates',
    parentVerified: false,
  );
}

// ---------------------------------------------------------------------------
// Keyed platform signals (twin of decideKeyed)
// ---------------------------------------------------------------------------

MatchDecision _decideKeyed(
  MatcherIncomingKeyed incoming,
  List<MatcherCandidate> candidates,
) {
  final keyed = candidates
      .where((c) => c.providerWorkoutId == incoming.planId)
      .firstOrNull;

  if (keyed == null) {
    return MatchDecision(
      gate: 'insert',
      action: 'insert',
      insertedSport: incoming.sport,
    );
  }

  if (keyed.status == 'deleted') {
    if (incoming.signalKind == KeyedSignalKind.completion) {
      return MatchDecision(
        gate: 'keyed-over-tombstone',
        action: 'revive-complete',
        matchedRowId: keyed.rowId,
      );
    }
    return const MatchDecision(gate: 'tombstone-T1', action: 'drop');
  }

  if (_matchableStatuses.contains(keyed.status)) {
    return MatchDecision(
      gate: 'platform-keyed',
      action: 'complete',
      matchedRowId: keyed.rowId,
    );
  }

  if (keyed.status == 'completed') {
    if (_signatureMatches(
      incoming.startMs,
      incoming.durationMin,
      keyed.matchedStartMs,
      keyed.recordedDurationMin,
    )) {
      return MatchDecision(
        gate: 'verify-confirm',
        action: 'noop',
        matchedRowId: keyed.rowId,
      );
    }
    final displacedStartMs = keyed.matchedStartMs;
    final displacedDurationMin = keyed.recordedDurationMin;
    String? displacedRescoredTo;
    if (displacedStartMs != null && displacedDurationMin != null) {
      final open = candidates
          .where(
            (c) =>
                c.rowId != keyed.rowId &&
                (c.status == 'planned' || c.status == 'draft') &&
                c.sport == keyed.sport &&
                !c.deletedAt &&
                c.slotMs != null &&
                _sameLocalDay(c.slotMs!, displacedStartMs) &&
                !guardRefuses(displacedDurationMin, c.plannedDurationMin),
          )
          .toList();
      if (open.isNotEmpty) {
        displacedRescoredTo =
            _pickBestFit(open, displacedStartMs, displacedDurationMin).rowId;
      }
    }
    return MatchDecision(
      gate: 'revert-rebind',
      action: 'rebind',
      reboundPlanId: incoming.planId,
      displacedRescoredTo: displacedRescoredTo,
    );
  }

  return MatchDecision(
    gate: 'insert',
    action: 'insert',
    insertedSport: incoming.sport,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
