/** Per-day "message from Vana" for the Plan tab — precomputed, never generated on read.
 *
 *  The notes live on `meal_plans.day_notes` ({date → text}) and are written by one Haiku call from the athlete
 *  context + the plan. The numbers in them come from the context (daily_macro_targets + activities), not the model.
 *
 *  Calling the model less often (ai-cost ticket 13, mp-432 / mp-478). Two mechanisms, both in SQL because an edge
 *  function keeps nothing between requests:
 *
 *  - **Per-day input keys.** Beside every note we store a fingerprint of the inputs it was written from
 *    (`meal_plans.day_notes_keys`, see `dayNoteKey`). On a regeneration the days whose fingerprint still matches keep
 *    their stored note and only the days that differ go to the model — so a plan edit rewrites the days it touched and
 *    nothing else, and a plan whose seven fingerprints all match calls no model at all. `day_notes_stale` stays what it
 *    was: the cheap flag every plan mutation flips (`refreshShopping`) to say "look again", not "rewrite everything".
 *
 *  - **A claim row.** `vana_day_note_claims` holds one row per plan while a generation runs. Whoever wins the insert
 *    calls the model; a request that loses waits for the stored notes to appear instead of calling it a second time.
 *    An in-process promise could not do this: two simultaneous requests may be two isolates. The row has a TTL so an
 *    isolate torn down mid-generation cannot block the plan forever.
 *
 *  Edge-function shape: the eager/background regenerations are not in-process promises (an isolate may be torn down
 *  after the response) — they are a `vana-day-notes` invocation handed to EdgeRuntime.waitUntil with the caller's JWT. */
import { generateObject } from 'npm:ai@6.0.277';
import { z } from 'npm:zod@3';
import { TOOL_MODEL, SUPABASE_URL, addDays, dayName, waitUntil } from './env.ts';
import type { VanaCtx } from './env.ts';
import { buildAthleteContext, contextBlock } from './context.ts';
import { getPlan } from './plan.ts';
import { logCall } from './log.ts';
import { checkRateLimit } from './rate-limit.ts';
import type { AthleteContext, DaySlot, MealPlan } from './contracts.ts';

const NotesZ = z.object({ notes: z.array(z.object({ date: z.string(), text: z.string() })).min(1).max(8) });

export const DAY_NOTE_SYSTEM =
  `You are Vana, an endurance-nutrition assistant. Write ONE short message (max 2 sentences, ≤ 30 words) for EACH of the dates listed, telling the athlete how to use their meal plan that day given their training. Be concrete: name a plan meal when it fits (e.g. "long ride → the rice bowl at lunch, extra serving at dinner"), mention the carb target only if it matters that day, keep rest days light. A date with meals already assigned is about those meals; a date with none may draw on any meal in the plan. Minimums framing, never weight or calorie-restriction language, no greetings, no emoji. Only use numbers that appear in the context.`;

/** How long a claim is honoured before another request may take it over (an isolate that died mid-generation). */
export const CLAIM_TTL_SECONDS = 120;
const SLOTS: readonly DaySlot[] = ['breakfast', 'lunch', 'dinner', 'snack'];

export interface DayNotesDeps {
  /** The one model call. Injected so a test drives the writer from a fixed set of notes. */
  generate: (input: { system: string; prompt: string; dates: string[] }) => Promise<{ notes: { date: string; text: string }[]; inputTokens?: number; outputTokens?: number }>;
  /** The athlete context the notes and the fingerprints are both read from. */
  buildContext: (v: VanaCtx, anchorDate: string) => Promise<AthleteContext>;
  /** A token → this request owns the plan's generation and releases it with that token. `true` → the claim could not
   *  be asked for (fail open): generate, but there is nothing of ours to release. False → someone else is generating. */
  claim: (v: VanaCtx, planId: string) => Promise<string | boolean>;
  release: (v: VanaCtx, planId: string, token: string) => Promise<void>;
  /** How a request that lost the claim waits for the winner's notes. */
  waitMs: number;
  pollMs: number;
  sleep: (ms: number) => Promise<void>;
}

