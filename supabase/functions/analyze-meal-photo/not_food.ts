/**
 * analyze-meal-photo's not-food answer (develop-2026-10 ticket 55, 49-005).
 *
 * The same wire shape describe-meal sends (`errorResponse(msg, 422,
 * undefined, { not_food: true })`), so the client has one rule for both
 * functions: a 422 with `not_food: true` is the athlete's turn, noted and
 * counted, never reported as degraded. A 422 without the flag still reports.
 * Its own module so the test can call it without starting the server.
 */

import { errorResponse } from "../_shared/responses.ts";

export const NOT_FOOD_MESSAGE =
  "The photo doesn't appear to contain food. Please try a different image.";

export function notFoodResponse(): Response {
  return errorResponse(NOT_FOOD_MESSAGE, 422, undefined, { not_food: true });
}
