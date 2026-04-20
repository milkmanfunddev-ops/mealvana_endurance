/**
 * Environment classification and sweat rate calculations based on Baker 2017.
 */

export function classifyEnvironment(
  tempC: number | null,
  humidityPct: number | null,
): [number, string] {
  if (tempC === null && humidityPct === null) return [1.0, "moderate"];
  const t = tempC ?? 20.0;
  const h = humidityPct ?? 60.0;
  if (t <= 10) return [0.85, "cool"];
  if (t <= 20 && h <= 60) return [1.0, "temperate"];
  if (t <= 25 || (h > 60 && h <= 75)) return [1.1, "warm"];
  if (t <= 30 || (h > 75 && h <= 85)) return [1.2, "hot"];
  return [1.3, "very_hot"];
}

export function baseSweatRateFromCategory(category: string): number {
  if (category === "light") return 0.75;
  if (category === "medium") return 1.25;
  if (category === "heavy") return 2.0;
  return 1.25;
}

export function sodiumConcentrationFromCategory(category: string): number {
  if (category === "low") return 550;
  if (category === "medium") return 925;
  if (category === "high") return 1150;
  return 925;
}

export function calculateActualSweatRate(
  baseCategory: string,
  tempC: number | null,
  _humidityPct: number | null,
): number {
  const baseRate = baseSweatRateFromCategory(baseCategory);
  let tempAdjustment = 1.0;
  if (tempC !== null && tempC > 20) {
    tempAdjustment = 1.0 + Math.max(0, (tempC - 20) * 0.04);
  }
  return baseRate * tempAdjustment;
}
