/** Daily targets always come from the app's `calculate-daily-macros-v6` edge function — never
 *  recomputed here. When the current week has missing days in daily_macro_targets (nobody
 *  opened the app to compute them), we call the deployed engine with the same payload the
 *  Flutter app builds (daily_macro_service.dart) and cache the result the same way.
 *  The fill is written with the service role (the one sanctioned admin write besides vana_calls). */
import { MACROS_FN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, today, addDays } from './env.ts';
import type { VanaCtx } from './env.ts';

type Act = {
  id: string; scheduled_date_time: string; title: string | null; activity_type: string;
  duration_minutes: number | null; intensity_level: string | null; tss: number | null;
  intensity_z1_z2_pct: number | null; intensity_z3_z4_pct: number | null; intensity_z5_pct: number | null;
  distance_miles: number | null; pace_target_minutes_per_mile: number | null; cycling_speed_mph: number | null; swimming_pace_per_100m_seconds: number | null;
};

/** App parity: _sessionFromActivityRow (duration fallbacks via pace/speed, sport mapping). */
// deno-lint-ignore no-explicit-any
function sessionFromActivity(r: Act): Record<string, any> {
  let dur = r.duration_minutes ?? 0;
  if (dur === 0) {
    const d = r.distance_miles;
    if (r.activity_type === 'running' && d != null && r.pace_target_minutes_per_mile) dur = Math.round(d * r.pace_target_minutes_per_mile);
    else if (r.activity_type === 'cycling' && d != null && r.cycling_speed_mph) dur = Math.round((d / r.cycling_speed_mph) * 60);
    else if (r.activity_type === 'swimming' && d != null && r.swimming_pace_per_100m_seconds) dur = Math.round(((d * 1609.34) / 100) * r.swimming_pace_per_100m_seconds / 60);
    if (dur === 0) dur = r.activity_type === 'other' ? 30 : 60;
  }
  const sport = r.activity_type === 'cycling' ? 'cycling' : r.activity_type === 'swimming' ? 'swimming' : r.activity_type === 'other' ? 'strength' : 'running';
  return { sport, duration_hr: dur / 60, pct_conversational: ((r.intensity_z1_z2_pct ?? 70) / 100), pct_tempo: ((r.intensity_z3_z4_pct ?? 20) / 100), pct_allout: ((r.intensity_z5_pct ?? 10) / 100), tss: r.tss, activity_id: r.id };
}
const actsOn = (acts: Act[], iso: string) => acts.filter((a) => String(a.scheduled_date_time).slice(0, 10) === iso);
/** App parity: _contextFromActivityRows. hours_since is clamped ≥0 (prospective weeks run into future dates). */
// deno-lint-ignore no-explicit-any
function contextFrom(acts: Act[]): Record<string, any> {
  if (!acts.length) return { max_tss: null, hours_since: null, duration_hr: null, is_race: false };
  const last = new Date(acts[acts.length - 1].scheduled_date_time).getTime();
  return {
    max_tss: acts.reduce<number | null>((m, a) => (a.tss != null && (m == null || a.tss > m) ? a.tss : m), null),
    hours_since: Math.max(0, (Date.now() - last) / 3600_000),
    duration_hr: acts.reduce((s, a) => s + (a.duration_minutes ?? 0) / 60, 0),
    is_race: acts.some((a) => a.intensity_level === 'race'),
  };
}
/** Monday-based training week, like the app's weeklyHoursFor. */
const weeklyHours = (acts: Act[], iso: string) => {
  const d = new Date(iso + 'T00:00:00Z'); const mon = new Date(d); mon.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  const end = new Date(mon); end.setUTCDate(mon.getUTCDate() + 7);
  return acts.filter((a) => { const t = new Date(a.scheduled_date_time).getTime(); return t >= mon.getTime() && t < end.getTime(); }).reduce((s, a) => s + (a.duration_minutes ?? 0), 0) / 60;
};

