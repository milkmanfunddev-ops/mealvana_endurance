/// Fueling-window authority — `docs/ssot/spec/fueling/food-recommendation.md`
/// §3/§3a (RATIFIED Xuan, 2026-09-03).
///
/// The ratified timing TABLE provides the default pre-workout fueling window
/// (user-adjustable within the clamp); the sport-specific
/// `recommendedHoursBefore` formula is RETIRED in its favour (§3a supersedes
/// the run 0.25–3.5 h / bike 0.25–3.0 / swim 0.5–2.5 ranges — the table's
/// session classes are sport-neutral).
///
/// Rules carried here, all ruled 2026-09-03 unless noted:
/// * §3a table: race/key 180 · ≥2.5 h 180 · 1.5–2.5 h 150 · 60–90 moderate+
///   120 · 60–90 easy 60 · <60 min 45.
/// * Early-start overlay: a TRAINING session starting strictly before 07:00
///   drops the default to 60 min (never raises it); races keep the table
///   default regardless of start time.
/// * Clamp (§3, RULED 2026-09-02 db654def): the window is capped at the
///   actual minutes remaining before start, floor 15 — a tier whose minimum
///   window exceeds the remaining gap is NOT offered, never scheduled in the
///   past (closes F-38).
/// * Intensity nudge mapping: the Long preset ⇒ +1 row; Race Pace ⇒ the race
///   row directly; all other presets ⇒ no nudge.
/// * Active tiers derive from the ratified thresholds (meal ≥ 120 min,
///   snack ≥ 30 min, top-up always).
///
/// TS twin: `supabase/functions/_shared/nutrition/fueling-window.ts` (§8 twin
/// contract — every rule binds both engines).
library;

import 'intensity_distribution.dart';
import 'workout_preset.dart';

/// §3a session classes (sport-neutral). Wire names match the ratified vector
/// file `docs/ssot/vectors/fueling/food-recommendation.json`.
enum FuelingSessionClass {
  race('race'),
  longSession('long>=2.5h'),
  midSession('mid1.5-2.5h'),
  moderate60to90('60-90-moderate'),
  easy60to90('60-90-easy'),
  under60('<60');

  const FuelingSessionClass(this.wireName);
  final String wireName;

  static FuelingSessionClass fromWire(String wire) =>
      values.firstWhere((c) => c.wireName == wire,
          orElse: () =>
              throw ArgumentError.value(wire, 'wire', 'unknown session class'));
}

/// Training sessions starting strictly before this hour take the early-start
/// overlay (the boundary is exclusive: a 07:00 start keeps the table default).
const int kEarlyStartHourExclusive = 7;

/// Early-start fallback window (snack tier — the literature's own fallback).
const int kEarlyStartWindowMin = 60;

/// Clamp floor: the window never drops below this, even closer to the start.
const int kFuelingWindowFloorMin = 15;

/// Ratified tier thresholds (carbs v2; mirrored by the v4 engine's
/// TIER_MEAL_MIN / TIER_TOPOFF_MAX — deliberately restated here so a wrong
/// engine constant cannot agree with itself).
const int kTierMealMinMin = 120;
const int kTierSnackMinMin = 30;

/// §3a table default, before the early-start overlay and clamp.
int tableDefaultWindowMin(FuelingSessionClass sessionClass) =>
    switch (sessionClass) {
      FuelingSessionClass.race => 180,
      FuelingSessionClass.longSession => 180,
      FuelingSessionClass.midSession => 150,
      FuelingSessionClass.moderate60to90 => 120,
      FuelingSessionClass.easy60to90 => 60,
      FuelingSessionClass.under60 => 45,
    };

/// The resolved default window plus the tiers reachable inside it.
class FuelingWindowResolution {
  const FuelingWindowResolution({
    required this.windowMin,
    required this.activePhases,
  });

  /// Default window in minutes (post early-start overlay, post clamp).
  final int windowMin;

  /// Tiers whose minimum window fits inside [windowMin], in meal → snack →
  /// top_up order. Top-up is always reachable.
  final List<String> activePhases;
}

