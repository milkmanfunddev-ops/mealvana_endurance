/**
 * Jade chat tool set — service-role data fetchers + logBaselineMeal writer.
 *
 * All tools are scoped to the authenticated user's id. Descriptions are kept
 * concise so the model picks the right tool without ambiguity.
 *
 * AI SDK v6 API (npm:ai@6): tool({ description, inputSchema, execute })
 * Parameters use Zod schemas.
 *
 * Factory: makeJadeTools(ctx) closes over the service-role client, userId,
 * timezone, and optional location so every execute() has what it needs without
 * passing arguments through the AI SDK call.
 */

import { tool } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { getInSeasonProduce } from './in_season.ts';

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------

export interface JadeToolContext {
  serviceClient: SupabaseClient;
  userId: string;
  /** IANA timezone string, e.g. "America/Chicago". Used for day-boundary logic. */
  timezone: string;
  /** Optional — required for getWeather. Sourced from request body. */
  location?: { latitude: number; longitude: number };
}

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

/** Returns an ISO date string for "today" in the given IANA timezone. */
function todayInTz(timezone: string): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(new Date());
  } catch {
    return new Date().toISOString().slice(0, 10);
  }
}

/** Adds `days` days to an ISO date string and returns the result as ISO date. */
function addDays(isoDate: string, days: number): string {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

export function makeJadeTools(ctx: JadeToolContext) {
  const { serviceClient, userId, timezone, location } = ctx;

  return {

    // ── 1. getUserProfile ───────────────────────────────────────────────────

    getUserProfile: tool({
      description:
        "Fetch the user's profile: biometrics (weight, height, body fat), gender, " +
        "age (birthday), dietary preference, allergies, gut training level, and " +
        "athletic performance markers (cycling FTP, swim CSS). Also fetches their " +
        "explicit food preferences (liked/disliked foods).",
      inputSchema: z.object({}),
      execute: async () => {
        const [profileRes, prefsRes] = await Promise.all([
          serviceClient
            .from('users')
            .select(
              'id, gender, birthday, height_feet, height_inches, weight_pounds, ' +
              'body_fat_pct, dietary_preference, allergies, gut_training_level, ' +
              'cycling_ftp_watts, swimming_css_seconds_per_100m, runs_with_water_bottle',
            )
            .eq('id', userId)
            .maybeSingle(),
          serviceClient
            .from('food_preferences')
            .select('food_name, preference, preference_level')
            .eq('user_id', userId)
            .order('preference_level', { ascending: false }),
        ]);

        if (profileRes.error) {
          console.error('[jade-chat/getUserProfile] profile error:', profileRes.error);
        }
        if (prefsRes.error) {
          console.error('[jade-chat/getUserProfile] prefs error:', prefsRes.error);
        }

        return {
          profile: profileRes.data ?? null,
          food_preferences: prefsRes.data ?? [],
        };
      },
    }),

    // ── 2. getMacroTargets ──────────────────────────────────────────────────

    getMacroTargets: tool({
      description:
        "Fetch the user's calculated daily macro targets (carb_g, prot_g, fat_g, " +
        "tdee, session_kcal) for a date range. Use this to understand what the user " +
        "should be eating on specific days, especially around training.",
      inputSchema: z.object({
        start_date: z.string().describe('ISO date YYYY-MM-DD (inclusive)'),
        end_date: z.string().describe('ISO date YYYY-MM-DD (inclusive)'),
      }),
      execute: async ({ start_date, end_date }) => {
        const { data, error } = await serviceClient
          .from('daily_macro_targets')
          .select('target_date, carb_g, prot_g, fat_g, tdee, session_kcal, rmr, mode, ea_status')
          .eq('user_id', userId)
          .gte('target_date', start_date)
          .lte('target_date', end_date)
          .order('target_date');

        if (error) {
          console.error('[jade-chat/getMacroTargets] error:', error);
          return { error: error.message, data: [] };
        }
        return { data: data ?? [] };
      },
    }),

    // ── 3. getWorkouts ──────────────────────────────────────────────────────

    getWorkouts: tool({
      description:
        "Fetch the user's planned and completed workouts for a date range. " +
        'Use direction="upcoming" for future workouts (default) or direction="recent" ' +
        "for past workouts. Useful for fueling advice, recovery context, or referencing " +
        "what training is coming up.",
      inputSchema: z.object({
        direction: z
          .enum(['upcoming', 'recent'])
          .default('upcoming')
          .describe('"upcoming" = today + future days; "recent" = past days up to today'),
        days: z
          .number()
          .int()
          .min(1)
          .max(30)
          .default(7)
          .describe('Number of days to look ahead (upcoming) or back (recent)'),
      }),
      execute: async ({ direction, days }) => {
        const today = todayInTz(timezone);
        let startDate: string;
        let endDate: string;

        if (direction === 'upcoming') {
          startDate = today;
          endDate = addDays(today, days);
        } else {
          startDate = addDays(today, -days);
          endDate = today;
        }

        const { data, error } = await serviceClient
          .from('activities')
          .select(
            'id, title, activity_type, scheduled_date_time, status, ' +
            'duration_minutes, distance_miles, intensity_level, ' +
            'actual_duration_minutes, actual_distance_miles, calories_burned',
          )
          .eq('user_id', userId)
          .is('deleted_at', null)
          .gte('scheduled_date_time', `${startDate}T00:00:00`)
          .lte('scheduled_date_time', `${endDate}T23:59:59`)
          .order('scheduled_date_time');

        if (error) {
          console.error('[jade-chat/getWorkouts] error:', error);
          return { error: error.message, data: [] };
        }
        return { data: data ?? [], date_range: { start: startDate, end: endDate } };
      },
    }),

    // ── 4. getUpcomingEvents ────────────────────────────────────────────────

    getUpcomingEvents: tool({
      description:
        "Fetch the user's upcoming races and events. Useful for race-day fueling " +
        "advice, taper nutrition, and carb-loading guidance.",
      inputSchema: z.object({
        days_ahead: z
          .number()
          .int()
          .min(1)
          .max(365)
          .default(90)
          .describe('How many days ahead to look for events'),
      }),
      execute: async ({ days_ahead }) => {
        const today = todayInTz(timezone);
        const futureDate = addDays(today, days_ahead);

        const { data, error } = await serviceClient
          .from('events')
          .select(
            'id, event_name, event_type, event_date, event_subtype, ' +
            'location, goal_time_minutes, has_carb_loading, carb_loading_days, ' +
            'carb_loading_start_date',
          )
          .eq('user_id', userId)
          .gte('event_date', today)
          .lte('event_date', futureDate)
          .order('event_date');

        if (error) {
          console.error('[jade-chat/getUpcomingEvents] error:', error);
          return { error: error.message, data: [] };
        }
        return { data: data ?? [] };
      },
    }),

    // ── 5. getLoggedMeals ───────────────────────────────────────────────────

    getLoggedMeals: tool({
      description:
        "Fetch the user's logged meals for a date range. Returns meal name, slot, " +
        "macros (calories, carbs_g, protein_g, fat_g), source, and items breakdown. " +
        "Use this to review what the user has been eating, identify patterns, or " +
        "give feedback on a specific day.",
      inputSchema: z.object({
        start_date: z.string().describe('ISO date YYYY-MM-DD (inclusive)'),
        end_date: z.string().describe('ISO date YYYY-MM-DD (inclusive)'),
      }),
      execute: async ({ start_date, end_date }) => {
        const { data, error } = await serviceClient
          .from('meal_logs')
          .select(
            'id, log_date, slot, name, source, calories, carbs_g, protein_g, ' +
            'fat_g, sodium_mg, items, notes, eaten_at',
          )
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .gte('log_date', start_date)
          .lte('log_date', end_date)
          .order('log_date')
          .order('eaten_at', { ascending: true, nullsFirst: true });

        if (error) {
          console.error('[jade-chat/getLoggedMeals] error:', error);
          return { error: error.message, data: [] };
        }
        return { data: data ?? [] };
      },
    }),

    // ── 6. getWeather ───────────────────────────────────────────────────────

    getWeather: tool({
      description:
        "Fetch a 7-day weather forecast for the user's location using Open-Meteo " +
        "(no API key required). Returns daily high/low temps (°F), precipitation " +
        "probability, and a hydration advisory when conditions warrant it. " +
        "Useful for heat/cold fueling adjustments. Returns { available: false } " +
        "if no location was provided in the request.",
      inputSchema: z.object({
        days: z
          .number()
          .int()
          .min(1)
          .max(7)
          .default(7)
          .describe('Number of forecast days to return'),
      }),
      execute: async ({ days }) => {
        if (!location) {
          return { available: false, reason: 'no location provided in request' };
        }

        try {
          const url =
            `https://api.open-meteo.com/v1/forecast` +
            `?latitude=${location.latitude}&longitude=${location.longitude}` +
            `&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max` +
            `&temperature_unit=fahrenheit` +
            `&timezone=${encodeURIComponent(timezone)}` +
            `&forecast_days=${days}`;

          const res = await fetch(url);
          if (!res.ok) {
            console.warn('[jade-chat/getWeather] Open-Meteo responded:', res.status);
            return { available: false, reason: `weather service error (${res.status})` };
          }

          const json = await res.json();
          const dates: string[] = json.daily?.time ?? [];
          const maxTemps: number[] = json.daily?.temperature_2m_max ?? [];
          const minTemps: number[] = json.daily?.temperature_2m_min ?? [];
          const precipPcts: number[] = json.daily?.precipitation_probability_max ?? [];

          const forecast = dates.map((date: string, i: number) => {
            const high = maxTemps[i] ?? null;
            const advisory =
              high !== null && high > 85
                ? 'Heat advisory: increase fluid intake ~8–12 oz/hr vs baseline'
                : high !== null && high < 35
                  ? 'Cold advisory: fuel early — perceived effort rises, appetite may drop'
                  : null;
            return {
              date,
              temp_high_f: high,
              temp_low_f: minTemps[i] ?? null,
              precip_pct: precipPcts[i] ?? null,
              advisory,
            };
          });

          return { available: true, forecast };
        } catch (err) {
          console.error('[jade-chat/getWeather] fetch error:', err);
          return { available: false, reason: 'weather fetch failed' };
        }
      },
    }),

    // ── 7. getInSeasonProduce ───────────────────────────────────────────────

    getInSeasonProduce: tool({
      description:
        "Returns produce items at peak quality and lowest cost this month " +
        "(northern hemisphere US default). Useful for budget-friendly meal suggestions, " +
        "grocery guidance, and whole-food fueling recommendations.",
      inputSchema: z.object({
        month: z
          .number()
          .int()
          .min(1)
          .max(12)
          .optional()
          .describe('Month number (1–12). Defaults to the current month.'),
      }),
      execute: async ({ month }) => {
        return getInSeasonProduce(month);
      },
    }),

    // ── 8. getSalesNearby ───────────────────────────────────────────────────

    getSalesNearby: tool({
      description:
        "Checks for grocery store sales near the user's location relevant to " +
        "endurance fueling (produce, protein, carbs). Currently returns a stub — " +
        "use it to acknowledge the user asked, then offer other budget suggestions.",
      inputSchema: z.object({
        query: z
          .string()
          .optional()
          .describe('Optional search term, e.g. "chicken", "pasta", "bananas"'),
      }),
      execute: async (_args) => {
        // TODO: Integrate Flipp endpoint when Lee provides access credentials.
        // Endpoint: https://cdn-gateflipp.flippback.com/bf/flipp/items/search
        // Params: postal_code (reverse-geocode from location), q (search query)
        // Ref: Mealvana Endurance — grocery sales integration backlog
        return {
          available: false,
          reason: 'sales data not configured yet — coming soon',
        };
      },
    }),

    // ── 9. logBaselineMeal ──────────────────────────────────────────────────

    logBaselineMeal: tool({
      description:
        "Insert a meal_logs row to record a typical/baseline meal the user described " +
        "in chat. Use source 'jade_baseline'. One call per meal slot. " +
        "Derive total calories/macros by summing item values when items are provided. " +
        "After inserting, confirm what you logged in one concise sentence.",
      inputSchema: z.object({
        name: z.string().describe('Short display title, e.g. "Oatmeal with banana and peanut butter"'),
        slot: z.enum(['breakfast', 'lunch', 'dinner', 'snack']).describe('Meal slot'),
        log_date: z
          .string()
          .describe('ISO date YYYY-MM-DD for the log entry (use today or yesterday as appropriate)'),
        items: z
          .array(
            z.object({
              name: z.string(),
              portion: z.string().optional(),
              calories: z.number().int().nonnegative().optional(),
              carb_g: z.number().nonnegative().optional(),
              protein_g: z.number().nonnegative().optional(),
              fat_g: z.number().nonnegative().optional(),
              sodium_mg: z.number().nonnegative().optional(),
            }),
          )
          .optional()
          .describe('Food components. Provide macros when you can estimate them.'),
        calories: z
          .number()
          .int()
          .nonnegative()
          .optional()
          .describe('Total calories — computed from items if omitted'),
        carbs_g: z.number().nonnegative().optional(),
        protein_g: z.number().nonnegative().optional(),
        fat_g: z.number().nonnegative().optional(),
        sodium_mg: z.number().nonnegative().optional(),
      }),
      execute: async ({ name, slot, log_date, items, calories, carbs_g, protein_g, fat_g, sodium_mg }) => {
        // Derive totals from items when top-level values are absent
        const derivedCalories =
          calories ?? (items ? items.reduce((sum, item) => sum + (item.calories ?? 0), 0) : undefined);
        const derivedCarbs =
          carbs_g ?? (items ? items.reduce((sum, item) => sum + (item.carb_g ?? 0), 0) : undefined);
        const derivedProtein =
          protein_g ?? (items ? items.reduce((sum, item) => sum + (item.protein_g ?? 0), 0) : undefined);
        const derivedFat =
          fat_g ?? (items ? items.reduce((sum, item) => sum + (item.fat_g ?? 0), 0) : undefined);
        const derivedSodium =
          sodium_mg ?? (items ? items.reduce((sum, item) => sum + (item.sodium_mg ?? 0), 0) : undefined);

        const { data, error } = await serviceClient
          .from('meal_logs')
          .insert({
            user_id: userId,
            name,
            slot,
            log_date,
            source: 'jade_baseline',
            items: items ? JSON.stringify(items) : '[]',
            calories: derivedCalories ?? null,
            carbs_g: derivedCarbs ?? null,
            protein_g: derivedProtein ?? null,
            fat_g: derivedFat ?? null,
            sodium_mg: derivedSodium ?? null,
            notes: 'Recorded by Jade from chat',
            is_deleted: false,
          })
          .select('id')
          .single();

        if (error) {
          console.error('[jade-chat/logBaselineMeal] insert error:', error);
          return { success: false, error: error.message };
        }

        return {
          success: true,
          id: data.id,
          confirmation: `Logged ${slot}: "${name}" on ${log_date}.`,
        };
      },
    }),

  } as const;
}

/** Convenience type — the return value of makeJadeTools */
export type JadeTools = ReturnType<typeof makeJadeTools>;
