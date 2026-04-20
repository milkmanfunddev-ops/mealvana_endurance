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
}

/** Per-day input for week mode — day-specific fields only */
export interface WeekDayInput {
  sessions: SessionInput[];
  yesterday_tss?: number | null;
  yesterday_hours_since?: number | null;
  tomorrow_tss?: number | null;
  tomorrow_duration_hr?: number | null;
  tomorrow_is_race?: boolean;
  weekly_hours_ratio?: number | null;
}

/** Week-mode input: shared profile + 7 day entries */
export interface WeekMacroInput {
  scope: 'week';
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
  days: WeekDayInput[];
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
}