export const defaultDayNotesDeps: DayNotesDeps = {
  generate: async ({ system, prompt }) => {
    const { object, usage } = await generateObject({ model: TOOL_MODEL, schema: NotesZ, maxOutputTokens: 900, system, prompt });
    return { notes: object.notes, inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens };
  },
  buildContext: (v, anchorDate) => buildAthleteContext(v, anchorDate),
  claim: async (v, planId) => {
    const { data, error } = await v.db.rpc('vana_claim_day_notes', { p_plan_id: planId, p_ttl_seconds: CLAIM_TTL_SECONDS });
    // Fail open on a database error: a missed claim costs one duplicate call, a wrongly refused one costs the notes.
    if (error) { console.error(`[vana] day notes claim failed: ${error.message}`); return true; }
    return typeof data === 'string' && data ? data : false;
  },
  release: async (v, planId, token) => {
    const { error } = await v.db.rpc('vana_release_day_notes', { p_plan_id: planId, p_claimed_at: token });
    if (error) console.error(`[vana] day notes release failed: ${error.message}`);
  },
  waitMs: 25_000,
  pollMs: 500,
  sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
};

/** The seven dates a note is written for, from the day the athlete is looking at. */
export const noteDates = (anchorDate: string) => Array.from({ length: 7 }, (_, i) => addDays(anchorDate, i));

/** The pool of meals the plan holds — what a day with nothing assigned may draw on.
 *  `servingsLeft` is deliberately out: eating a serving does not rewrite the week's notes, and no plan mutation that
 *  only moves it flips `day_notes_stale` either. */
const poolSignature = (plan: MealPlan) =>
  plan.meals.map((m) => `${m.name}/${m.mealType}/${m.servings}/${m.session ?? ''}`).sort().join('|');

/** The inputs the note for one date is written from, as one canonical string.
 *
 *  A date's own inputs are its assigned slots, its workouts and its macro target, plus the two plan-wide facts the
 *  prompt carries (status, batch cooking). The meal pool is an input ONLY for a date with nothing assigned, because
 *  that is the date whose note may name any meal in the plan — which is exactly why moving a meal in or out of the
 *  pool leaves an assigned day's note alone and an unassigned day's note to be written again. */
export function dayNoteInputs(plan: MealPlan, ctx: AthleteContext, date: string): string {
  const slots = plan.days?.[date] ?? {};
  const assigned = SLOTS.map((s) => { const r = slots[s]; return r ? `${s}=${r.name}` : null; }).filter((x): x is string => !!x);
  const workouts = ctx.week.workouts.filter((w) => w.date === date).map((w) => `${w.title ?? ''}/${w.type}/${w.minutes ?? ''}/${w.intensity ?? ''}`).sort();
  const t = ctx.budget.week.find((d) => d.date === date);
  return [
    `d=${date}`,
    `st=${plan.status}`,
    `bc=${plan.batchCooking ? 1 : 0}`,
    `slots=${assigned.join('|')}`,
    `w=${workouts.join('|')}`,
    `t=${t ? `${t.carbsG}/${t.kcal}/${t.sessionKcal}` : ''}`,
    assigned.length ? 'pool=assigned' : `pool=${poolSignature(plan)}`,
  ].join(';');
}

const hex = (buf: ArrayBuffer) => Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');

/** The stored fingerprint for one date — sha256 of `dayNoteInputs`, first 16 hex chars. */
export async function dayNoteKey(plan: MealPlan, ctx: AthleteContext, date: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(dayNoteInputs(plan, ctx, date)));
  return hex(digest).slice(0, 16);
}

export async function dayNoteKeys(plan: MealPlan, ctx: AthleteContext, dates: string[]): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  for (const d of dates) out[d] = await dayNoteKey(plan, ctx, d);
  return out;
}

