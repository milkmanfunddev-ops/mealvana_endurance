/**
 * Unit conversion constants and functions for nutrition calculations.
 */

export const LB_TO_KG = 0.45359237;
export const IN_TO_CM = 2.54;
export const MI_TO_KM = 1.60934;
export const MPH_TO_M_PER_MIN = 26.8224;

export function toKg(weight: number, unit: string): number {
  return unit === "kg" ? weight : weight * LB_TO_KG;
}

export function toCm(height: number, unit: string): number {
  return unit === "cm" ? height : height * IN_TO_CM;
}

export function toMiles(distance: number, unit: string): number {
  return unit === "mi" ? distance : distance / MI_TO_KM;
}
