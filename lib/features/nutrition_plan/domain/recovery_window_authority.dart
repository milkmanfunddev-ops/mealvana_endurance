/// Recovery-window authority — `docs/ssot/spec/fueling/post-workout.md`
/// (RATIFIED v1, Xuan, 2026-08-13).
///
/// The SSOT has no engine yet; this carries only what decides how long the
/// time right after a session matters. How urgently to refuel turns on one
/// variable, the time to the next fuel-demanding session:
/// * **Urgent** (`POST_URGENT_THRESHOLD_H`: under 8 h): carbs through the next
///   `POST_URGENT_DURATION_H`, 4 h, starting as soon as practical.
/// * **Relaxed** (8 h or more, or unknown): no carb timing. The one timed item
///   is the protein dose within `POST_PROTEIN_WINDOW_H`, 2 h, which applies in
///   both branches. The relaxed branch's "first meal within ~2 h" is a habit
///   anchor and must never be presented as a window: copy for this branch
///   carries no deadline.
///
/// The 8–24 h band (§6 Q1, `[design]`) follows the relaxed branch with copy
/// softened toward "earlier rather than later today".
///
/// Only a fuel-demanding session opens either branch (§6 Q2): an endurance
/// session of 60 min or more. A strength-only hour does not.
///
/// No grams here. The urgent branch redistributes the day's total in time and
/// adds nothing to it (§5).
library;

import '../../../shared/domain/activity_type.dart';

/// `POST_URGENT_THRESHOLD_H`: below this to the next fuel-demanding session,
/// the urgent branch applies.
const recoveryUrgentThreshold = Duration(hours: 8);

/// `POST_URGENT_DURATION_H`: how long the urgent branch keeps carbs coming.
const recoveryUrgentDuration = Duration(hours: 4);

/// `POST_PROTEIN_WINDOW_H`: the protein dose lands within this, both branches.
const recoveryProteinWindow = Duration(hours: 2);

/// §6 Q2: the shortest endurance session that counts as fuel-demanding.
const fuelDemandingSessionMinutes = 60;

/// §6 Q1: up to this far to the next fuel-demanding session, a relaxed
/// recovery's copy is softened. The literature contrasts under 8 h with
/// about 24 h and is silent between.
const recoverySoftenedUntil = Duration(hours: 24);

enum RecoveryBranch { urgent, relaxed }

/// The branch for a session that ends [toNextSession] before the next
/// fuel-demanding one; null (none known) is relaxed, deliberately.
RecoveryBranch recoveryBranch(Duration? toNextSession) =>
    toNextSession != null && toNextSession < recoveryUrgentThreshold
    ? RecoveryBranch.urgent
    : RecoveryBranch.relaxed;

/// Whether a relaxed recovery's copy leans toward "earlier rather than later
/// today": the next fuel-demanding session is 8 to under 24 h away.
bool recoveryCopySoftened(Duration? toNextSession) =>
    toNextSession != null &&
    recoveryBranch(toNextSession) == RecoveryBranch.relaxed &&
    toNextSession < recoverySoftenedUntil;

/// How long after the session its recovery guidance is timed: the urgent
/// refeeding window, else the protein window.
Duration recoveryWindow(RecoveryBranch branch) => switch (branch) {
  RecoveryBranch.urgent => recoveryUrgentDuration,
  RecoveryBranch.relaxed => recoveryProteinWindow,
};

/// §6 Q2: an endurance session of [fuelDemandingSessionMinutes] or more. Every
/// type an athlete can plan is an endurance sport; the import-only catch-all
/// (strength, yoga, walking) is not. An unknown length is not evidence.
bool isFuelDemandingSession({
  required ActivityType type,
  required int? durationMinutes,
}) =>
    !type.isImportOnly &&
    durationMinutes != null &&
    durationMinutes >= fuelDemandingSessionMinutes;