/** What is stored right now. Read from the table rather than the caller's `MealPlan` snapshot: between an edit and
 *  this call another request may already have written the notes, and that is the whole point of the claim row. */
async function storedNotes(v: VanaCtx, planId: string): Promise<{ notes: Record<string, string>; keys: Record<string, string> }> {
  const { data } = await v.db.from('meal_plans').select('day_notes, day_notes_keys').eq('id', planId).maybeSingle();
  return { notes: (data?.day_notes ?? {}) as Record<string, string>, keys: (data?.day_notes_keys ?? {}) as Record<string, string> };
}

/** The dates whose stored note is missing or was written from different inputs. */
export const staleDates = (dates: string[], stored: { notes: Record<string, string>; keys: Record<string, string> }, want: Record<string, string>) =>
  dates.filter((d) => !stored.notes[d]?.trim() || stored.keys[d] !== want[d]);

function notesPrompt(plan: MealPlan, ctx: AthleteContext, dates: string[]): string {
  const meals = plan.meals.map((m) => `- ${m.name} (${m.mealType}, ×${m.servings}, ${m.servingsLeft} left${m.session ? `, ${m.session}` : ''})`).join('\n') || '- (no meals in the plan yet)';
  const lines = dates.map((d) => {
    const slots = plan.days?.[d] ?? {};
    const assigned = SLOTS.map((s) => { const r = slots[s]; return r ? `${s}: ${r.name}` : null; }).filter(Boolean).join(', ');
    return `${d} (${dayName(d)}) — ${assigned || 'no meals assigned yet'}`;
  });
  return `--- CONTEXT ---\n${contextBlock(ctx)}\n--- PLAN (${plan.status}, batch cooking ${plan.batchCooking ? 'on' : 'off'}) ---\n${meals}\n--- DATES ---\n${lines.join('\n')}\nReturn one note per date, in order.`;
}

/** Bring the plan's notes up to date, writing only the days whose inputs changed. Returns every note the plan holds.
 *  Costs no model call when nothing changed, and no second model call when another request is already generating. */
export async function generateDayNotes(v: VanaCtx, plan: MealPlan, anchorDate: string, deps: DayNotesDeps = defaultDayNotesDeps): Promise<Record<string, string>> {
  const dates = noteDates(anchorDate);
  const ctx = await deps.buildContext(v, anchorDate);
  const want = await dayNoteKeys(plan, ctx, dates);
  const stored = await storedNotes(v, plan.id);
  const dirty = staleDates(dates, stored, want);

  // The plan is unchanged as far as the notes are concerned: keep every stored note and call nothing.
  if (!dirty.length) {
    if (plan.dayNotesStale !== false) await v.db.from('meal_plans').update({ day_notes_stale: false }).eq('id', plan.id);
    console.log(`[vana] day notes for ${plan.id}: nothing changed, no model call`);
    return stored.notes;
  }

  // Over the bucket → keep whatever notes exist (the Plan tab shows the last good ones); never queue a burst of Haiku calls.
  const rl = await checkRateLimit(v.admin, v.userId, 'vana.daynotes');
  if (!rl.allowed) { console.warn(`[vana] day notes rate-limited for ${v.userId}`); return stored.notes; }

  // Someone else is already writing these days. Wait for their notes rather than paying for a second call.
  const claimed = await deps.claim(v, plan.id);
  if (!claimed) return await awaitNotes(v, plan, dates, want, stored, deps);

  const started = Date.now();
  try {
    // The flag comes down BEFORE the model runs, never after: an edit that lands while we generate raises it again,
    // and our write below must not lower it over that edit (its days would stay wrong until the next plan change).
    if (plan.dayNotesStale !== false) await v.db.from('meal_plans').update({ day_notes_stale: false }).eq('id', plan.id);
    const { notes: written, inputTokens, outputTokens } = await deps.generate({ system: DAY_NOTE_SYSTEM, prompt: notesPrompt(plan, ctx, dirty), dates: dirty });
    const fresh: Record<string, string> = {};
    const keys: Record<string, string> = {};
    for (const n of written) if (dirty.includes(n.date) && n.text.trim()) { fresh[n.date] = n.text.trim(); keys[n.date] = want[n.date]; }
    const notes = { ...stored.notes, ...fresh };
    await v.db.from('meal_plans').update({
      day_notes: notes,
      day_notes_keys: { ...stored.keys, ...keys },
      day_notes_at: new Date().toISOString(),
    }).eq('id', plan.id);
    await logCall(v.admin, { userId: v.userId, functionName: 'vana.daynotes', model: TOOL_MODEL, inputTokens, outputTokens });
    console.log(`[vana] day notes for ${plan.id}: ${dirty.length} of ${dates.length} days in ${Date.now() - started}ms`);
    return notes;
  } catch (e) {
    // Nothing was written: the days are still wrong, so the next open must try again.
    await v.db.from('meal_plans').update({ day_notes_stale: true }).eq('id', plan.id);
    throw e;
  } finally {
    if (typeof claimed === 'string') await deps.release(v, plan.id, claimed);
  }
}

