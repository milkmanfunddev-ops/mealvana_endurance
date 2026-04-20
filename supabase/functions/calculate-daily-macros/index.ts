/**
 * calculate-daily-macros Edge Function
 *
 * Daily macronutrient calculator for endurance athletes.
 * Implements 4-iteration algorithm:
 * - Iteration 1: Baseline RMR, TDEE, macros with session demands
 * - Iteration 2: Multi-day context (recovery, pre-load, weekly load, phase)
 * - Iteration 3: Dynamic NEAT + iterative TEF
 * - Iteration 4: Safety (EA check, multi-session compounding, carb cycling)
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import {
  errorResponse,
  jsonResponse,
  validationError,
  serverError,
} from '../_shared/responses.ts';
import type { DailyMacroInput, WeekMacroInput } from './types.ts';
import { validateInput, calculateDailyMacros, calculateWeekMacros } from './pipeline.ts';

/**
 * Main handler
 */
serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Only accept POST
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed. Use POST.', 405);
    }

    // Parse JSON body
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return validationError('Invalid JSON body');
    }

    // Week scope: batch 7 days in one call
    if (body.scope === 'week') {
      const weekInput = body as unknown as WeekMacroInput;

      if (!Array.isArray(weekInput.days) || weekInput.days.length === 0) {
        return validationError('week scope requires a non-empty "days" array');
      }

      // Validate each day by merging with shared profile fields
      for (let i = 0; i < weekInput.days.length; i++) {
        const merged: DailyMacroInput = {
          sex: weekInput.sex,
          age: weekInput.age,
          weight_kg: weekInput.weight_kg,
          height_cm: weekInput.height_cm,
          body_fat_pct: weekInput.body_fat_pct,
          lifestyle: weekInput.lifestyle,
          typical_weekly_hours: weekInput.typical_weekly_hours,
          carb_cycle_opt_in: weekInput.carb_cycle_opt_in,
          training_phase: weekInput.training_phase,
          mode: weekInput.mode,
          ...weekInput.days[i],
        };
        const err = validateInput(merged);
        if (err) {
          return validationError(`day ${i}: ${err}`);
        }
      }

      const results = calculateWeekMacros(weekInput);
      return jsonResponse({ days: results });
    }

    // Single-day scope (default)
    const input = body as unknown as DailyMacroInput;

    // Validate input
    const validationErr = validateInput(input);
    if (validationErr) {
      return validationError(validationErr);
    }

    // Calculate macros
    const result = calculateDailyMacros(input);

    return jsonResponse(result);
  } catch (error) {
    console.error('[CALCULATE_DAILY_MACROS_ERROR]', error);
    return serverError(error);
  }
});
