/**
 * Input and output types for calculate-daily-macros edge function
 */

export type Sex = 'male' | 'female';
export type Sport = 'running' | 'cycling' | 'swimming' | 'strength';
export type Lifestyle = 'desk' | 'mixed' | 'active' | 'very_active';
export type TrainingPhase = 'base' | 'build' | 'peak' | 'taper' | 'race_week' | 'off_season';
export type Mode = 'prospective' | 'retrospective';

export interface SessionInput {
  sport: Sport;
  duration_hr: number;
  pct_conversational: number;
  pct_tempo: number;
  pct_allout: number;
  tss?: number | null;
  /**
   * Activity row id used by the server to look up per-session Garmin
   * completion data (calories_burned, actual_duration_minutes) and produce
   * a GarminActivityForSession passed into the resolver.
   */
  activity_id?: string | null;
}

/** Per-session Garmin activity data, aligned to sessions[] by index. */
export interface GarminActivityForSession {
  activeKilocalories: number | null;
  durationInSeconds: number | null;
}

export interface DailyMacroInput {
  sex: Sex;
  age: number;
  weight_kg: number;
  height_cm: number;
  body_fat_pct?: number | null;
  lifestyle?: Lifestyle;
  typical_weekly_hours?: number | null;
  carb_cycle_opt_in?: boolean;
  training_phase?: TrainingPhase;
  sessions: SessionInput[];
  yesterday_tss?: number | null;
  yesterday_hours_since?: number | null;
  tomorrow_tss?: number | null;
  tomorrow_duration_hr?: number | null;
  tomorrow_is_race?: boolean;
  weekly_hours_ratio?: number | null;
  mode?: Mode;

  // Server-side Garmin context lookup. When omitted the server skips Garmin
  // entirely and uses the input fields as-is.
  user_id?: string;
  date?: string; // YYYY-MM-DD

  // Unix-seconds timestamps of the user's last manual entries.
  // Null/undefined = "no manual entry" (Garmin fills if available).
  user_weight_updated_at_seconds?: number | null;
  user_body_fat_updated_at_seconds?: number | null;

  // Garmin context — populated server-side by attachGarminContext().
  // Callers don't supply these directly; they are attached after the fetch.
  garmin_body_comp?: {
    weightInGrams: number | null;
    percentFat: number | null;
    measurementTimeInSeconds: number | null;
  } | null;

  garmin_daily?: {
    bmrKilocalories: number | null;
    activeKilocalories: number | null;
  } | null;

  /**
   * Per-session Garmin activity data, aligned to sessions[] by index.
   * Populated server-side from the activities table — entries are null
   * for sessions that have no garmin_summary_id (no Garmin upload).
   */
  garmin_activities?: (GarminActivityForSession | null)[] | null;
}

/** Per-day input for week mode — day-specific fields only */
export interface WeekDayInput {
  date?: string; // YYYY-MM-DD for this specific day (used for per-day Garmin context)
  sessions: SessionInput[];
  yesterday_tss?: number | null;
  yesterday_hours_since?: number | null;
  tomorrow_tss?: number | null;
  tomorrow_duration_hr?: number | null;
  tomorrow_is_race?: boolean;
  weekly_hours_ratio?: number | null;
  // Per-day Garmin context (populated server-side)
  garmin_body_comp?: DailyMacroInput['garmin_body_comp'];
  garmin_daily?: DailyMacroInput['garmin_daily'];
  garmin_activities?: DailyMacroInput['garmin_activities'];
  user_weight_updated_at_seconds?: number | null;
  user_body_fat_updated_at_seconds?: number | null;
}

/** Week-mode input: shared profile + 7 day entries */
export interface WeekMacroInput {
  scope: 'week';
  user_id?: string;
  date?: string; // YYYY-MM-DD (any date in the week; used as context for server-side lookup)
  sex: Sex;
  age: number;
  weight_kg: number;
  height_cm: number;
  body_fat_pct?: number | null;
  lifestyle?: Lifestyle;
  typical_weekly_hours?: number | null;
  carb_cycle_opt_in?: boolean;
  training_phase?: TrainingPhase;
  mode?: Mode;
  // User timestamps — shared across the week (fetched once)
  user_weight_updated_at_seconds?: number | null;
  user_body_fat_updated_at_seconds?: number | null;
  days: WeekDayInput[];
}

/**
 * Source attribution for each major input that fed into the calculation.
 * String literals match `ResolveSource` in formulas/resolve.ts. Stringly
 * typed here to avoid leaking the resolver's internal enum type into the
 * cross-platform output contract.
 */
export interface SessionSources {
  session_kcal: string; // 'GARMIN' | 'FORMULA'
  intensity_factor: string; // 'TP_ACTUAL' | 'TP_PLANNED' | 'ZONE_DIST'
  tss: string; // 'TP_ACTUAL' | 'TP_PLANNED' | 'FORMULA'
  duration: string; // 'GARMIN' | 'TP_PLANNED' | 'FORMULA'
}

export interface MacroSources {
  rmr: string; // 'GARMIN' | 'FORMULA'
  neat: string; // 'GARMIN' | 'FORMULA'
  weight: string; // 'GARMIN' | 'MANUAL'
  body_fat: string; // 'GARMIN' | 'MANUAL' | 'NONE'
  sessions: SessionSources[];
}

export interface DailyMacroOutput {
  carb_g: number;
  prot_g: number;
  fat_g: number;
  tdee: number;
  rmr: number;
  session_kcal: number;
  neat_kcal: number;
  tef_kcal: number;
  mode: string;
  ea: number | null;
  ea_status: string | null;
  algorithm_version: string;
  /**
   * Resolved athlete weight & body-fat % actually used in this calculation.
   * Lets the UI show "78 kg · from Garmin" alongside `sources.weight`.
   */
  weight_kg: number;
  body_fat_pct: number | null;
  sources: MacroSources;
}