/// Resolve the §3a default window for a session.
///
/// [minutesUntilStart] is the real gap between "now" (plan-creation time) and
/// the session start; pass a large value when the session is far out.
FuelingWindowResolution resolveFuelingWindow({
  required FuelingSessionClass sessionClass,
  required int startHour,
  required bool isRace,
  required int minutesUntilStart,
}) {
  var window = tableDefaultWindowMin(sessionClass);

  // Early-start overlay: training before 07:00 drops to the snack-tier
  // window; never raises a smaller default. Races are exempt.
  if (!isRace && startHour < kEarlyStartHourExclusive) {
    window = window < kEarlyStartWindowMin ? window : kEarlyStartWindowMin;
  }

  // Clamp to the time actually remaining, floor 15.
  if (minutesUntilStart < window) window = minutesUntilStart;
  if (window < kFuelingWindowFloorMin) window = kFuelingWindowFloorMin;

  return FuelingWindowResolution(
    windowMin: window,
    activePhases: [
      if (window >= kTierMealMinMin) 'meal',
      if (window >= kTierSnackMinMin) 'snack',
      'top_up',
    ],
  );
}

/// One row up the table (§3a note: "intensity nudges one row up"). The race
/// and long rows are already the top.
FuelingSessionClass nudgeOneRowUp(FuelingSessionClass c) => switch (c) {
      FuelingSessionClass.under60 => FuelingSessionClass.easy60to90,
      FuelingSessionClass.easy60to90 => FuelingSessionClass.moderate60to90,
      FuelingSessionClass.moderate60to90 => FuelingSessionClass.midSession,
      FuelingSessionClass.midSession => FuelingSessionClass.longSession,
      _ => c,
    };

/// Recover the preset a distribution came from, if it exactly matches one
/// (the preset chips write these exact distributions; a hand-tuned slider
/// matches nothing and takes no nudge).
WorkoutPreset? presetForDistribution(IntensityDistribution d) {
  for (final entry in WorkoutPresetData.presetDistributions.entries) {
    final p = entry.value;
    if (p.conversationalPct == d.conversationalPct &&
        p.tempoPct == d.tempoPct &&
        p.allOutPct == d.allOutPct) {
      return entry.key;
    }
  }
  return null;
}

/// Classify a session onto the §3a table from what the create flow knows.
///
/// Duration decides the base row; the ruled preset mapping applies on top
/// (Long ⇒ +1 row · Race Pace ⇒ race row · others none). The 60–90 easy/
/// moderate split: the easy and recovery presets (and, for hand-tuned or
/// default distributions, a conversational share ≥ 70 %) read as easy.
FuelingSessionClass classifySession({
  required int durationMinutes,
  required IntensityDistribution intensity,
}) {
  final preset = presetForDistribution(intensity);
  if (preset == WorkoutPreset.racePace) return FuelingSessionClass.race;

  final FuelingSessionClass base;
  if (durationMinutes >= 150) {
    base = FuelingSessionClass.longSession;
  } else if (durationMinutes >= 90) {
    base = FuelingSessionClass.midSession;
  } else if (durationMinutes >= 60) {
    final easy = preset == WorkoutPreset.easy ||
        preset == WorkoutPreset.recovery ||
        (preset == null && intensity.conversationalPct >= 70);
    base = easy
        ? FuelingSessionClass.easy60to90
        : FuelingSessionClass.moderate60to90;
  } else {
    base = FuelingSessionClass.under60;
  }

  return preset == WorkoutPreset.long ? nudgeOneRowUp(base) : base;
}

/// Convenience for the create-flow controllers: the §3a default in minutes
/// for a session, replacing the retired `recommendedHoursBefore` at its four
/// call sites (running, cycling, swimming, brick).
int defaultFuelingWindowMinutes({
  required int durationMinutes,
  required IntensityDistribution intensity,
  required int startHour,
  required int minutesUntilStart,
}) {
  final sessionClass = classifySession(
    durationMinutes: durationMinutes,
    intensity: intensity,
  );
  return resolveFuelingWindow(
    sessionClass: sessionClass,
    startHour: startHour,
    isRace: sessionClass == FuelingSessionClass.race,
    minutesUntilStart: minutesUntilStart,
  ).windowMin;
}
