/**
 * Session-level calculations: intensity factor, calorie cost, carb demand
 */

import type { SessionInput, Sport } from '../types.ts';

/**
 * Convert zone distribution to Intensity Factor using RMS
 * Formula: IF = sqrt(pct_conv × 0.68² + pct_tempo × 0.88² + pct_allout × 1.08²)
 *
 * Validation is part of the formula (F3, SSOT session-demand.md): the three
 * percentages must sum to 1.0 within float tolerance. Rejected, never
 * normalized — 0.70/0.20/0.20 and 0/0/0 both throw.
 */
export function zoneDistributionToIF(
  pct_conversational: number,
  pct_tempo: number,
  pct_allout: number,
): number {
  const sum = pct_conversational + pct_tempo + pct_allout;
  if (Math.abs(sum - 1.0) > 0.001) {
    throw new RangeError(
      `zone percentages must sum to 1.0 (got ${sum})`,
    );
  }

  const if_squared =
    pct_conversational * 0.68 * 0.68 +
    pct_tempo * 0.88 * 0.88 +
    pct_allout * 1.08 * 1.08;

  return Math.sqrt(if_squared);
}

/**
 * Calculate session calorie cost (F4 + F4a).
 * Weight is multiplied LAST so cost is exactly linear in body weight
 * (invariant I6: the 60:75:90 kg ratio is 0.800:1.000:1.200 exactly,
 * not within tolerance — floating-point ordering matters here).
 *
 * F4a (session-demand.md, RULED Xuan 2026-09-10; resolves the 2026-08-20
 * unknown-sport intake and REMOVES both the historical `?? 11` RUNNING
 * fallback and the interim strength-rate floor):
 *  - MOBILITY class (foam-rolling / stretching / yoga / aqua-routine):
 *    BASE_RATE 2.5 kcal·kg⁻¹·hr⁻¹, LINEAR in IF (like strength).
 *  - Composite types (triathlon/duathlon/brick/multisport): decompose by
 *    legs where supplied, else price as the dominant leg (CONVENTION:
 *    dominant = longest-duration leg, resolver-supplied). With neither,
 *    the session falls to the unknown rung.
 *  - Genuinely unknown sports contribute EXACTLY 0 kcal with a
 *    sources-style estimate flag (0 is a recommendation, not null).
 * Mirrored in daily_baseline_calculator.dart (D-005 twin discipline);
 * both pinned by the f4a-* rows of session-demand.json.
 */
export interface SessionCostLeg {
  sport: string;
  duration_hr: number;
  intensity_factor: number;
}

export interface SessionCostResult {
  kcal: number;
  /** True when the sport was genuinely unknown and the 0 is an estimate. */
  estimate_flag: boolean;
}

const SESSION_BASE_RATE: Record<string, number> = {
  running: 11,
  cycling: 9,
  swimming: 7,
  strength: 5,
  mobility: 2.5, // F4a
};

/** Sports whose cost is LINEAR in IF (everything else priced is quadratic). */
const LINEAR_IF_SPORTS = new Set(['strength', 'mobility']);

/** The F4a MOBILITY class members, verbatim from the ruling. */
const MOBILITY_SPORTS = new Set([
  'mobility',
  'foam_rolling',
  'stretching',
  'yoga',
  'aqua_routine',
]);

export const COMPOSITE_SPORTS = new Set([
  'triathlon',
  'duathlon',
  'brick',
  'multisport',
]);

