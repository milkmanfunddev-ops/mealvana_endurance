/**
 * Shared utility functions for Edge Functions
 */

/**
 * Safely convert a value to a number, returning a default if not finite
 */
export function safe(n: unknown, defaultValue = 0): number {
  return Number.isFinite(Number(n)) ? Number(n) : defaultValue;
}

/**
 * Round a value to the nearest increment (default 0.5)
 */
export function roundToIncrement(value: number, increment = 0.5): number {
  return Math.round(value / increment) * increment;
}

/**
 * Round up a value to the nearest increment
 */
export function roundUpToIncrement(value: number, increment = 0.5): number {
  if (value <= 0) return 0;
  return Math.ceil(value / increment) * increment;
}

/**
 * Clamp a value between min and max
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/**
 * Generate a UUID
 */
export function generateUUID(): string {
  return crypto.randomUUID();
}

/**
 * Parse JSON body from request with error handling
 */
export async function parseJsonBody<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    throw new Error('Invalid JSON body');
  }
}

/**
 * Check if a value is null or undefined
 */
export function isNullish(value: unknown): value is null | undefined {
  return value === null || value === undefined;
}

/**
 * Deep clone an object
 */
export function deepClone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}