/** Lost the claim: poll for the winner's notes, then answer with whatever is stored. Never calls the model. */
async function awaitNotes(v: VanaCtx, plan: MealPlan, dates: string[], want: Record<string, string>, stored: { notes: Record<string, string>; keys: Record<string, string> }, deps: DayNotesDeps): Promise<Record<string, string>> {
  const deadline = Date.now() + deps.waitMs;
  while (Date.now() < deadline) {
    await deps.sleep(deps.pollMs);
    const now = await storedNotes(v, plan.id);
    if (!staleDates(dates, now, want).length) {
      console.log(`[vana] day notes for ${plan.id}: another request wrote them, no second model call`);
      return now.notes;
    }
    stored = now;
  }
  console.warn(`[vana] day notes for ${plan.id}: waited ${deps.waitMs}ms for another request, answering with what is stored`);
  return stored.notes;
}

/** Notes for the plan. Fresh → stored. Stale but a note exists for the day → return it now, regenerate in the background
 *  (`stale: true` tells the client to refetch shortly). No note at all → wait for one. Never throws. */
export async function ensureDayNotes(v: VanaCtx, plan: MealPlan | null, anchorDate: string, deps: DayNotesDeps = defaultDayNotesDeps): Promise<{ notes: Record<string, string>; stale: boolean }> {
  if (!plan) return { notes: {}, stale: false };
  const have = !!plan.dayNotes[anchorDate];
  if (!plan.dayNotesStale && have) return { notes: plan.dayNotes, stale: false };
  if (have) { refreshDayNotesSoon(v, anchorDate, plan.id); return { notes: plan.dayNotes, stale: true }; }
  try { return { notes: await generateDayNotes(v, plan, anchorDate, deps), stale: false }; } catch (e) { console.error('[vana] day notes failed:', (e as Error).message); return { notes: plan.dayNotes, stale: false }; }
}

/** After Confirm / an edit: regenerate eagerly without holding the response — one `vana-day-notes` call under waitUntil.
 *  Cheap to over-call: the endpoint writes only the days whose inputs moved, and the claim row keeps two of these to one
 *  model call. */
export function refreshDayNotesSoon(v: VanaCtx, anchorDate: string, planId?: string | null) {
  const run = (async () => {
    const id = planId ?? (await getPlan(v))?.id; if (!id) return;
    const res = await fetch(`${SUPABASE_URL}/functions/v1/vana-day-notes`, { method: 'POST', signal: AbortSignal.timeout(60_000), headers: { Authorization: `Bearer ${v.token}`, 'content-type': 'application/json' }, body: JSON.stringify({ plan_id: id, anchor_date: anchorDate }) });
    if (!res.ok) console.error(`[vana] vana-day-notes ${res.status}: ${(await res.text()).slice(0, 200)}`);
  })().catch((e) => console.error('[vana] day notes refresh failed:', (e as Error).message));
  waitUntil(run);
}
