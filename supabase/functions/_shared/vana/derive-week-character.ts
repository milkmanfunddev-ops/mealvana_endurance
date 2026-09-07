/**
 * Client-side mirror of the server's WEEK CHARACTER derivation.
 *
 * Same heuristic the chat handler (vite.config.ts) injects into the system
 * prompt. Used by variant entry screens so they can lead with the inferred
 * character + anchor day instead of asking the user to pick one.
 */

export type WeekCharacter =
  | "race week"
  | "full rest"
  | "high-load training"
  | "moderate training"
  | "easy / recovery";

export interface ActivityLite {
  scheduled_date_time?: string | null;
  activity_type?: string | null;
  title?: string | null;
  duration_minutes?: number | null;
  intensity_level?: string | null;
  distance_miles?: number | null;
  distance_meters?: number | null;
}

export interface MacroLite {
  target_date?: string | null;
  carb_g?: number | null;
}

export interface DerivedWeekCharacter {
  weekCharacter: WeekCharacter;
  totalLoad: number;
  workoutDays: number;
  restDays: number;
  /** Longest activity in the next 7 days, if any */
  anchor: ActivityLite | null;
  /** "Saturday", "Wednesday", etc. — derived from anchor.scheduled_date_time */
  anchorDayName: string | null;
  /** "long run, 90 min, 12 mi" — short summary of anchor */
  anchorSummary: string | null;
  /** True if any activity in the next 7 days looks like a race */
  isRaceWeek: boolean;
  avgCarbG: number;
  /** Headline line: "high-load training week — anchor Saturday's long run (12 mi)" */
  headline: string;
  /** Single-sentence CTA copy: "Build a plan around Saturday's long run." */
  ctaCopy: string;
}

const intensityWeight: Record<string, number> = {
  low: 1,
  easy: 1,
  moderate: 2,
  mod: 2,
  high: 3,
  threshold: 3.5,
  vo2max: 4,
  race: 5,
};

const RACE_PATTERN = /race|marathon|half|10k|5k|ironman|tri\b/i;

/**
 * Derive a contextual summary of the upcoming 7 days from existing data.
 * Safe to call with empty arrays.
 */
export function deriveWeekCharacter(
  activities: ActivityLite[],
  macros: MacroLite[] = [],
): DerivedWeekCharacter {
  const sevenDaysOut = new Date(Date.now() + 7 * 86400_000)
    .toISOString()
    .slice(0, 10);
  const thisWeek = activities.filter(
    (a) => a.scheduled_date_time && a.scheduled_date_time.slice(0, 10) <= sevenDaysOut,
  );

  const totalLoad = thisWeek.reduce((sum, a) => {
    const min = Number(a.duration_minutes ?? 0);
    const w = intensityWeight[String(a.intensity_level ?? "moderate").toLowerCase()] ?? 2;
    return sum + min * w;
  }, 0);

  const workoutDays = new Set(
    thisWeek.map((a) => a.scheduled_date_time?.slice(0, 10)).filter(Boolean),
  ).size;
  const restDays = 7 - workoutDays;

  const anchor =
    thisWeek
      .slice()
      .sort((a, b) => Number(b.duration_minutes ?? 0) - Number(a.duration_minutes ?? 0))[0] ?? null;

  const isRaceWeek = thisWeek.some((a) =>
    RACE_PATTERN.test(`${a.title ?? ""} ${a.activity_type ?? ""}`),
  );

  let weekCharacter: WeekCharacter;
  if (isRaceWeek) weekCharacter = "race week";
  else if (workoutDays === 0) weekCharacter = "full rest";
  else if (totalLoad > 1200) weekCharacter = "high-load training";
  else if (totalLoad > 600) weekCharacter = "moderate training";
  else weekCharacter = "easy / recovery";

  const avgCarbG = macros.length
    ? Math.round(
        macros.reduce((s, m) => s + Number(m.carb_g ?? 0), 0) / macros.length,
      )
    : 0;

  let anchorDayName: string | null = null;
  let anchorSummary: string | null = null;
  if (anchor?.scheduled_date_time) {
    const date = new Date(anchor.scheduled_date_time.slice(0, 10) + "T00:00:00");
    anchorDayName = date.toLocaleDateString("en-US", { weekday: "long" });
    const dist = anchor.distance_miles
      ? `${anchor.distance_miles} mi`
      : anchor.distance_meters
        ? `${anchor.distance_meters} m`
        : "";
    const dur = anchor.duration_minutes ? `${anchor.duration_minutes} min` : "";
    const sport = anchor.title || anchor.activity_type || "workout";
    anchorSummary = [sport, dur, dist].filter(Boolean).join(" · ");
  }

  // Headline + CTA copy
  let headline: string;
  let ctaCopy: string;
  if (isRaceWeek && anchorDayName) {
    headline = `Race week — ${anchorDayName}'s ${anchor?.activity_type ?? "race"}.`;
    ctaCopy = `Build a carb-loading plan around ${anchorDayName}.`;
  } else if (workoutDays === 0) {
    headline = `Rest week — no workouts on the calendar.`;
    ctaCopy = `Build a recovery-focused plan.`;
  } else if (anchorDayName) {
    headline = `${weekCharacter[0].toUpperCase()}${weekCharacter.slice(1)} week — anchor ${anchorDayName} (${anchorSummary}).`;
    ctaCopy = `Build a plan around ${anchorDayName}'s ${anchor?.activity_type ?? "session"}.`;
  } else {
    headline = `${weekCharacter[0].toUpperCase()}${weekCharacter.slice(1)} week.`;
    ctaCopy = `Build my plan.`;
  }

  return {
    weekCharacter,
    totalLoad: Math.round(totalLoad),
    workoutDays,
    restDays,
    anchor,
    anchorDayName,
    anchorSummary,
    isRaceWeek,
    avgCarbG,
    headline,
    ctaCopy,
  };
}