const attempted = new Map<string, number>(); // per user+week failure backoff — never block a turn on retries
/** Ensure daily_macro_targets covers the Sun–Sat week of `anchorDate` (default today); silently no-ops when it does. */
export async function ensureWeekTargets(v: VanaCtx, anchorDate?: string): Promise<void> {
  const t0 = anchorDate ?? today();
  const ws = (() => { const d = new Date(t0 + 'T00:00:00Z'); return addDays(t0, -d.getUTCDay()); })();
  const key = `${v.userId}:${ws}`;
  if (attempted.has(key) && Date.now() - attempted.get(key)! < 10 * 60_000) return;
  const week = Array.from({ length: 7 }, (_, i) => addDays(ws, i));
  try {
    const { data: have } = await v.db.from('daily_macro_targets').select('target_date').eq('user_id', v.userId).gte('target_date', ws).lte('target_date', addDays(ws, 6));
    const missing = week.filter((dt) => !(have ?? []).some((r: { target_date: string }) => r.target_date === dt));
    if (!missing.length) return;

    const { data: u } = await v.db.from('users').select('gender, birthday, weight_pounds, height_feet, height_inches, body_fat_pct, lifestyle, typical_weekly_hours, carb_cycle_opt_in, training_phase').eq('id', v.userId).maybeSingle();
    if (!u?.weight_pounds) return; // no profile → nothing the engine can compute from
    const { data: actsRaw } = await v.db.from('activities').select('id, scheduled_date_time, title, activity_type, duration_minutes, intensity_level, tss, intensity_z1_z2_pct, intensity_z3_z4_pct, intensity_z5_pct, distance_miles, pace_target_minutes_per_mile, cycling_speed_mph, swimming_pace_per_100m_seconds').eq('user_id', v.userId).is('deleted_at', null).gte('scheduled_date_time', addDays(ws, -1)).lt('scheduled_date_time', addDays(ws, 8)).order('scheduled_date_time');
    const acts = (actsRaw ?? []) as unknown as Act[];

    const age = u.birthday ? Math.floor((Date.now() - new Date(u.birthday).getTime()) / (365.25 * 86400_000)) : 35;
    const typical = Number(u.typical_weekly_hours ?? 0);
    const days = missing.map((dt) => {
      const y = contextFrom(actsOn(acts, addDays(dt, -1))); const tm = contextFrom(actsOn(acts, addDays(dt, 1)));
      return {
        sessions: actsOn(acts, dt).map(sessionFromActivity),
        yesterday_tss: y.max_tss, yesterday_hours_since: y.hours_since,
        tomorrow_tss: tm.max_tss, tomorrow_duration_hr: tm.duration_hr, tomorrow_is_race: tm.is_race ?? false,
        ...(typical > 0 ? { weekly_hours_ratio: weeklyHours(acts, dt) / typical } : {}),
      };
    });
    const res = await fetch(`${SUPABASE_URL}/functions/v1/${MACROS_FN}`, { method: 'POST', signal: AbortSignal.timeout(15_000), headers: { Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, apikey: SUPABASE_SERVICE_ROLE_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ user_id: v.userId, date: ws, scope: 'week', sex: u.gender === 'female' ? 'female' : 'male', age, weight_kg: Number(u.weight_pounds) * 0.453592, height_cm: (Number(u.height_feet ?? 6) * 12 + Number(u.height_inches ?? 0)) * 2.54, body_fat_pct: u.body_fat_pct ?? null, lifestyle: u.lifestyle ?? 'mixed', typical_weekly_hours: u.typical_weekly_hours ?? null, carb_cycle_opt_in: !!u.carb_cycle_opt_in, training_phase: u.training_phase ?? 'base', mode: 'prospective', days }) });
    if (!res.ok) throw new Error(`${MACROS_FN} ${res.status}`);
    const { days: out } = (await res.json()) as { days: { carb_g: number; prot_g: number; fat_g: number; tdee: number; rmr: number; session_kcal: number; neat_kcal: number; tef_kcal: number; mode: string; ea: number; ea_status: string; algorithm_version: string }[] };
    const rows = out.map((r, i) => ({ id: crypto.randomUUID(), user_id: v.userId, target_date: missing[i],
      carb_g: r.carb_g, prot_g: r.prot_g, fat_g: r.fat_g, tdee: r.tdee, rmr: r.rmr, session_kcal: r.session_kcal, neat_kcal: r.neat_kcal, tef_kcal: r.tef_kcal, mode: r.mode, ea: r.ea, ea_status: r.ea_status, algorithm_version: r.algorithm_version }));
    // (user_id, target_date) is a full unique constraint, not a partial index — safe as an onConflict target.
    const { error } = await v.admin.from('daily_macro_targets').upsert(rows, { onConflict: 'user_id,target_date' });
    if (error) throw new Error(error.message);
  } catch (e) {
    attempted.set(key, Date.now()); // back off; context falls back to whatever is cached
    console.warn('[vana] ensureWeekTargets failed:', (e as Error).message);
  }
}