export function sessionCostF4a(
  sport: Sport | string,
  duration_hr: number,
  intensity_factor: number,
  weight_kg: number,
  opts?: { legs?: SessionCostLeg[]; dominant_sport?: string },
): SessionCostResult {
  const normalized = MOBILITY_SPORTS.has(sport) ? 'mobility' : sport;

  if (COMPOSITE_SPORTS.has(normalized)) {
    const legs = opts?.legs;
    if (legs && legs.length > 0) {
      let kcal = 0;
      let estimate_flag = false;
      for (const leg of legs) {
        const r = sessionCostF4a(
          leg.sport,
          leg.duration_hr,
          leg.intensity_factor,
          weight_kg,
        );
        kcal += r.kcal;
        estimate_flag = estimate_flag || r.estimate_flag;
      }
      return { kcal, estimate_flag };
    }
    if (opts?.dominant_sport) {
      return sessionCostF4a(
        opts.dominant_sport,
        duration_hr,
        intensity_factor,
        weight_kg,
      );
    }
    // No legs and no resolvable dominant leg: the composite is unpriceable
    // without inventing a rate — the F4a unknown rung applies.
    return { kcal: 0, estimate_flag: true };
  }

  const rate = SESSION_BASE_RATE[normalized];
  if (rate === undefined) {
    // F4a: genuinely unknown sports contribute 0 with the estimate flag —
    // never a hidden fallback rate.
    console.warn(
      `sessionCost: unknown sport "${sport}" — F4a zero-with-estimate-flag ` +
        `(session-demand.md F4a, RULED 2026-09-10)`,
    );
    return { kcal: 0, estimate_flag: true };
  }

  if (LINEAR_IF_SPORTS.has(normalized)) {
    return {
      kcal: rate * (intensity_factor / 0.75) * duration_hr * weight_kg,
      estimate_flag: false,
    };
  }
  return {
    kcal: rate * Math.pow(intensity_factor / 0.75, 2) * duration_hr *
      weight_kg,
    estimate_flag: false,
  };
}

/** Numeric convenience over [sessionCostF4a] for call sites that only need
 * the kcal (an unknown sport reads as exactly 0 here — check the flag via
 * sessionCostF4a when the source attribution matters). */
export function sessionCost(
  sport: Sport | string,
  duration_hr: number,
  intensity_factor: number,
  weight_kg: number,
  opts?: { legs?: SessionCostLeg[]; dominant_sport?: string },
): number {
  return sessionCostF4a(sport, duration_hr, intensity_factor, weight_kg, opts)
    .kcal;
}

/**
 * Interpolate carb oxidation rate from IF using piecewise linear interpolation
 */
function carbOxidationRate(intensity_factor: number): number {
  // Anchor points: [IF, g/hr at 75kg reference]
  const anchors: [number, number][] = [
    [0.55, 25],
    [0.70, 40],
    [0.80, 55],
    [0.90, 75],
    [1.00, 95],
    [1.10, 115],
  ];

  // Below 0.55
  if (intensity_factor <= anchors[0][0]) {
    return anchors[0][1];
  }

  // Above 1.10
  if (intensity_factor >= anchors[anchors.length - 1][0]) {
    return anchors[anchors.length - 1][1];
  }

  // Find bounding points and interpolate
  for (let i = 0; i < anchors.length - 1; i++) {
    const [if_low, rate_low] = anchors[i];
    const [if_high, rate_high] = anchors[i + 1];

    if (intensity_factor >= if_low && intensity_factor <= if_high) {
      const t = (intensity_factor - if_low) / (if_high - if_low);
      return rate_low + t * (rate_high - rate_low);
    }
  }

  // Should never reach here
  return 60;
}

/**
 * Calculate carb demand for a session (F5).
 *
 * Strength branch (Q-003, ruled 2026-08-13): resistance-exercise glycogen
 * depletion tracks duration, not load, so strength uses a flat
 * 27 g/hr @ 75 kg rate — IF ignored, no long/intense multiplier.
 */
export function carbDemand(
  sport: Sport,
  intensity_factor: number,
  duration_hr: number,
  weight_kg: number,
): number {
  if (sport === 'strength') {
    return 27 * duration_hr * (weight_kg / 75);
  }

  // Step 1: Get carb oxidation rate (g/hr at 75kg reference)
  const rate_g_per_hr = carbOxidationRate(intensity_factor);

  // Step 2: Scale by duration and weight
  const raw = rate_g_per_hr * duration_hr * (weight_kg / 75);

  // Step 3: Apply multiplier for long or intense sessions (both strict)
  if (duration_hr > 1.5 || intensity_factor > 0.85) {
    return raw * 1.15;
  } else {
    return raw;
  }
}

/**
 * Process a single session to get its contribution
 */
export function processSession(
  session: SessionInput,
  weight_kg: number,
): {
  intensity_factor: number;
  session_kcal: number;
  session_carb: number;
} {
  const intensity_factor = zoneDistributionToIF(
    session.pct_conversational,
    session.pct_tempo,
    session.pct_allout,
  );

  const session_kcal = sessionCost(
    session.sport,
    session.duration_hr,
    intensity_factor,
    weight_kg,
  );

  const session_carb = carbDemand(
    session.sport,
    intensity_factor,
    session.duration_hr,
    weight_kg,
  );

  return { intensity_factor, session_kcal, session_carb };
}
