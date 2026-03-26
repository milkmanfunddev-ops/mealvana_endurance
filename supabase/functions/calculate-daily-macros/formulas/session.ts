/**
 * Session-level calculations: intensity factor, calorie cost, carb demand
 */

import type { SessionInput, Sport } from '../types.ts';

/**
 * Convert zone distribution to Intensity Factor using RMS
 * Formula: IF = sqrt(pct_conv × 0.68² + pct_tempo × 0.88² + pct_allout × 1.08²)
 */
export function zoneDistributionToIF(
  pct_conversational: number,
  pct_tempo: number,
  pct_allout: number,
): number {
  const if_squared =
    pct_conversational * 0.68 * 0.68 +
    pct_tempo * 0.88 * 0.88 +
    pct_allout * 1.08 * 1.08;

  return Math.sqrt(if_squared);
}

/**
 * Calculate session calorie cost
 */
export function sessionCost(
  sport: Sport,
  duration_hr: number,
  intensity_factor: number,
  weight_kg: number,
): number {
  const BASE_RATE: Record<Sport, number> = {
    running: 11,
    cycling: 9,
    swimming: 7,
    strength: 5,
  };

  const base = BASE_RATE[sport] * weight_kg;

  if (sport === 'strength') {
    // Strength: linear with IF
    return base * (intensity_factor / 0.75) * duration_hr;
  } else {
    // Endurance sports: quadratic with IF
    return base * Math.pow(intensity_factor / 0.75, 2) * duration_hr;
  }
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
 * Calculate carb demand for a session
 */
export function carbDemand(
  intensity_factor: number,
  duration_hr: number,
  weight_kg: number,
): number {
  // Step 1: Get carb oxidation rate (g/hr at 75kg reference)
  const rate_g_per_hr = carbOxidationRate(intensity_factor);

  // Step 2: Scale by duration and weight
  const raw = rate_g_per_hr * duration_hr * (weight_kg / 75);

  // Step 3: Apply multiplier for long or intense sessions
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
    intensity_factor,
    session.duration_hr,
    weight_kg,
  );

  return { intensity_factor, session_kcal, session_carb };
}
