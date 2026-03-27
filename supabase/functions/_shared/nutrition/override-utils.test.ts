/**
 * Tests for adjustTargetsForOverrides
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';
import { adjustTargetsForOverrides, type MacroTargets } from './types.ts';

describe('adjustTargetsForOverrides', () => {
  const baseTargets: MacroTargets = {
    carbs_g: 360,
    carbs_low_g: 216,
    carbs_high_g: 324,
    sodium_mg: 1800,
    sodium_low_mg: 1440,
    sodium_high_mg: 1980,
    water_ml: 2400,
    water_low_ml: 1920,
    water_high_ml: 2640,
  };

  it('should return targets unchanged when no overrides', () => {
    const result = adjustTargetsForOverrides(baseTargets);
    assertEquals(result.carbs_high_g, 324);
    assertEquals(result.carbs_low_g, 216);
  });

  it('should expand carbs_high_g to include target when overridden above band', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      overrides: { carbs: true },
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.carbs_high_g, 360); // expanded from 324 to 360
    assertEquals(result.carbs_low_g, 216); // unchanged
  });

  it('should lower carbs_low_g to include target when overridden below band', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      carbs_g: 100, // below band low of 216
      overrides: { carbs: true },
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.carbs_low_g, 100); // lowered from 216 to 100
    assertEquals(result.carbs_high_g, 324); // unchanged
  });

  it('should not adjust carbs when target is within band', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      carbs_g: 270, // within [216, 324]
      overrides: { carbs: true },
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.carbs_high_g, 324); // unchanged
    assertEquals(result.carbs_low_g, 216); // unchanged
  });

  it('should not adjust carbs when override flag is not set', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      overrides: { sodium: true }, // only sodium overridden, not carbs
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.carbs_high_g, 324); // unchanged despite being outside band
  });

  it('should handle sodium overrides', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      sodium_mg: 2500, // above band high of 1980
      overrides: { sodium: true },
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.sodium_high_mg, 2500);
    assertEquals(result.sodium_low_mg, 1440); // unchanged
  });

  it('should handle water overrides', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      water_ml: 3000, // above band high of 2640
      overrides: { water: true },
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.water_high_ml, 3000);
  });

  it('should handle multiple overrides simultaneously', () => {
    const targets: MacroTargets = {
      ...baseTargets,
      carbs_g: 360,
      sodium_mg: 2500,
      overrides: { carbs: true, sodium: true },
    };
    const result = adjustTargetsForOverrides(targets);
    assertEquals(result.carbs_high_g, 360);
    assertEquals(result.sodium_high_mg, 2500);
  });

  it('should handle missing band values gracefully', () => {
    const targets: MacroTargets = {
      carbs_g: 360,
      sodium_mg: 1800,
      water_ml: 2400,
      overrides: { carbs: true },
    };
    const result = adjustTargetsForOverrides(targets);
    // No band values to adjust, should not crash
    assertEquals(result.carbs_g, 360);
    assertEquals(result.carbs_high_g, undefined);
  });

  it('should handle the exact bug scenario: 120g/hr override for 3h run', () => {
    // This is the exact case from the bug report:
    // User overrides carb rate to 120g/hr for a 3h run → 360g total
    // Band is derived from un-overridden rate: [72, 108] g/hr × 3h = [216, 324]
    const targets: MacroTargets = {
      carbs_g: 360,
      carbs_low_g: 216,
      carbs_high_g: 324,
      sodium_mg: 1800,
      water_ml: 2400,
      overrides: { carbs: true },
    };
    const result = adjustTargetsForOverrides(targets);
    // The solver should now be able to reach 360g
    assertEquals(result.carbs_high_g, 360);
    assertEquals(result.carbs_low_g, 216); // keep original low
  });
});
